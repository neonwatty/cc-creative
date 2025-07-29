require "test_helper"

module CloudServices
  class GoogleDriveServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      
      # Delete existing integration to avoid uniqueness conflicts
      CloudIntegration.where(user: @user, provider: 'google_drive').destroy_all
      
      @cloud_integration = CloudIntegration.create!(
        user: @user,
        provider: 'google_drive',
        access_token: 'test_google_token',
        refresh_token: 'test_google_refresh',
        expires_at: 1.hour.from_now,
        settings: { 
          scope: 'https://www.googleapis.com/auth/drive.readonly',
          token_type: 'Bearer'
        }
      )
      
      # Mock Google credentials
      Rails.application.credentials.stubs(:dig).with(:google, :client_id).returns('test_client_id')
      Rails.application.credentials.stubs(:dig).with(:google, :client_secret).returns('test_client_secret')
      
      @service = GoogleDriveService.new(@cloud_integration)
    end

    # Class Method Tests
    test "oauth2_config should return correct configuration" do
      GoogleDriveService.stubs(:build_callback_url).returns('http://localhost:3000/callback')
      
      config = GoogleDriveService.oauth2_config
      
      assert_equal 'test_client_id', config[:client_id]
      assert_equal 'test_client_secret', config[:client_secret]
      assert_equal 'http://localhost:3000/callback', config[:redirect_uri]
      assert_includes config[:scope], 'drive.readonly'
      assert_equal 'offline', config[:access_type]
      assert_equal 'consent', config[:prompt]
    end

    test "authorization_url should generate correct OAuth URL" do
      GoogleDriveService.stubs(:build_callback_url).returns('http://localhost:3000/callback')
      
      url = GoogleDriveService.authorization_url
      
      assert_includes url, 'https://accounts.google.com/o/oauth2/v2/auth'
      assert_includes url, 'client_id=test_client_id'
      assert_includes url, 'redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback'
      assert_includes url, 'response_type=code'
      assert_includes url, 'access_type=offline'
      assert_includes url, 'prompt=consent'
    end

    test "exchange_code should make correct API request" do
      expected_response = {
        'access_token' => 'new_access_token',
        'refresh_token' => 'new_refresh_token',
        'expires_in' => 3600,
        'scope' => 'drive.readonly',
        'token_type' => 'Bearer'
      }
      
      HTTParty.expects(:post).with(
        'https://oauth2.googleapis.com/token',
        has_entries(
          body: has_entries(
            code: 'auth_code_123',
            client_id: 'test_client_id',
            client_secret: 'test_client_secret',
            grant_type: 'authorization_code'
          )
        )
      ).returns(mock_response(expected_response))
      
      result = GoogleDriveService.exchange_code('auth_code_123')
      
      assert_equal expected_response, result
    end

    test "exchange_code should handle API errors" do
      error_response = { 'error' => 'invalid_grant', 'error_description' => 'Invalid code' }
      
      HTTParty.expects(:post).returns(mock_response(error_response, success: false))
      
      assert_raises(ApiError, /Failed to exchange code/) do
        GoogleDriveService.exchange_code('invalid_code')
      end
    end

    # Instance Method Tests
    test "list_files should return formatted file list" do
      mock_files_response = mock('files_response')
      mock_files_response.stubs(:files).returns([
        create_mock_file('file1', 'document.txt', 'text/plain', 1024),
        create_mock_file('file2', 'spreadsheet.xlsx', 'application/vnd.ms-excel', 2048)
      ])
      mock_files_response.stubs(:next_page_token).returns('next_token_123')
      
      @service.instance_variable_get(:@drive_service).expects(:list_files).with(
        q: "mimeType != 'application/vnd.google-apps.folder'",
        page_size: 100,
        page_token: nil,
        fields: 'files(id, name, mimeType, size, modifiedTime, webViewLink), nextPageToken'
      ).returns(mock_files_response)
      
      result = @service.list_files
      
      assert_equal 2, result[:files].length
      assert_equal 'next_token_123', result[:next_page_token]
      
      file1 = result[:files].first
      assert_equal 'file1', file1[:id]
      assert_equal 'document.txt', file1[:name]
      assert_equal 'text/plain', file1[:mime_type]
      assert_equal 1024, file1[:size]
      assert_not_nil file1[:metadata][:modified_time]
      assert_not_nil file1[:metadata][:web_view_link]
    end

    test "list_files should handle custom query and page_token" do
      mock_files_response = mock('files_response')
      mock_files_response.stubs(:files).returns([])
      mock_files_response.stubs(:next_page_token).returns(nil)
      
      @service.instance_variable_get(:@drive_service).expects(:list_files).with(
        q: "name contains 'test'",
        page_size: 100,
        page_token: 'page_token_456',
        fields: 'files(id, name, mimeType, size, modifiedTime, webViewLink), nextPageToken'
      ).returns(mock_files_response)
      
      result = @service.list_files(query: "name contains 'test'", page_token: 'page_token_456')
      
      assert_equal [], result[:files]
      assert_nil result[:next_page_token]
    end

    test "list_files should handle Google API errors" do
      google_error = Google::Apis::ClientError.new('Invalid credentials')
      
      @service.instance_variable_get(:@drive_service).expects(:list_files).raises(google_error)
      @service.expects(:handle_google_api_error).with(google_error)
      
      @service.list_files
    end

    test "import_file should handle Google Docs" do
      mock_file = create_mock_file('doc1', 'My Document', 'application/vnd.google-apps.document', nil)
      html_content = '<html><body><h1>My Document Content</h1></body></html>'
      
      drive_service = @service.instance_variable_get(:@drive_service)
      drive_service.expects(:get_file).with('doc1').returns(mock_file)
      drive_service.expects(:export_file).with('doc1', 'text/html').returns(html_content)
      
      result = @service.import_file('doc1')
      
      assert_equal html_content, result[:content]
      assert_equal 'application/vnd.google-apps.document', result[:mime_type]
      assert_equal 'My Document', result[:name]
    end

    test "import_file should handle Google Sheets" do
      mock_file = create_mock_file('sheet1', 'My Spreadsheet', 'application/vnd.google-apps.spreadsheet', nil)
      csv_content = "Name,Value\nTest,123\nExample,456"
      
      drive_service = @service.instance_variable_get(:@drive_service)
      drive_service.expects(:get_file).with('sheet1').returns(mock_file)
      drive_service.expects(:export_file).with('sheet1', 'text/csv').returns(csv_content)
      
      result = @service.import_file('sheet1')
      
      assert_equal csv_content, result[:content]
      assert_equal 'application/vnd.google-apps.spreadsheet', result[:mime_type]
      assert_equal 'My Spreadsheet', result[:name]
    end

    test "import_file should handle regular files" do
      mock_file = create_mock_file('txt1', 'notes.txt', 'text/plain', 500)
      file_content = "This is a plain text file content"
      
      drive_service = @service.instance_variable_get(:@drive_service)
      drive_service.expects(:get_file).with('txt1').returns(mock_file)
      drive_service.expects(:get_file).with('txt1', download_dest: kind_of(StringIO)).returns(file_content)
      
      result = @service.import_file('txt1')
      
      assert_equal file_content, result[:content]
      assert_equal 'text/plain', result[:mime_type]
      assert_equal 'notes.txt', result[:name]
    end

    test "import_file should handle download errors" do
      google_error = Google::Apis::ClientError.new('File not found')
      
      drive_service = @service.instance_variable_get(:@drive_service)
      drive_service.expects(:get_file).raises(google_error)
      @service.expects(:handle_google_api_error).with(google_error)
      
      @service.import_file('nonexistent')
    end

    test "export_document should upload document to Drive" do
      document = documents(:one)
      mock_file_metadata = mock('file_metadata')
      mock_uploaded_file = create_mock_file('uploaded1', document.title, 'text/html', 2048)
      
      drive_service = @service.instance_variable_get(:@drive_service)
      drive_service.expects(:create_file).with(
        { name: document.title, parents: ['folder123'] },
        fields: 'id, name, webViewLink',
        upload_source: kind_of(StringIO),
        content_type: 'text/html'
      ).returns(mock_uploaded_file)
      
      result = @service.export_document(document, folder_id: 'folder123')
      
      assert_equal 'uploaded1', result.file_id
      assert_equal document.title, result.name
      assert_equal 'text/html', result.mime_type
    end

    test "export_document should handle upload errors" do
      document = documents(:one)
      google_error = Google::Apis::ClientError.new('Insufficient storage')
      
      Google::Apis::DriveV3::File.stubs(:new).returns(mock('file_metadata'))
      
      drive_service = @service.instance_variable_get(:@drive_service)
      drive_service.expects(:create_file).raises(google_error)
      @service.expects(:handle_google_api_error).with(google_error)
      
      @service.export_document(document)
    end

    # OAuth2 Refresh Tests
    test "oauth2_refresh_request should make correct refresh request" do
      expected_response = {
        'access_token' => 'refreshed_token',
        'refresh_token' => 'new_refresh_token',
        'expires_in' => 3600
      }
      
      HTTParty.expects(:post).with(
        'https://oauth2.googleapis.com/token',
        has_entries(
          body: has_entries(
            refresh_token: 'test_google_refresh',
            client_id: 'test_client_id',
            client_secret: 'test_client_secret',
            grant_type: 'refresh_token'
          )
        )
      ).returns(mock_response(expected_response))
      
      result = @service.send(:oauth2_refresh_request)
      
      assert_equal expected_response, result
    end

    test "oauth2_refresh_request should handle refresh errors" do
      error_response = { 'error' => 'invalid_grant' }
      
      HTTParty.expects(:post).returns(mock_response(error_response, success: false))
      
      assert_raises(ApiError, /Failed to refresh token/) do
        @service.send(:oauth2_refresh_request)
      end
    end

    # Error Handling Tests
    test "handle_google_api_error should map Google errors correctly" do
      # Test authentication error (401)
      auth_error = Google::Apis::AuthorizationError.new("Invalid credentials")
      auth_error.stubs(:status_code).returns(401)
      assert_raises(CloudServices::AuthenticationError) do
        @service.send(:handle_google_api_error, auth_error)
      end
      
      # Test client error (400-499)
      client_error = Google::Apis::ClientError.new("Bad request")
      client_error.stubs(:status_code).returns(400)
      assert_raises(CloudServices::ApiError) do
        @service.send(:handle_google_api_error, client_error)
      end
      
      # Test server error (500-599)
      server_error = Google::Apis::ServerError.new("Internal server error")
      server_error.stubs(:status_code).returns(500)
      assert_raises(CloudServices::ApiError) do
        @service.send(:handle_google_api_error, server_error)
      end
      
      # Test rate limit error
      rate_limit_error = Google::Apis::RateLimitError.new("Rate limit exceeded")
      rate_limit_error.stubs(:status_code).returns(429)
      assert_raises(CloudServices::ApiError) do
        @service.send(:handle_google_api_error, rate_limit_error)
      end
    end

    # Integration Tests (with mocked Google services)
    test "should successfully sync files from Google Drive" do
      mock_files_response = mock('files_response')
      mock_files_response.stubs(:files).returns([
        create_mock_file('file1', 'doc1.txt', 'text/plain', 1024),
        create_mock_file('file2', 'doc2.pdf', 'application/pdf', 2048)
      ])
      mock_files_response.stubs(:next_page_token).returns(nil)
      
      @service.instance_variable_get(:@drive_service).expects(:list_files).returns(mock_files_response)
      
      result = @service.sync_files
      
      assert_equal 2, result
      assert_equal 2, @cloud_integration.cloud_files.count
      
      file1 = @cloud_integration.cloud_files.find_by(file_id: 'file1')
      assert_equal 'doc1.txt', file1.name
      assert_equal 'text/plain', file1.mime_type
      assert_equal 1024, file1.size
    end

    test "should handle API rate limits gracefully" do
      rate_limit_error = Google::Apis::RateLimitError.new("Rate limit exceeded")
      
      @service.instance_variable_get(:@drive_service).expects(:list_files).raises(rate_limit_error)
      
      assert_raises(ApiError) do
        @service.sync_files
      end
    end

    test "should refresh token before API calls when needed" do
      @cloud_integration.update!(expires_at: 30.minutes.from_now)
      
      @service.expects(:refresh_token!).returns(true)
      @service.expects(:list_files).returns([])
      
      @service.sync_files
    end

    private

    def mock_response(body, success: true)
      response = mock('http_response')
      response.stubs(:success?).returns(success)
      response.stubs(:body).returns(body.to_json)
      response
    end

    def create_mock_file(id, name, mime_type, size)
      file = mock("google_file_#{id}")
      file.stubs(:id).returns(id)
      file.stubs(:name).returns(name)
      file.stubs(:mime_type).returns(mime_type)
      file.stubs(:size).returns(size)
      file.stubs(:modified_time).returns(Time.current)
      file.stubs(:web_view_link).returns("https://drive.google.com/file/d/#{id}/view")
      file
    end
  end
end