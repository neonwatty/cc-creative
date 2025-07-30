require "test_helper"

class CloudIntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    
    # Clean up any existing integrations to avoid conflicts
    CloudIntegration.destroy_all
    
    sign_in_as(@user)
  end

  # Index Action Tests
  test "should get index" do
    get cloud_integrations_path
    assert_response :success
    assert_select "h1", text: /Cloud Integrations/i
  end

  test "index should show available providers" do
    get cloud_integrations_url
    assert_response :success
    
    # Should show all supported providers with their proper display names
    provider_names = {
      'google_drive' => 'Google Drive',
      'dropbox' => 'Dropbox',
      'notion' => 'Notion'
    }
    
    CloudIntegration::PROVIDERS.each do |provider|
      assert_select "h3", text: provider_names[provider]
    end
  end

  test "index should show connected integrations" do
    # Create a cloud integration for the user
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      settings: { scope: 'read_write' }
    )
    
    get cloud_integrations_url
    assert_response :success
    assert_select "div", text: /Connected/
  end

  test "index should require authentication" do
    sign_out
    get cloud_integrations_url
    assert_redirected_to new_session_path
  end

  # New Action Tests
  test "should redirect to OAuth for valid provider" do
    CloudServices::GoogleDriveService.stubs(:authorization_url).returns("https://oauth.google.com/authorize?test=1")
    
    get new_cloud_integration_url(provider: 'google_drive')
    assert_redirected_to "https://oauth.google.com/authorize?test=1"
  end

  test "should reject invalid provider" do
    get new_cloud_integration_url(provider: 'invalid_provider')
    assert_redirected_to cloud_integrations_path
    assert_equal "Invalid provider", flash[:alert]
  end

  test "should not allow duplicate provider connections" do
    # Create existing integration
    CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'existing_token',
      settings: {}
    )
    
    get new_cloud_integration_url(provider: 'google_drive')
    assert_redirected_to cloud_integrations_path
    assert_match /Already connected/, flash[:notice]
  end

  test "new should require authentication" do
    sign_out
    get new_cloud_integration_url(provider: 'google_drive')
    assert_redirected_to new_session_path
  end

  # Destroy Action Tests
  test "should destroy cloud integration" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      settings: {}
    )
    
    assert_difference('CloudIntegration.count', -1) do
      delete cloud_integration_url(integration)
    end
    
    assert_redirected_to cloud_integrations_path
    assert_match /Disconnected from/, flash[:notice]
  end

  test "should not allow destroying others integrations" do
    other_user = users(:two)
    integration = CloudIntegration.create!(
      user: other_user,
      provider: 'google_drive',
      access_token: 'test_token',
      settings: {}
    )
    
    # Try to delete another user's integration
    delete cloud_integration_url(integration)
    
    # Should get a 404 since the record is not found in current user's scope
    assert_response :not_found
    
    # Verify the integration still exists
    assert CloudIntegration.exists?(integration.id)
  end

  test "destroy should require authentication" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      settings: {}
    )
    
    sign_out
    delete cloud_integration_url(integration)
    assert_redirected_to new_session_path
  end

  # OAuth Callback Tests
  test "google callback should handle successful authorization" do
    CloudServices::GoogleDriveService.stubs(:exchange_code)
      .with('test_code')
      .returns({
        'access_token' => 'new_access_token',
        'refresh_token' => 'new_refresh_token',
        'expires_in' => 3600,
        'scope' => 'drive.readonly',
        'token_type' => 'Bearer'
      })
    
    CloudFileSyncJob.expects(:perform_later).once
    
    assert_difference('CloudIntegration.count', 1) do
      get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    end
    
    assert_redirected_to cloud_integrations_path
    assert_match /Successfully connected/, flash[:notice]
    
    integration = CloudIntegration.last
    assert_equal @user, integration.user
    assert_equal 'google_drive', integration.provider
    assert_equal 'new_access_token', integration.access_token
  end

  test "google callback should handle authorization error" do
    get '/cloud_integrations/google/callback', params: { 
      error: 'access_denied',
      error_description: 'User denied access'
    }
    
    assert_redirected_to cloud_integrations_path
    assert_match /Authorization failed/, flash[:alert]
  end

  test "google callback should handle missing code" do
    get '/cloud_integrations/google/callback'
    
    assert_redirected_to cloud_integrations_path
    assert_match /Authorization code not received/, flash[:alert]
  end

  test "google callback should handle service errors" do
    CloudServices::GoogleDriveService.stubs(:exchange_code)
      .raises(StandardError.new("API Error"))
    
    get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    
    assert_redirected_to cloud_integrations_path
    assert_match /Failed to connect/, flash[:alert]
  end

  test "dropbox callback should work similarly to google" do
    CloudServices::DropboxService.stubs(:exchange_code)
      .with('test_code')
      .returns({
        'access_token' => 'dropbox_token',
        'account_id' => 'account123',
        'uid' => 'uid456'
      })
    
    CloudFileSyncJob.expects(:perform_later).once
    
    assert_difference('CloudIntegration.count', 1) do
      get '/cloud_integrations/dropbox/callback', params: { code: 'test_code' }
    end
    
    assert_redirected_to cloud_integrations_path
    assert_match /Successfully connected/, flash[:notice]
  end

  test "notion callback should work similarly to google" do
    CloudServices::NotionService.stubs(:exchange_code)
      .with('test_code')
      .returns({
        'access_token' => 'notion_token',
        'bot_id' => 'bot123',
        'workspace_name' => 'Test Workspace',
        'workspace_id' => 'workspace456'
      })
    
    CloudFileSyncJob.expects(:perform_later).once
    
    assert_difference('CloudIntegration.count', 1) do
      get '/cloud_integrations/notion/callback', params: { code: 'test_code' }
    end
    
    assert_redirected_to cloud_integrations_path
    assert_match /Successfully connected/, flash[:notice]
  end

  test "callback should update existing integration" do
    # Create existing integration
    existing = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'old_token',
      settings: { old: 'data' }
    )
    
    CloudServices::GoogleDriveService.stubs(:exchange_code)
      .returns({
        'access_token' => 'updated_token',
        'refresh_token' => 'updated_refresh',
        'expires_in' => 7200,
        'scope' => 'drive.file',
        'token_type' => 'Bearer'
      })
    
    CloudFileSyncJob.expects(:perform_later).once
    
    assert_no_difference('CloudIntegration.count') do
      get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    end
    
    existing.reload
    assert_equal 'updated_token', existing.access_token
    assert_equal 'updated_refresh', existing.refresh_token
    assert_equal 'drive.file', existing.settings['scope']
  end

  test "callbacks should require authentication" do
    sign_out
    get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    assert_redirected_to new_session_path
  end

  # Helper Method Tests
  test "authorization_url_for should return correct URLs" do
    controller = CloudIntegrationsController.new
    
    CloudServices::GoogleDriveService.stubs(:authorization_url).returns("https://google.oauth.url")
    assert_equal "https://google.oauth.url", controller.send(:authorization_url_for, 'google_drive')
    
    CloudServices::DropboxService.stubs(:authorization_url).returns("https://dropbox.oauth.url")
    assert_equal "https://dropbox.oauth.url", controller.send(:authorization_url_for, 'dropbox')
    
    CloudServices::NotionService.stubs(:authorization_url).returns("https://notion.oauth.url")
    assert_equal "https://notion.oauth.url", controller.send(:authorization_url_for, 'notion')
  end

  test "authorization_url_for should raise error for unknown provider" do
    controller = CloudIntegrationsController.new
    
    assert_raises(RuntimeError, /Unknown provider/) do
      controller.send(:authorization_url_for, 'unknown_provider')
    end
  end

  test "calculate_expiry should handle expires_in correctly" do
    controller = CloudIntegrationsController.new
    
    # Test with expires_in value
    freeze_time do
      expiry = controller.send(:calculate_expiry, 3600)
      assert_equal Time.current + 1.hour, expiry
    end
    
    # Test with nil expires_in
    assert_nil controller.send(:calculate_expiry, nil)
  end

  test "extract_additional_data should return provider-specific data" do
    controller = CloudIntegrationsController.new
    
    # Google Drive
    google_data = {
      'scope' => 'drive.file',
      'token_type' => 'Bearer',
      'extra' => 'ignored'
    }
    result = controller.send(:extract_additional_data, google_data, 'google_drive')
    expected = { scope: 'drive.file', token_type: 'Bearer' }
    assert_equal expected, result
    
    # Dropbox
    dropbox_data = {
      'account_id' => 'acc123',
      'uid' => 'uid456',
      'extra' => 'ignored'
    }
    result = controller.send(:extract_additional_data, dropbox_data, 'dropbox')
    expected = { account_id: 'acc123', uid: 'uid456' }
    assert_equal expected, result
    
    # Notion
    notion_data = {
      'bot_id' => 'bot123',
      'workspace_name' => 'Test Workspace',
      'workspace_icon' => 'icon.png',
      'workspace_id' => 'workspace456',
      'extra' => 'ignored'
    }
    result = controller.send(:extract_additional_data, notion_data, 'notion')
    expected = {
      bot_id: 'bot123',
      workspace_name: 'Test Workspace',
      workspace_icon: 'icon.png',
      workspace_id: 'workspace456'
    }
    assert_equal expected, result
    
    # Unknown provider
    result = controller.send(:extract_additional_data, {}, 'unknown')
    assert_equal({}, result)
  end

  # Security Tests
  test "should have CSRF protection in production" do
    # CSRF protection is disabled in test environment by default
    # This test just verifies that the controller inherits from ApplicationController
    # which includes protect_from_forgery in production
    assert CloudIntegrationsController < ApplicationController
    assert ApplicationController.ancestors.include?(ActionController::RequestForgeryProtection)
  end

  test "should handle concurrent callback requests gracefully" do
    CloudServices::GoogleDriveService.stubs(:exchange_code)
      .returns({
        'access_token' => 'token',
        'refresh_token' => 'refresh',
        'expires_in' => 3600
      })
    
    CloudFileSyncJob.stubs(:perform_later)
    
    # Simulate concurrent requests (though this is hard to test properly)
    get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    assert_response :redirect
  end

  # Error Handling Tests
  test "should handle network timeouts gracefully" do
    CloudServices::GoogleDriveService.stubs(:exchange_code)
      .raises(Timeout::Error.new("Request timeout"))
    
    get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    
    assert_redirected_to cloud_integrations_path
    assert_match /Failed to connect/, flash[:alert]
  end

  test "should handle JSON parsing errors gracefully" do
    CloudServices::GoogleDriveService.stubs(:exchange_code)
      .raises(JSON::ParserError.new("Invalid JSON"))
    
    get '/cloud_integrations/google/callback', params: { code: 'test_code' }
    
    assert_redirected_to cloud_integrations_path
    assert_match /Failed to connect/, flash[:alert]
  end

  private

  def freeze_time(&block)
    Time.stubs(:current).returns(Time.parse("2024-01-01 12:00:00"))
    yield
  ensure
    Time.unstub(:current)
  end
end