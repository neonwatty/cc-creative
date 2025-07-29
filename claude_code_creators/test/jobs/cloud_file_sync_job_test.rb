require "test_helper"

class CloudFileSyncJobTest < ActiveJob::TestCase
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
  end

  test "should enqueue job with integration" do
    assert_enqueued_with(job: CloudFileSyncJob, args: [@cloud_integration]) do
      CloudFileSyncJob.perform_later(@cloud_integration)
    end
  end

  test "should perform sync and broadcast progress" do
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).returns(5)  # 5 files synced
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Mock ActionCable broadcast
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      {
        type: 'sync_started',
        integration_id: @cloud_integration.id,
        provider: 'google_drive'
      }
    )
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      {
        type: 'sync_completed',
        integration_id: @cloud_integration.id,
        provider: 'google_drive',
        files_synced: 5
      }
    )
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should handle sync errors and broadcast failure" do
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).raises(StandardError.new("API Error"))
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Mock ActionCable broadcasts
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      {
        type: 'sync_started',
        integration_id: @cloud_integration.id,
        provider: 'google_drive'
      }
    )
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      {
        type: 'sync_failed',
        integration_id: @cloud_integration.id,
        provider: 'google_drive',
        error: 'API Error'
      }
    )
    
    # Should not raise the error, but handle it gracefully
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should handle authentication errors" do
    auth_error = CloudServices::AuthenticationError.new("Invalid token")
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).raises(auth_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).twice  # start and fail broadcasts
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should handle authorization errors" do
    auth_error = CloudServices::AuthorizationError.new("Access denied")
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).raises(auth_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).twice  # start and fail broadcasts
    
    CloudFileSyncJob.perform_now(@cloud_integration)
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
      
      service_mock = mock("#{provider}_service")
      service_mock.expects(:sync_files).returns(3)
      
      service_class.expects(:new).with(integration).returns(service_mock)
      ActionCable.server.expects(:broadcast).twice  # start and complete
      
      CloudFileSyncJob.perform_now(integration)
    end
  end

  test "should handle network timeouts" do
    timeout_error = Net::TimeoutError.new("Request timeout")
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).raises(timeout_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      has_entries(type: 'sync_failed', error: 'Request timeout')
    )
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      has_entries(type: 'sync_started')
    )
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should handle JSON parsing errors" do
    json_error = JSON::ParserError.new("Invalid JSON")
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).raises(json_error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).twice
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should broadcast to correct channel" do
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).returns(2)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Verify the channel name format
    expected_channel = "cloud_sync_#{@cloud_integration.id}"
    
    ActionCable.server.expects(:broadcast).with(expected_channel, anything).twice
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should include correct data in broadcast messages" do
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).returns(10)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Test start broadcast
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      {
        type: 'sync_started',
        integration_id: @cloud_integration.id,
        provider: 'google_drive'
      }
    )
    
    # Test completion broadcast
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      {
        type: 'sync_completed', 
        integration_id: @cloud_integration.id,
        provider: 'google_drive',
        files_synced: 10
      }
    )
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should handle zero files synced" do
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).returns(0)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    ActionCable.server.expects(:broadcast).with(
      anything,
      has_entries(type: 'sync_completed', files_synced: 0)
    )
    ActionCable.server.expects(:broadcast).with(anything, has_entries(type: 'sync_started'))
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should be retryable on transient errors" do
    # Test that the job is configured for retries
    assert_equal CloudFileSyncJob.retry_on, [Net::TimeoutError, CloudServices::ApiError]
  end

  test "should not retry on authentication errors" do
    # Authentication errors should not be retried as they require user intervention
    assert_includes CloudFileSyncJob.discard_on, CloudServices::AuthenticationError
    assert_includes CloudFileSyncJob.discard_on, CloudServices::AuthorizationError
  end

  test "should handle service instantiation errors" do
    # Test when service class doesn't exist or fails to instantiate
    CloudServices::GoogleDriveService.expects(:new).raises(NameError.new("Service not found"))
    
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      has_entries(type: 'sync_failed', error: 'Service not found')
    )
    ActionCable.server.expects(:broadcast).with(
      "cloud_sync_#{@cloud_integration.id}",
      has_entries(type: 'sync_started')
    )
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should handle missing integration gracefully" do
    non_existent_id = 999999
    
    assert_raises(ActiveRecord::RecordNotFound) do
      CloudFileSyncJob.perform_now(non_existent_id)
    end
  end

  test "should work when ActionCable is not available" do
    # Simulate ActionCable server not being available
    ActionCable.stubs(:server).returns(nil)
    
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).returns(3)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    
    # Should not raise an error even if ActionCable is not available
    assert_nothing_raised do
      CloudFileSyncJob.perform_now(@cloud_integration)
    end
  end

  test "should use correct queue" do
    assert_equal :default, CloudFileSyncJob.queue_name
  end

  test "should log sync activity" do
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).returns(7)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    Rails.logger.expects(:info).with(includes("Starting cloud file sync"))
    Rails.logger.expects(:info).with(includes("Completed cloud file sync"))
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end

  test "should log sync errors" do
    error = StandardError.new("Sync failed")
    service_mock = mock('cloud_service')
    service_mock.expects(:sync_files).raises(error)
    
    CloudServices::GoogleDriveService.expects(:new).with(@cloud_integration).returns(service_mock)
    ActionCable.server.expects(:broadcast).twice
    
    Rails.logger.expects(:info).with(includes("Starting cloud file sync"))
    Rails.logger.expects(:error).with(includes("Cloud file sync failed"))
    
    CloudFileSyncJob.perform_now(@cloud_integration)
  end
end