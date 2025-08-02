require "test_helper"

class CloudFilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)

    # Delete existing integrations to avoid uniqueness conflicts
    CloudIntegration.destroy_all

    @cloud_integration = CloudIntegration.create!(
      user: @user,
      provider: "google_drive",
      access_token: "test_token",
      settings: { scope: "drive.file" }
    )
    @cloud_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: "google_drive",
      file_id: "test_file_123",
      name: "test_document.txt",
      mime_type: "text/plain",
      size: 1024,
      metadata: { author: "Test User" }
    )
    sign_in_as(@user)
  end

  # Index Action Tests
  test "should get index" do
    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_response :success
    assert_select "h1", text: /Files/
  end

  test "index should show cloud files" do
    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_response :success
    assert_select "div", text: /#{@cloud_file.name}/
  end

  test "index should filter by importable files when requested" do
    # Create non-importable file
    non_importable = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: "google_drive",
      file_id: "image_file",
      name: "image.jpg",
      mime_type: "image/jpeg",
      size: 2048
    )

    get cloud_integration_cloud_files_url(@cloud_integration, importable: "true")
    assert_response :success

    # Should show importable file
    assert_select "div", text: /#{@cloud_file.name}/
    # Should not show non-importable file
    assert_select "div", text: /#{non_importable.name}/, count: 0
  end

  test "index should trigger sync when requested" do
    CloudFileSyncJob.expects(:perform_later).with(@cloud_integration).once

    get cloud_integration_cloud_files_url(@cloud_integration, sync: "true")
    assert_response :success
    assert_match /Syncing files/, flash[:notice]
  end

  test "index should trigger sync when no files exist" do
    @cloud_integration.cloud_files.destroy_all
    CloudFileSyncJob.expects(:perform_later).with(@cloud_integration).once

    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_response :success
  end

  test "index should trigger sync when sync is needed" do
    # Make the file appear old
    @cloud_file.update!(last_synced_at: 2.hours.ago)
    CloudFileSyncJob.expects(:perform_later).with(@cloud_integration).once

    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_response :success
  end

  test "index should paginate results" do
    # Create 25 files to test pagination
    25.times do |i|
      CloudFile.create!(
        cloud_integration: @cloud_integration,
        provider: "google_drive",
        file_id: "file_#{i}",
        name: "document_#{i}.txt",
        mime_type: "text/plain",
        size: 1024
      )
    end

    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_response :success
    # Should only show 20 files per page (as configured in controller)
    assert_select "div[data-file-id]", count: 20
  end

  test "index should require authentication" do
    sign_out
    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_redirected_to new_session_path
  end

  test "index should not allow access to other users integrations" do
    other_user = users(:two)
    other_integration = CloudIntegration.create!(
      user: other_user,
      provider: "dropbox",
      access_token: "other_token",
      settings: {}
    )

    get cloud_integration_cloud_files_url(other_integration)
    assert_response :not_found
  end

  # Show Action Tests
  test "should show cloud file" do
    get cloud_integration_cloud_file_url(@cloud_integration, @cloud_file)
    assert_response :success
    assert_select "h1", text: /#{@cloud_file.name}/
  end

  test "show should display file metadata" do
    get cloud_integration_cloud_file_url(@cloud_integration, @cloud_file)
    assert_response :success
    assert_select "div", text: /#{@cloud_file.human_size}/
    assert_select "div", text: /#{@cloud_file.mime_type}/
  end

  test "show should not allow access to other users files" do
    other_user = users(:two)
    other_integration = CloudIntegration.create!(
      user: other_user,
      provider: "dropbox",
      access_token: "other_token",
      settings: {}
    )
    other_file = CloudFile.create!(
      cloud_integration: other_integration,
      provider: "dropbox",
      file_id: "other_file",
      name: "other.txt",
      mime_type: "text/plain"
    )

    get cloud_integration_cloud_file_url(@cloud_integration, other_file)
    assert_response :not_found
  end

  # Import Action Tests
  test "should import importable file" do
    CloudFileImportJob.expects(:perform_later).with(@cloud_file, @user).once

    post import_cloud_integration_cloud_file_url(@cloud_integration, @cloud_file)

    assert_redirected_to cloud_integration_cloud_files_path(@cloud_integration)
    assert_match /File import queued/, flash[:notice]
  end

  test "should not import non-importable file" do
    non_importable = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: "google_drive",
      file_id: "image_file",
      name: "image.jpg",
      mime_type: "image/jpeg",
      size: 2048
    )

    CloudFileImportJob.expects(:perform_later).never

    post import_cloud_integration_cloud_file_url(@cloud_integration, non_importable)

    assert_redirected_to cloud_integration_cloud_files_path(@cloud_integration)
    assert_match /cannot be imported/, flash[:alert]
  end

  test "import should require authentication" do
    sign_out
    post import_cloud_integration_cloud_file_url(@cloud_integration, @cloud_file)
    assert_redirected_to new_session_path
  end

  test "import should not allow access to other users files" do
    other_user = users(:two)
    other_integration = CloudIntegration.create!(
      user: other_user,
      provider: "dropbox",
      access_token: "other_token",
      settings: {}
    )
    other_file = CloudFile.create!(
      cloud_integration: other_integration,
      provider: "dropbox",
      file_id: "other_file",
      name: "other.txt",
      mime_type: "text/plain"
    )

    post import_cloud_integration_cloud_file_url(@cloud_integration, other_file)
    assert_response :not_found
  end

  # Export Action Tests
  test "should export document to cloud" do
    document = documents(:one)
    service_mock = mock("cloud_service")
    service_mock.expects(:export_document).with(document, {}).returns(
      CloudFile.new(name: "exported.txt", file_id: "exported_123")
    )

    controller = CloudFilesController.new
    controller.stubs(:cloud_service_for).returns(service_mock)
    CloudFilesController.any_instance.stubs(:cloud_service_for).returns(service_mock)

    post export_cloud_integration_cloud_files_url(@cloud_integration), params: {
      document_id: document.id
    }

    assert_redirected_to document_path(document)
    assert_match /Document exported/, flash[:notice]
  end

  test "should handle export errors gracefully" do
    document = documents(:one)
    service_mock = mock("cloud_service")
    service_mock.expects(:export_document).raises(StandardError.new("Export failed"))

    CloudFilesController.any_instance.stubs(:cloud_service_for).returns(service_mock)

    post export_cloud_integration_cloud_files_url(@cloud_integration), params: {
      document_id: document.id
    }

    assert_redirected_to document_path(document)
    assert_match /Failed to export/, flash[:alert]
  end

  test "export should require authentication" do
    document = documents(:one)
    sign_out

    post export_cloud_integration_cloud_files_url(@cloud_integration), params: {
      document_id: document.id
    }
    assert_redirected_to new_session_path
  end

  test "export should not allow access to other users documents" do
    other_user = users(:two)
    other_document = Document.create!(
      title: "Other Document",
      content: "Other document content",
      user: other_user
    )

    post export_cloud_integration_cloud_files_url(@cloud_integration), params: {
      document_id: other_document.id
    }

    # Should raise RecordNotFound because current_user.documents won't include other user's docs
    assert_response :not_found
  end

  test "export should pass export options" do
    document = documents(:one)
    service_mock = mock("cloud_service")

    expected_options = {
      folder_id: "folder123",
      folder_path: "/my/folder",
      parent_page_id: "page456"
    }

    service_mock.expects(:export_document).with(document, expected_options).returns(
      CloudFile.new(name: "exported.txt", file_id: "exported_123")
    )

    CloudFilesController.any_instance.stubs(:cloud_service_for).returns(service_mock)

    post export_cloud_integration_cloud_files_url(@cloud_integration), params: {
      document_id: document.id,
      folder_id: "folder123",
      folder_path: "/my/folder",
      parent_page_id: "page456",
      ignored_param: "should_be_ignored"
    }

    assert_redirected_to document_path(document)
    assert_match /Document exported/, flash[:notice]
  end

  # Helper Method Tests
  test "sync_needed? should return true when no files exist" do
    @cloud_integration.cloud_files.destroy_all
    controller = CloudFilesController.new
    controller.instance_variable_set(:@cloud_integration, @cloud_integration)

    assert controller.send(:sync_needed?)
  end

  test "sync_needed? should return true when files are old" do
    @cloud_file.update!(last_synced_at: 2.hours.ago)
    controller = CloudFilesController.new
    controller.instance_variable_set(:@cloud_integration, @cloud_integration)

    assert controller.send(:sync_needed?)
  end

  test "sync_needed? should return false when files are recent" do
    @cloud_file.update!(last_synced_at: 30.minutes.ago)
    controller = CloudFilesController.new
    controller.instance_variable_set(:@cloud_integration, @cloud_integration)

    assert_not controller.send(:sync_needed?)
  end

  test "cloud_service_for should return correct service class" do
    controller = CloudFilesController.new

    # Test Google Drive
    google_integration = CloudIntegration.new(provider: "google_drive")
    CloudServices::GoogleDriveService.expects(:new).with(google_integration).returns("google_service")
    result = controller.send(:cloud_service_for, google_integration)
    assert_equal "google_service", result

    # Test Dropbox
    dropbox_integration = CloudIntegration.new(provider: "dropbox")
    CloudServices::DropboxService.expects(:new).with(dropbox_integration).returns("dropbox_service")
    result = controller.send(:cloud_service_for, dropbox_integration)
    assert_equal "dropbox_service", result

    # Test Notion
    notion_integration = CloudIntegration.new(provider: "notion")
    CloudServices::NotionService.expects(:new).with(notion_integration).returns("notion_service")
    result = controller.send(:cloud_service_for, notion_integration)
    assert_equal "notion_service", result
  end

  test "cloud_service_for should raise error for unknown provider" do
    controller = CloudFilesController.new
    unknown_integration = CloudIntegration.new(provider: "unknown_provider")

    assert_raises(RuntimeError, /Unknown provider/) do
      controller.send(:cloud_service_for, unknown_integration)
    end
  end

  test "export_options should permit only allowed parameters" do
    controller = CloudFilesController.new

    # Mock params
    allowed_params = {
      "folder_id" => "folder123",
      "folder_path" => "/path",
      "parent_page_id" => "page456"
    }

    disallowed_params = {
      "user_id" => "999",
      "access_token" => "secret",
      "malicious" => "payload"
    }

    all_params = allowed_params.merge(disallowed_params)

    controller.stubs(:params).returns(ActionController::Parameters.new(all_params))

    result = controller.send(:export_options)

    # Should only include allowed params with symbol keys
    expected = {
      folder_id: "folder123",
      folder_path: "/path",
      parent_page_id: "page456"
    }

    assert_equal expected, result
  end

  # Error Handling Tests
  test "should handle service unavailable errors" do
    CloudFileSyncJob.stubs(:perform_later).raises(StandardError.new("Service unavailable"))

    get cloud_integration_cloud_files_url(@cloud_integration, sync: "true")

    # Should still respond successfully even if sync job fails
    assert_response :success
  end

  test "should handle database connection errors gracefully" do
    # Stub at the model level to ensure the error is raised
    CloudIntegration.any_instance.stubs(:cloud_files).raises(ActiveRecord::ConnectionNotEstablished.new("Database down"))

    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      get cloud_integration_cloud_files_url(@cloud_integration)
    end
  end

  # Security Tests
  test "should prevent mass assignment attacks" do
    # This is more of a model concern, but worth testing at controller level
    post import_cloud_integration_cloud_file_url(@cloud_integration, @cloud_file), params: {
      cloud_file: {
        file_id: "malicious_id",
        access_token: "stolen_token"
      }
    }

    # Should ignore the malicious params
    @cloud_file.reload
    assert_not_equal "malicious_id", @cloud_file.file_id
  end

  test "should sanitize file names in responses" do
    malicious_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: "google_drive",
      file_id: "malicious_file",
      name: '<script>alert("xss")</script>.txt',
      mime_type: "text/plain"
    )

    get cloud_integration_cloud_files_url(@cloud_integration)
    assert_response :success

    # HTML should be escaped
    assert_no_match /<script>/, response.body
    assert_match /&lt;script&gt;/, response.body
  end

  # Performance Tests
  test "index should include necessary associations to avoid N+1 queries" do
    # Create multiple files
    5.times do |i|
      CloudFile.create!(
        cloud_integration: @cloud_integration,
        provider: "google_drive",
        file_id: "file_#{i}",
        name: "document_#{i}.txt",
        mime_type: "text/plain",
        document: documents(:one)  # Associate with document
      )
    end

    # This test verifies that the controller uses includes(:document)
    # With authentication, integration lookup, and other framework queries,
    # we expect around 13-15 queries total. The key is that we shouldn't have
    # N+1 queries for documents (which would be 5 extra queries for 5 files)
    assert_queries_count(13) do
      get cloud_integration_cloud_files_url(@cloud_integration)
    end

    assert_response :success
  end

  private

  def assert_queries_count(expected_count)
    queries = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
      queries << payload[:sql] unless payload[:sql] =~ /^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/
    end

    yield

    assert_equal expected_count, queries.size, "Expected #{expected_count} queries, got #{queries.size}:\n#{queries.join("\n")}"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end
