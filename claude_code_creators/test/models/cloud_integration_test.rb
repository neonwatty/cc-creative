require "test_helper"

class CloudIntegrationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    
    # Clean up existing integrations to avoid conflicts
    CloudIntegration.destroy_all
    
    # Create a fresh integration instead of using fixtures to avoid encryption issues
    @cloud_integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh_token',
      expires_at: 1.hour.from_now,
      settings: { scope: 'drive.readonly' }
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    integration = CloudIntegration.new(
      user: users(:two),  # Use a different user to avoid conflicts
      provider: 'google_drive',
      access_token: 'test_token'
    )
    assert integration.valid?
  end

  test "should require a user" do
    @cloud_integration.user = nil
    assert_not @cloud_integration.valid?
    assert_includes @cloud_integration.errors[:user], "must exist"
  end

  test "should require a provider" do
    @cloud_integration.provider = nil
    assert_not @cloud_integration.valid?
    assert_includes @cloud_integration.errors[:provider], "can't be blank"
  end

  test "should require a valid provider" do
    @cloud_integration.provider = 'invalid_provider'
    assert_not @cloud_integration.valid?
    assert_includes @cloud_integration.errors[:provider], "is not included in the list"
  end

  test "should allow all supported providers" do
    CloudIntegration::PROVIDERS.each_with_index do |provider, index|
      # Use different users or destroy existing to avoid conflicts
      CloudIntegration.where(provider: provider).destroy_all
      
      integration = CloudIntegration.new(
        user: @user,
        provider: provider,
        access_token: 'test_token'
      )
      assert integration.valid?, "#{provider} should be valid"
    end
  end

  test "should require access token" do
    @cloud_integration.access_token = nil
    assert_not @cloud_integration.valid?
    assert_includes @cloud_integration.errors[:access_token], "can't be blank"
  end

  test "should enforce uniqueness of provider per user" do
    duplicate = CloudIntegration.new(
      user: @cloud_integration.user,
      provider: @cloud_integration.provider,
      access_token: 'different_token'
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "already has an integration for this provider"
  end

  test "should allow same provider for different users" do
    different_user = users(:two)
    integration = CloudIntegration.new(
      user: different_user,
      provider: @cloud_integration.provider,
      access_token: 'test_token'
    )
    assert integration.valid?
  end

  # Association Tests
  test "should belong to user" do
    assert_respond_to @cloud_integration, :user
    assert_instance_of User, @cloud_integration.user
  end

  test "should have many cloud files" do
    assert_respond_to @cloud_integration, :cloud_files
    # Create a cloud file to test the association
    cloud_file = @cloud_integration.cloud_files.create!(
      provider: 'google_drive',
      file_id: 'test_file_id',
      name: 'test.txt',
      mime_type: 'text/plain'
    )
    assert_includes @cloud_integration.cloud_files, cloud_file
  end

  test "should destroy dependent cloud files" do
    # Ensure clean state
    CloudFile.destroy_all
    
    cloud_file = @cloud_integration.cloud_files.create!(
      provider: 'google_drive',
      file_id: 'test_file_id',
      name: 'test.txt',
      mime_type: 'text/plain'
    )
    
    assert_difference('CloudFile.count', -1) do
      @cloud_integration.destroy
    end
  end

  # Scope Tests
  test "active scope should return only active integrations" do
    # Create expired integration
    expired = CloudIntegration.create!(
      user: users(:two),
      provider: 'dropbox',
      access_token: 'expired_token',
      expires_at: 1.hour.ago
    )
    
    # Create active integration
    active = CloudIntegration.create!(
      user: users(:two),
      provider: 'notion',
      access_token: 'active_token',
      expires_at: 1.hour.from_now
    )

    active_integrations = CloudIntegration.active
    assert_includes active_integrations, active
    assert_not_includes active_integrations, expired
  end

  test "expired scope should return only expired integrations" do
    # Create expired integration
    expired = CloudIntegration.create!(
      user: users(:two),
      provider: 'dropbox',
      access_token: 'expired_token',
      expires_at: 1.hour.ago
    )
    
    # Create active integration
    active = CloudIntegration.create!(
      user: users(:two),
      provider: 'notion',
      access_token: 'active_token',
      expires_at: 1.hour.from_now
    )

    expired_integrations = CloudIntegration.expired
    assert_includes expired_integrations, expired
    assert_not_includes expired_integrations, active
  end

  test "for_provider scope should filter by provider" do
    google_integration = CloudIntegration.create!(
      user: users(:two),
      provider: 'google_drive',
      access_token: 'google_token'
    )

    google_integrations = CloudIntegration.for_provider('google_drive')
    assert_includes google_integrations, google_integration
  end

  # Instance Method Tests
  test "active? should return true for non-expiring tokens" do
    @cloud_integration.expires_at = nil
    assert @cloud_integration.active?
  end

  test "active? should return true for future expiration" do
    @cloud_integration.expires_at = 1.hour.from_now
    assert @cloud_integration.active?
  end

  test "active? should return false for past expiration" do
    @cloud_integration.expires_at = 1.hour.ago
    assert_not @cloud_integration.active?
  end

  test "expired? should be inverse of active?" do
    @cloud_integration.expires_at = 1.hour.from_now
    assert_not @cloud_integration.expired?
    
    @cloud_integration.expires_at = 1.hour.ago
    assert @cloud_integration.expired?
  end

  test "needs_refresh? should return false for non-expiring tokens" do
    @cloud_integration.expires_at = nil
    assert_not @cloud_integration.needs_refresh?
  end

  test "needs_refresh? should return true when expiring soon" do
    @cloud_integration.expires_at = 30.minutes.from_now
    assert @cloud_integration.needs_refresh?
  end

  test "needs_refresh? should return false when not expiring soon" do
    @cloud_integration.expires_at = 2.hours.from_now
    assert_not @cloud_integration.needs_refresh?
  end

  # Settings Methods Tests
  test "get_setting should return setting value" do
    @cloud_integration.settings = { 'key' => 'value', 'nested' => { 'inner' => 'data' } }
    assert_equal 'value', @cloud_integration.get_setting('key')
    assert_equal({ 'inner' => 'data' }, @cloud_integration.get_setting('nested'))
  end

  test "get_setting should return nil for non-existent key" do
    @cloud_integration.settings = { 'key' => 'value' }
    assert_nil @cloud_integration.get_setting('nonexistent')
  end

  test "set_setting should set setting value" do
    @cloud_integration.set_setting('new_key', 'new_value')
    assert_equal 'new_value', @cloud_integration.settings['new_key']
  end

  test "set_setting should initialize settings if nil" do
    @cloud_integration.settings = nil
    @cloud_integration.set_setting('key', 'value')
    assert_equal({ 'key' => 'value' }, @cloud_integration.settings)
  end

  # Provider Helper Tests
  test "provider helper methods should work correctly" do
    @cloud_integration.provider = 'google_drive'
    assert @cloud_integration.google_drive?
    assert_not @cloud_integration.dropbox?
    assert_not @cloud_integration.notion?

    @cloud_integration.provider = 'dropbox'
    assert_not @cloud_integration.google_drive?
    assert @cloud_integration.dropbox?
    assert_not @cloud_integration.notion?

    @cloud_integration.provider = 'notion'
    assert_not @cloud_integration.google_drive?
    assert_not @cloud_integration.dropbox?
    assert @cloud_integration.notion?
  end

  test "provider_name should return human readable names" do
    @cloud_integration.provider = 'google_drive'
    assert_equal 'Google Drive', @cloud_integration.provider_name

    @cloud_integration.provider = 'dropbox'
    assert_equal 'Dropbox', @cloud_integration.provider_name

    @cloud_integration.provider = 'notion'
    assert_equal 'Notion', @cloud_integration.provider_name
  end

  # Encryption Tests
  test "should encrypt access token" do
    # Use a different provider to avoid conflicts
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'dropbox',
      access_token: 'secret_token'
    )
    
    # The stored value should be encrypted (different from plain text)
    raw_value = integration.attributes_before_type_cast['access_token']
    assert_not_equal 'secret_token', raw_value
    
    # But the decrypted value should match
    assert_equal 'secret_token', integration.access_token
  end

  test "should encrypt refresh token" do
    # Use a different provider to avoid conflicts
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'notion',
      access_token: 'access_token',
      refresh_token: 'secret_refresh'
    )
    
    # The stored value should be encrypted (different from plain text)
    raw_value = integration.attributes_before_type_cast['refresh_token']
    assert_not_equal 'secret_refresh', raw_value
    
    # But the decrypted value should match
    assert_equal 'secret_refresh', integration.refresh_token
  end

  # JSON Serialization Tests
  test "should serialize settings as JSON" do
    settings_hash = { 'scope' => 'read_write', 'permissions' => ['files', 'folders'] }
    @cloud_integration.settings = settings_hash
    @cloud_integration.save!
    
    @cloud_integration.reload
    assert_equal settings_hash, @cloud_integration.settings
  end
end
