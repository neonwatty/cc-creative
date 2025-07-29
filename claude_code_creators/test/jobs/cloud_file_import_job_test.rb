require "test_helper"

class CloudFileImportJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one) 
    
    # Delete existing integration to avoid uniqueness conflicts
    CloudIntegration.where(user: @user, provider: 'google_drive').destroy_all
    
    @cloud_integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 1.hour.from_now,
      settings: { scope: 'drive.readonly' }
    )
    
    @cloud_file = CloudFile.create!(
      cloud_integration: @cloud_integration,
      provider: 'google_drive',
      file_id: 'test_file_123',
      name: 'Test Document.txt',
      mime_type: 'text/plain',
      size: 1024,
      metadata: { author: 'Test User' }
    )
  end

  test "should enqueue job with cloud file and user" do
    assert_enqueued_with(job: CloudFileImportJob, args: [@cloud_file, @user]) do
      CloudFileImportJob.perform_later(@cloud_file, @user)
    end
  end

  test "should successfully import file and create document" do
    imported_content = {
      content: "This is the imported file content",
      content_type: 'text/plain',
      title: 'Test Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).with(@cloud_file.file_id).returns(imported_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Mock ActionCable broadcasts
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      {
        type: 'import_started',
        file_id: @cloud_file.id,
        file_name: @cloud_file.name
      }
    )
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      {
        type: 'import_completed',
        file_id: @cloud_file.id,
        file_name: @cloud_file.name,
        document_id: anything
      }
    )
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    # Verify document was created correctly
    document = Document.last
    assert_equal 'Test Document', document.title
    assert_equal @user, document.user
    assert_includes document.content.to_plain_text, "This is the imported file content"
    
    # Verify cloud file is linked to document
    @cloud_file.reload
    assert_equal document, @cloud_file.document
  end

  test "should handle import errors and broadcast failure" do
    error = CloudServices::ApiError.new("Failed to download file")
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).with(@cloud_file.file_id).raises(error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Mock ActionCable broadcasts
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      {
        type: 'import_started',
        file_id: @cloud_file.id,
        file_name: @cloud_file.name
      }
    )
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      {
        type: 'import_failed',
        file_id: @cloud_file.id,
        file_name: @cloud_file.name,
        error: 'Failed to download file'
      }
    )
    
    assert_no_difference('Document.count') do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    # Cloud file should not be linked to any document
    @cloud_file.reload
    assert_nil @cloud_file.document
  end

  test "should handle authentication errors" do
    auth_error = CloudServices::AuthenticationError.new("Invalid token")
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).raises(auth_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      has_entries(type: 'import_failed', error: 'Invalid token')
    )
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      has_entries(type: 'import_started')
    )
    
    assert_no_difference('Document.count') do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
  end

  test "should handle file not found errors" do
    not_found_error = CloudServices::NotFoundError.new("File not found")
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).raises(not_found_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).twice
    
    assert_no_difference('Document.count') do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
  end

  test "should work with different providers" do
    providers_and_services = {
      'google_drive' => CloudServices::GoogleDriveService,
      'dropbox' => CloudServices::DropboxService,
      'notion' => CloudServices::NotionService
    }
    
    providers_and_services.each do |provider, service_class|
      integration = CloudIntegration.create!(
        user: @user,
        provider: provider,
        access_token: 'test_token',
        settings: {}
      )
      
      file = CloudFile.create!(
        cloud_integration: integration,
        provider: provider,
        file_id: "#{provider}_file_123",
        name: "#{provider}_document.txt",
        mime_type: 'text/plain'
      )
      
      service_mock = mock("#{provider}_service")
      service_mock.expects(:import_file).returns({
        content: "Content from #{provider}",
        content_type: 'text/plain',
        title: "#{provider} Document"
      })
      
      service_class.expects(:new).with(integration).returns(service_mock)
      ActionCable.server.expects(:broadcast).twice
      
      assert_difference('Document.count', 1) do
        CloudFileImportJob.perform_now(file, @user)
      end
    end
  end

  test "should handle HTML content import" do
    html_content = {
      content: "<h1>HTML Document</h1><p>This is HTML content</p>",
      content_type: 'text/html',
      title: 'HTML Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(html_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    document = Document.last
    assert_equal 'HTML Document', document.title
    # ActionText should handle HTML content properly
    assert_includes document.content.to_s, 'HTML Document'
    assert_includes document.content.to_s, 'This is HTML content'
  end

  test "should handle markdown content import" do
    @cloud_file.update!(mime_type: 'text/markdown', name: 'document.md')
    
    markdown_content = {
      content: "# Markdown Document\n\nThis is **markdown** content",
      content_type: 'text/markdown',
      title: 'Markdown Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(markdown_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    document = Document.last
    assert_equal 'Markdown Document', document.title
  end

  test "should handle large file imports" do
    large_content = "x" * 1_000_000  # 1MB of content
    
    large_file_content = {
      content: large_content,
      content_type: 'text/plain',
      title: 'Large Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(large_file_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    document = Document.last
    assert_equal 'Large Document', document.title
    assert_equal large_content.length, document.content.to_plain_text.length
  end

  test "should generate unique document titles for duplicates" do
    # Create existing document with same title
    Document.create!(title: 'Test Document', user: @user)
    
    imported_content = {
      content: "Content",
      content_type: 'text/plain',
      title: 'Test Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(imported_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    new_document = Document.last
    assert_not_equal 'Test Document', new_document.title
    assert_includes new_document.title, 'Test Document'
  end

  test "should handle empty or missing content gracefully" do
    empty_content = {
      content: "",
      content_type: 'text/plain',
      title: 'Empty Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(empty_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    document = Document.last
    assert_equal 'Empty Document', document.title
  end

  test "should handle missing title in imported content" do
    no_title_content = {
      content: "Content without title",
      content_type: 'text/plain'
      # title is missing
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(no_title_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    assert_difference('Document.count', 1) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
    
    document = Document.last
    # Should fall back to cloud file name
    assert_equal @cloud_file.name, document.title
  end

  test "should broadcast to correct user channel" do
    imported_content = {
      content: "Content",
      content_type: 'text/plain',
      title: 'Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(imported_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    expected_channel = "cloud_import_#{@user.id}"
    ActionCable.server.expects(:broadcast).with(expected_channel, anything).twice
    
    CloudFileImportJob.perform_now(@cloud_file, @user)
  end

  test "should include correct data in broadcast messages" do
    imported_content = {
      content: "Content", 
      content_type: 'text/plain',
      title: 'Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(imported_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Test start broadcast
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      {
        type: 'import_started',
        file_id: @cloud_file.id,
        file_name: @cloud_file.name
      }
    )
    
    # Test completion broadcast  
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      {
        type: 'import_completed',
        file_id: @cloud_file.id,
        file_name: @cloud_file.name,
        document_id: anything
      }
    )
    
    CloudFileImportJob.perform_now(@cloud_file, @user)
  end

  test "should be retryable on transient errors" do
    # Test that the job handles timeout errors appropriately
    timeout_error = Timeout::Error.new("Request timeout")
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).raises(timeout_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    assert_raises(Timeout::Error) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
  end

  test "should not retry on authentication errors" do
    assert_includes CloudFileImportJob.discard_on, CloudServices::AuthenticationError
    assert_includes CloudFileImportJob.discard_on, CloudServices::AuthorizationError
  end

  test "should use correct queue" do
    assert_equal :default, CloudFileImportJob.queue_name
  end

  test "should log import activity" do
    imported_content = {
      name: 'Test Document',
      content: "Content",
      mime_type: 'text/plain'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(imported_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    Rails.logger.expects(:info).with(regexp_matches(/Successfully imported .* as document .* for user/))
    
    assert_nothing_raised do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
  end

  test "should log import errors" do
    error = StandardError.new("Import failed")
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).raises(error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    Rails.logger.expects(:error).with(regexp_matches(/Import error for cloud file .* Import failed/))
    
    assert_raises(StandardError) do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
  end

  test "should handle database transaction failures" do
    imported_content = {
      content: "Content",
      content_type: 'text/plain', 
      title: 'Document'
    }
    
    service_mock = mock('cloud_service')
    service_mock.expects(:import_file).returns(imported_content)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Mock database failure
    Document.expects(:create!).raises(ActiveRecord::RecordInvalid.new(Document.new))
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      has_entries(type: 'import_failed')
    )
    ActionCable.server.expects(:broadcast).with(
      "cloud_import_#{@user.id}",
      has_entries(type: 'import_started')
    )
    
    assert_no_difference('Document.count') do
      CloudFileImportJob.perform_now(@cloud_file, @user)
    end
  end
end