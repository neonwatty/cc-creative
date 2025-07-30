require "test_helper"

class CloudSyncStatusComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:one)
    # Clean up existing integrations to avoid conflicts
    CloudIntegration.destroy_all
  end

  test "renders global sync status" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      expires_at: 1.hour.from_now,
      settings: {}
    )

    rendered = render_inline(CloudSyncStatusComponent.new(
      integrations: [integration],
      current_user: @user,
      show_global: true,
      show_details: false
    ))

    assert_selector ".cloud-sync-status"
    # The component shows file count instead of integration count
    assert_text "0 files total"
  end

  test "renders with no integrations" do
    rendered = render_inline(CloudSyncStatusComponent.new(
      integrations: [],
      current_user: @user,
      show_global: true,
      show_details: false
    ))

    assert_selector ".cloud-sync-status"
    assert_text "No Cloud Integrations"
  end

  test "renders integration details when show_details is true" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      expires_at: 1.hour.from_now,
      settings: {}
    )

    # Create some cloud files
    integration.cloud_files.create!(
      provider: 'google_drive',
      file_id: 'file_1',
      name: 'Test File',
      mime_type: 'text/plain',
      last_synced_at: 30.minutes.ago
    )

    rendered = render_inline(CloudSyncStatusComponent.new(
      integrations: [integration],
      current_user: @user,
      show_global: false,
      show_details: true
    ))

    assert_selector ".cloud-sync-status"
    # The component shows provider name and sync info
    assert_text "Google Drive"
    assert_text "1 file"
  end

  test "shows sync status for multiple integrations" do
    google_integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      expires_at: 1.hour.from_now,
      settings: {}
    )

    dropbox_integration = CloudIntegration.create!(
      user: @user,
      provider: 'dropbox',
      access_token: 'test_token',
      expires_at: 1.hour.from_now,
      settings: {}
    )

    rendered = render_inline(CloudSyncStatusComponent.new(
      integrations: [google_integration, dropbox_integration],
      current_user: @user,
      show_global: true,
      show_details: false
    ))

    assert_selector ".cloud-sync-status"
    assert_text "0 files total"
  end

  test "handles expired integrations" do
    expired_integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      expires_at: 1.hour.ago,
      settings: {}
    )

    rendered = render_inline(CloudSyncStatusComponent.new(
      integrations: [expired_integration],
      current_user: @user,
      show_global: true,
      show_details: false
    ))

    assert_selector ".cloud-sync-status"
    # Expired integrations are still shown but as disconnected
    assert_text "All integrations disconnected"
  end

  test "shows last sync information" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      expires_at: 1.hour.from_now,
      settings: {}
    )

    # Create cloud files with different sync times
    integration.cloud_files.create!(
      provider: 'google_drive',
      file_id: 'file_1',
      name: 'Recent File',
      mime_type: 'text/plain',
      last_synced_at: 5.minutes.ago
    )

    integration.cloud_files.create!(
      provider: 'google_drive',
      file_id: 'file_2',
      name: 'Older File',
      mime_type: 'text/plain',
      last_synced_at: 2.hours.ago
    )

    rendered = render_inline(CloudSyncStatusComponent.new(
      integrations: [integration],
      current_user: @user,
      show_global: false,
      show_details: true
    ))

    assert_selector ".cloud-sync-status"
    # Should show sync information
    assert_text "2 files"
    assert_text "synced"
  end
end