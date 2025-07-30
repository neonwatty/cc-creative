require "test_helper"

class CloudProviderComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:one)
    # Clean up existing integrations to avoid conflicts
    CloudIntegration.destroy_all
  end

  test "renders disconnected provider" do
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: nil,
      show_stats: true,
      show_actions: true
    ))

    assert_selector ".provider-card--google_drive"
    assert_selector ".provider-card--disconnected"
    assert_text "Google Drive"
    assert_text "Not Connected"
    assert_text "Import documents from Google Drive and export your work back to Drive."
    assert_selector "button", text: "Connect Google Drive"
  end

  test "renders connected provider" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 2.hours.from_now, # Far enough in future to avoid "needs refresh"
      settings: {}
    )
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: integration,
      show_stats: true,
      show_actions: true
    ))

    assert_selector ".provider-card--google_drive"
    assert_selector ".provider-card--connected"
    assert_text "Google Drive"
    assert_text "Connected"
    assert_selector "button", text: "Sync"
    assert_selector "button", text: "Disconnect"
    assert_selector "a", text: "Browse Files"
  end

  test "renders expired provider" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'dropbox',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 1.hour.ago,
      settings: {}
    )
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'dropbox',
      integration: integration,
      show_stats: true,
      show_actions: true
    ))

    assert_selector ".provider-card--dropbox"
    # Expired integration is not considered "connected", so it shows as disconnected
    assert_selector ".provider-card--disconnected"
    assert_text "Dropbox"
    assert_text "Not Connected"
    assert_selector "button", text: "Connect Dropbox"
  end

  test "renders provider needing refresh" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'notion',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 30.minutes.from_now,
      settings: {}
    )
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'notion',
      integration: integration,
      show_stats: true,
      show_actions: true
    ))

    assert_selector ".provider-card--notion"
    assert_text "Notion"
    assert_text "Needs Refresh"
    assert_text "Connection will expire soon"
  end

  test "renders without stats when show_stats is false" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 1.hour.from_now,
      settings: {}
    )
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: integration,
      show_stats: false,
      show_actions: true
    ))

    assert_no_selector ".provider-card__stats"
  end

  test "renders without actions when show_actions is false" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 1.hour.from_now,
      settings: {}
    )
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: integration,
      show_stats: true,
      show_actions: false
    ))

    assert_no_selector ".provider-card__actions"
  end

  test "shows file count and last sync for connected provider" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 1.hour.from_now,
      settings: {}
    )
    
    # Create some cloud files
    3.times do |i|
      integration.cloud_files.create!(
        provider: 'google_drive',
        file_id: "file_#{i}",
        name: "File #{i}",
        mime_type: 'text/plain',
        last_synced_at: (i + 1).hours.ago
      )
    end
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: integration,
      show_stats: true,
      show_actions: true
    ))

    assert_text "Files"
    assert_text "3"
    assert_text "Last Sync"
    assert_text "about 1 hour ago"
  end

  test "shows correct provider descriptions" do
    providers = {
      'google_drive' => 'Import documents from Google Drive and export your work back to Drive.',
      'dropbox' => 'Sync files with Dropbox for seamless document management.',
      'notion' => 'Connect to Notion to import pages and export documents as Notion pages.'
    }

    providers.each do |provider, description|
      rendered = render_inline(CloudProviderComponent.new(
        provider: provider,
        integration: nil,
        show_stats: true,
        show_actions: true
      ))

      assert_text description
    end
  end

  test "includes oauth controller data for disconnected providers" do
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: nil,
      show_stats: true,
      show_actions: true
    ))

    # The oauth controller data is added to the root div
    assert_selector ".provider-card[controller='cloud-oauth']"
    assert_selector "[cloud-oauth-provider-value='google_drive']"
    assert_selector "[cloud-oauth-auth-url-value='/cloud_integrations/new?provider=google_drive']"
  end

  test "includes sync status data for connected providers" do
    integration = CloudIntegration.create!(
      user: @user,
      provider: 'google_drive',
      access_token: 'test_token',
      refresh_token: 'test_refresh',
      expires_at: 1.hour.from_now,
      settings: {}
    )
    
    rendered = render_inline(CloudProviderComponent.new(
      provider: 'google_drive',
      integration: integration,
      show_stats: true,
      show_actions: true
    ))

    assert_selector "[data-integration-id='#{integration.id}']"
    # Check for the sync status element
    assert_selector ".provider-card__sync-status"
  end
end