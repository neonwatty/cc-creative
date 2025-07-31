require "test_helper"

module CloudServices
  class GoogleDriveServiceTest < ActiveSupport::TestCase
    setup do
      @integration = cloud_integrations(:one)
      @service = GoogleDriveService.new(@integration)
      
      # Mock Google API client
      @mock_drive_service = mock()
      Google::Apis::DriveV3::DriveService.stubs(:new).returns(@mock_drive_service)
      
      # Mock Google auth
      @mock_auth = mock()
      Google::Auth::UserRefreshCredentials.stubs(:new).returns(@mock_auth)
      @mock_drive_service.stubs(:authorization=)
      
      # Configure Rails credentials for testing
      Rails.application.credentials.stubs(:dig).with(:google, :client_id).returns("test-client-id")
      Rails.application.credentials.stubs(:dig).with(:google, :client_secret).returns("test-client-secret")
    end

    teardown do
      # WebMock.reset!
    end

    test "oauth2_config returns correct configuration" do
      config = GoogleDriveService.oauth2_config
      
      assert_equal "test-client-id", config[:client_id]
      assert_equal "test-client-secret", config[:client_secret]
      assert_includes config[:redirect_uri], "/cloud_integrations/google/callback"
      assert_equal "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/drive.file", config[:scope]
      assert_equal "offline", config[:access_type]
      assert_equal "consent", config[:prompt]
    end

    test "authorization_url generates correct URL" do
      url = GoogleDriveService.authorization_url
      
      assert_includes url, "https://accounts.google.com/o/oauth2/v2/auth"
      assert_includes url, "client_id=test-client-id"
      assert_includes url, "response_type=code"
      assert_includes url, "scope=https"
      assert_includes url, "access_type=offline"
    end

    test "exchange_code makes correct API call and returns tokens" do
      # Mock HTTParty response
      mock_response = mock()
      mock_response.stubs(:success?).returns(true)
      mock_response.stubs(:body).returns({ 
        access_token: "new-access-token",
        refresh_token: "new-refresh-token",
        expires_in: 3600
      }.to_json)
      
      HTTParty.expects(:post).with('https://oauth2.googleapis.com/token', anything).returns(mock_response)
      
      result = GoogleDriveService.exchange_code("auth-code")
      
      assert_equal "new-access-token", result["access_token"]
      assert_equal "new-refresh-token", result["refresh_token"]
      assert_equal 3600, result["expires_in"]
    end

    test "exchange_code raises error on failure" do
      mock_response = mock()
      mock_response.stubs(:success?).returns(false)
      mock_response.stubs(:body).returns("Invalid code")
      
      HTTParty.expects(:post).returns(mock_response)
      
      assert_raises CloudServices::BaseService::ApiError do
        GoogleDriveService.exchange_code("invalid-code")
      end
    end

    test "list_files returns formatted file list" do
      mock_files = [
        OpenStruct.new(
          id: "file1",
          name: "Document.docx",
          mime_type: "application/vnd.google-apps.document",
          size: 1024,
          modified_time: Time.current,
          web_view_link: "https://docs.google.com/document/d/file1"
        )
      ]
      
      mock_response = OpenStruct.new(
        files: mock_files,
        next_page_token: "next-page"
      )
      
      @mock_drive_service.expects(:list_files).with(
        q: "mimeType != 'application/vnd.google-apps.folder'",
        page_size: 100,
        page_token: nil,
        fields: 'files(id, name, mimeType, size, modifiedTime, webViewLink), nextPageToken'
      ).returns(mock_response)
      
      result = @service.list_files
      
      assert_equal 1, result[:files].count
      assert_equal "file1", result[:files].first[:id]
      assert_equal "Document.docx", result[:files].first[:name]
      assert_equal "next-page", result[:next_page_token]
    end

    test "list_files with custom query and page token" do
      @mock_drive_service.expects(:list_files).with(
        q: "name contains 'test'",
        page_size: 100,
        page_token: "page-token",
        fields: anything
      ).returns(OpenStruct.new(files: [], next_page_token: nil))
      
      @service.list_files(query: "name contains 'test'", page_token: "page-token")
    end

    test "import_file exports Google Docs as HTML" do
      mock_file = OpenStruct.new(
        name: "My Document",
        mime_type: "application/vnd.google-apps.document"
      )
      
      @mock_drive_service.expects(:get_file).with("doc-id").returns(mock_file)
      @mock_drive_service.expects(:export_file).with("doc-id", "text/html").returns("<html>Content</html>")
      
      result = @service.import_file("doc-id")
      
      assert_equal "My Document", result[:name]
      assert_equal "<html>Content</html>", result[:content]
      assert_equal "application/vnd.google-apps.document", result[:mime_type]
    end

    test "import_file exports Google Sheets as CSV" do
      mock_file = OpenStruct.new(
        name: "My Spreadsheet",
        mime_type: "application/vnd.google-apps.spreadsheet"
      )
      
      @mock_drive_service.expects(:get_file).with("sheet-id").returns(mock_file)
      @mock_drive_service.expects(:export_file).with("sheet-id", "text/csv").returns("col1,col2\nval1,val2")
      
      result = @service.import_file("sheet-id")
      
      assert_equal "text/csv", result[:content]
    end

    test "import_file downloads regular files" do
      mock_file = OpenStruct.new(
        name: "image.png",
        mime_type: "image/png"
      )
      
      @mock_drive_service.expects(:get_file).with("file-id").returns(mock_file)
      @mock_drive_service.expects(:get_file).with("file-id", download_dest: anything).returns("binary-data")
      
      result = @service.import_file("file-id")
      
      assert_equal "image.png", result[:name]
      assert_equal "image/png", result[:mime_type]
    end

    test "export_document creates file in Google Drive" do
      document = documents(:one)
      
      mock_file = OpenStruct.new(
        id: "new-file-id",
        name: document.title,
        web_view_link: "https://docs.google.com/document/d/new-file-id"
      )
      
      @mock_drive_service.expects(:create_file).with(
        { name: document.title, parents: ["root"] },
        fields: "id, name, webViewLink",
        upload_source: anything,
        content_type: "text/html"
      ).returns(mock_file)
      
      cloud_file = @service.export_document(document)
      
      assert_equal "new-file-id", cloud_file.file_id
      assert_equal document.title, cloud_file.name
      assert_equal "text/html", cloud_file.mime_type
      assert_equal document, cloud_file.document
      assert_not_nil cloud_file.last_synced_at
    end

    test "export_document with custom folder" do
      document = documents(:one)
      
      @mock_drive_service.expects(:create_file).with(
        { name: document.title, parents: ["folder-123"] },
        fields: anything,
        upload_source: anything,
        content_type: anything
      ).returns(OpenStruct.new(id: "file-id", name: document.title, web_view_link: "link"))
      
      @service.export_document(document, folder_id: "folder-123")
    end

    test "handles authentication errors" do
      error = Google::Apis::AuthorizationError.new("Unauthorized")
      error.instance_variable_set(:@status_code, 401)
      
      @mock_drive_service.expects(:list_files).raises(error)
      
      assert_raises CloudServices::BaseService::AuthenticationError do
        @service.list_files
      end
    end

    test "handles authorization errors" do
      error = Google::Apis::ClientError.new("Forbidden")
      error.instance_variable_set(:@status_code, 403)
      
      @mock_drive_service.expects(:list_files).raises(error)
      
      assert_raises CloudServices::BaseService::AuthorizationError do
        @service.list_files
      end
    end

    test "handles not found errors" do
      error = Google::Apis::ClientError.new("Not Found")
      error.instance_variable_set(:@status_code, 404)
      
      @mock_drive_service.expects(:get_file).raises(error)
      
      assert_raises CloudServices::BaseService::NotFoundError do
        @service.import_file("missing-id")
      end
    end

    test "refreshes token when needed" do
      mock_response = mock()
      mock_response.stubs(:success?).returns(true)
      mock_response.stubs(:body).returns({ 
        access_token: "refreshed-token",
        expires_in: 3600
      }.to_json)
      
      HTTParty.expects(:post).with('https://oauth2.googleapis.com/token', anything).returns(mock_response)
      
      # Force token refresh by calling private method through send
      result = @service.send(:oauth2_refresh_request)
      
      assert_equal "refreshed-token", result["access_token"]
    end
  end
end