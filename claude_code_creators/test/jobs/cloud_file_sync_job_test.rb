require "test_helper"

class CloudFileSyncJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)

    # Delete existing integration to avoid uniqueness conflicts
    CloudIntegration.where(user: @user, provider: "google_drive").destroy_all

    @cloud_integration = CloudIntegration.create!(
      user: @user,
      provider: "google_drive",
      access_token: "test_token",
      refresh_token: "test_refresh",
      expires_at: 1.hour.from_now,
      settings: { scope: "drive.readonly" }
    )
  end

  test "should enqueue job with integration" do
    assert_enqueued_with(job: CloudFileSyncJob, args: [ @cloud_integration ]) do
      CloudFileSyncJob.perform_later(@cloud_integration)
    end
  end

  test "should perform sync and update settings" do
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).returns(5)  # 5 files synced

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Test that last_sync_at gets updated
    CloudFileSyncJob.perform_now(@cloud_integration)

    @cloud_integration.reload
    assert_not_nil @cloud_integration.get_setting("last_sync_at")
  end

  test "should handle sync errors and broadcast failure" do
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(StandardError.new("API Error"))

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Errors should be re-raised
    assert_raises(StandardError) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should handle authentication errors" do
    auth_error = CloudServices::AuthenticationError.new("Invalid token")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(auth_error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Authentication errors are caught and handled gracefully
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should handle authorization errors" do
    auth_error = CloudServices::AuthorizationError.new("Access denied")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(auth_error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Authorization errors should be re-raised, not caught like authentication errors
    assert_raises(CloudServices::AuthorizationError) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should work with different providers" do
    providers_and_services = {
      "google_drive" => CloudServices::GoogleDriveService,
      "dropbox" => CloudServices::DropboxService,
      "notion" => CloudServices::NotionService
    }

    providers_and_services.each do |provider, service_class|
      # Clean up any existing integrations for this provider
      CloudIntegration.where(user: @user, provider: provider).destroy_all

      integration = CloudIntegration.create!(
        user: @user,
        provider: provider,
        access_token: "test_token",
        settings: {}
      )

      service_mock = mock("#{provider}_service")
      service_mock.expects(:sync_files).returns(3)

      service_class.expects(:new).with(integration).returns(service_mock)

      assert_nothing_raised do
        CloudFileSyncJob.perform_now(integration)
      end
    end
  end

  test "should handle network timeouts" do
    timeout_error = Timeout::Error.new("Request timeout")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(timeout_error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    assert_raises(Timeout::Error) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should handle JSON parsing errors" do
    json_error = JSON::ParserError.new("Invalid JSON")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(json_error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    assert_raises(JSON::ParserError) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should sync files successfully" do
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).returns(2)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Should complete successfully
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end

    @cloud_integration.reload
    assert_not_nil @cloud_integration.get_setting("last_sync_at")
  end

  test "should sync multiple files successfully" do
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).returns(10)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end

    @cloud_integration.reload
    assert_not_nil @cloud_integration.get_setting("last_sync_at")
  end

  test "should handle zero files synced" do
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).returns(0)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Should complete successfully even with 0 files
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end

    @cloud_integration.reload
    assert_not_nil @cloud_integration.get_setting("last_sync_at")
  end

  test "should be retryable on transient errors" do
    # Test that the job handles transient errors appropriately
    timeout_error = Timeout::Error.new("Request timeout")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(timeout_error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    assert_raises(Timeout::Error) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should not retry on authentication errors" do
    # Authentication errors should be handled gracefully without retries
    auth_error = CloudServices::AuthenticationError.new("Invalid credentials")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(auth_error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Authentication errors are caught and logged, not raised
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should handle service instantiation errors" do
    # Test when service class doesn't exist or fails to instantiate
    CloudServices::GoogleDriveService.expects(:new).raises(NameError.new("Service not found"))

    assert_raises(NameError) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should handle missing integration gracefully" do
    # Test with a non-existent integration object
    non_existent_integration = CloudIntegration.new(id: 999999)
    non_existent_integration.stubs(:active?).returns(false)

    # Should return early without error when integration is not active
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(non_existent_integration)
    end
  end

  test "should work when ActionCable is not available" do
    # Simulate ActionCable server not being available
    ActionCable.stubs(:server).returns(nil)

    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).returns(3)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    # Should not raise an error even if ActionCable is not available
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should use correct queue" do
    assert_equal "default", CloudFileSyncJob.queue_name
  end

  test "should log sync activity" do
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).returns(7)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    Rails.logger.expects(:info).at_least_once

    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should log sync errors" do
    error = StandardError.new("Sync failed")
    service_mock = mock("cloud_service")
    service_mock.expects(:sync_files).raises(error)

    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)

    Rails.logger.expects(:error).at_least_once

    assert_raises(StandardError) do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end
end
