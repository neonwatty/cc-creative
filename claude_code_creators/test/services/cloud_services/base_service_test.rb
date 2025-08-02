require "test_helper"

module CloudServices
  class BaseServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)

      # Delete existing integrations to avoid conflicts
      CloudIntegration.where(user: @user, provider: "google_drive").destroy_all

      @cloud_integration = CloudIntegration.create!(
        user: @user,
        provider: "google_drive",  # Use a valid provider
        access_token: "test_token",
        refresh_token: "test_refresh_token",
        expires_at: 1.hour.from_now,
        settings: { scope: "test_scope" }
      )
      @service = TestService.new(@cloud_integration)
    end

    # Initialization Tests
    test "should initialize with integration" do
      assert_equal @cloud_integration, @service.integration
      assert_equal @user, @service.user
    end

    # Abstract Method Tests
    test "should raise NotImplementedError for abstract methods" do
      base_service = BaseService.new(@cloud_integration)

      assert_raises(NotImplementedError) do
        base_service.oauth2_client
      end

      assert_raises(NotImplementedError) do
        base_service.list_files
      end

      assert_raises(NotImplementedError) do
        base_service.import_file("file_id")
      end

      assert_raises(NotImplementedError) do
        base_service.export_document(documents(:one))
      end
    end

    # Token Refresh Tests
    test "refresh_token! should return early if refresh not needed" do
      @cloud_integration.update!(expires_at: 2.hours.from_now)

      @service.expects(:oauth2_refresh_request).never
      result = @service.refresh_token!

      assert_nil result
    end

    test "refresh_token! should refresh token when needed" do
      @cloud_integration.update!(expires_at: 30.minutes.from_now)

      @service.expects(:oauth2_refresh_request).returns({
        "access_token" => "new_access_token",
        "refresh_token" => "new_refresh_token",
        "expires_in" => 3600
      })

      result = @service.refresh_token!

      assert_equal true, result
      @cloud_integration.reload
      assert_equal "new_access_token", @cloud_integration.access_token
      assert_equal "new_refresh_token", @cloud_integration.refresh_token
    end

    test "refresh_token! should handle missing refresh_token in response" do
      @cloud_integration.update!(expires_at: 30.minutes.from_now)

      @service.expects(:oauth2_refresh_request).returns({
        "access_token" => "new_access_token",
        "expires_in" => 3600
      })

      result = @service.refresh_token!

      assert_equal true, result
      @cloud_integration.reload
      assert_equal "new_access_token", @cloud_integration.access_token
      assert_equal "test_refresh_token", @cloud_integration.refresh_token  # Should keep original
    end

    test "refresh_token! should handle refresh failures" do
      @cloud_integration.update!(expires_at: 30.minutes.from_now)

      @service.expects(:oauth2_refresh_request).raises(StandardError.new("Refresh failed"))
      Rails.logger.expects(:error).with(includes("Failed to refresh token"))

      result = @service.refresh_token!

      assert_equal false, result
    end

    # Sync Files Tests
    test "sync_files should refresh token if needed and sync files" do
      @cloud_integration.update!(expires_at: 30.minutes.from_now)

      @service.expects(:refresh_token!).returns(true)
      @service.expects(:list_files).returns([
        {
          id: "file1",
          name: "test1.txt",
          mime_type: "text/plain",
          size: 1024,
          metadata: { author: "Test User" }
        },
        {
          id: "file2",
          name: "test2.pdf",
          mime_type: "application/pdf",
          size: 2048,
          metadata: { pages: 5 }
        }
      ])

      result = @service.sync_files

      assert_equal 2, result
      assert_equal 2, @cloud_integration.cloud_files.count

      file1 = @cloud_integration.cloud_files.find_by(file_id: "file1")
      assert_equal "test1.txt", file1.name
      assert_equal "text/plain", file1.mime_type
      assert_equal 1024, file1.size
      assert_equal({ "author" => "Test User" }, file1.metadata)
      assert_not_nil file1.last_synced_at
    end

    test "sync_files should update existing files" do
      existing_file = CloudFile.create!(
        cloud_integration: @cloud_integration,
        provider: "test_provider",
        file_id: "file1",
        name: "old_name.txt",
        mime_type: "text/plain",
        size: 512,
        metadata: { old: "data" }
      )

      @service.expects(:list_files).returns([
        {
          id: "file1",
          name: "updated_name.txt",
          mime_type: "text/plain",
          size: 1024,
          metadata: { updated: "data" }
        }
      ])

      result = @service.sync_files

      assert_equal 1, result
      assert_equal 1, @cloud_integration.cloud_files.count

      existing_file.reload
      assert_equal "updated_name.txt", existing_file.name
      assert_equal 1024, existing_file.size
      assert_equal({ "updated" => "data" }, existing_file.metadata)
    end

    test "sync_files should handle nil metadata" do
      @service.expects(:list_files).returns([
        {
          id: "file1",
          name: "test.txt",
          mime_type: "text/plain",
          size: 1024,
          metadata: nil
        }
      ])

      result = @service.sync_files

      assert_equal 1, result
      file = @cloud_integration.cloud_files.first
      assert_equal({}, file.metadata)
    end

    # Callback URL Tests
    test "build_callback_url should construct proper URLs" do
      Rails.application.config.action_mailer.default_url_options = { host: "example.com", port: 3000 }
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))

      url = BaseService.build_callback_url("/oauth/callback")
      assert_equal "http://example.com:3000/oauth/callback", url
    end

    test "build_callback_url should use https in production" do
      Rails.application.config.action_mailer.default_url_options = { host: "myapp.com" }
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))

      url = BaseService.build_callback_url("/oauth/callback")
      assert_equal "https://myapp.com/oauth/callback", url
    end

    test "build_callback_url should omit standard ports" do
      Rails.application.config.action_mailer.default_url_options = { host: "example.com", port: 80 }
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))

      url = BaseService.build_callback_url("/oauth/callback")
      assert_equal "http://example.com/oauth/callback", url
    end

    # Helper Method Tests
    test "calculate_expiry should handle expires_in correctly" do
      freeze_time do
        expiry = @service.send(:calculate_expiry, 3600)
        assert_equal Time.current + 1.hour, expiry
      end
    end

    test "calculate_expiry should return nil for nil expires_in" do
      expiry = @service.send(:calculate_expiry, nil)
      assert_nil expiry
    end

    test "handle_api_error should raise appropriate errors" do
      unauthorized_error = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      forbidden_error = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
      not_found_error = Net::HTTPNotFound.new("1.1", "404", "Not Found")
      generic_error = StandardError.new("Generic error")

      assert_raises(AuthenticationError, /Invalid or expired credentials/) do
        @service.send(:handle_api_error, unauthorized_error)
      end

      assert_raises(AuthorizationError, /Access denied/) do
        @service.send(:handle_api_error, forbidden_error)
      end

      assert_raises(NotFoundError, /Resource not found/) do
        @service.send(:handle_api_error, not_found_error)
      end

      assert_raises(ApiError, /API request failed/) do
        @service.send(:handle_api_error, generic_error)
      end
    end

    test "parse_response should parse JSON responses" do
      response = mock("response")
      response.stubs(:body).returns('{"key": "value"}')

      result = @service.send(:parse_response, response)
      assert_equal({ "key" => "value" }, result)
    end

    test "parse_response should return raw body for non-JSON" do
      response = mock("response")
      response.stubs(:body).returns("plain text response")

      result = @service.send(:parse_response, response)
      assert_equal "plain text response", result
    end

    test "parse_response should handle malformed JSON" do
      response = mock("response")
      response.stubs(:body).returns("{ invalid json }")

      result = @service.send(:parse_response, response)
      assert_equal "{ invalid json }", result
    end

    # Error Classes Tests
    test "custom error classes should inherit properly" do
      assert ApiError < StandardError
      assert AuthenticationError < ApiError
      assert AuthorizationError < ApiError
      assert NotFoundError < ApiError
    end

    test "custom errors should carry messages" do
      error = ApiError.new("Test message")
      assert_equal "Test message", error.message

      auth_error = AuthenticationError.new("Auth failed")
      assert_equal "Auth failed", auth_error.message
    end

    private

    def freeze_time(&block)
      Time.stubs(:current).returns(Time.parse("2024-01-01 12:00:00"))
      yield
    ensure
      Time.unstub(:current)
    end
  end

  # Test implementation of BaseService for testing purposes
  class TestService < BaseService
    def oauth2_client
      "test_client"
    end

    def list_files(options = {})
      []
    end

    def import_file(file_id)
      "imported_#{file_id}"
    end

    def export_document(document, options = {})
      "exported_#{document.id}"
    end

    def oauth2_refresh_request
      # Default implementation for testing
      {
        "access_token" => "refreshed_token",
        "refresh_token" => "new_refresh_token",
        "expires_in" => 3600
      }
    end
  end
end
