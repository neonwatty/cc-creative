# frozen_string_literal: true

class CloudProviderComponent < ViewComponent::Base
  def initialize(provider:, integration: nil, show_stats: true, show_actions: true)
    @provider = provider
    @integration = integration
    @show_stats = show_stats
    @show_actions = show_actions
  end

  private

  attr_reader :provider, :integration, :show_stats, :show_actions

  def connected?
    integration.present? && integration&.active?
  end

  def provider_name
    case provider
    when 'google_drive'
      'Google Drive'
    when 'dropbox'
      'Dropbox'
    when 'notion'
      'Notion'
    else
      provider.humanize
    end
  end

  def provider_icon_class
    "provider-icon provider-icon--#{provider}"
  end

  def status_badge_class
    if connected?
      'status-badge status-badge--connected'
    else
      'status-badge status-badge--disconnected'
    end
  end

  def status_text
    if connected?
      if integration.expired?
        'Token Expired'
      elsif integration.needs_refresh?
        'Needs Refresh'
      else
        'Connected'
      end
    else
      'Not Connected'
    end
  end

  def file_count
    integration&.cloud_files&.count || 0
  end

  def last_sync_text
    return 'Never' unless integration&.cloud_files&.any?
    
    last_sync = integration.cloud_files.order(:last_synced_at).last&.last_synced_at
    return 'Never' unless last_sync
    
    time_ago_in_words(last_sync) + ' ago'
  end

  def connect_url
    "/cloud_integrations/new?provider=#{provider}"
  end

  def files_url
    return nil unless connected?
    "/cloud_integrations/#{integration.id}/cloud_files"
  end

  def disconnect_url
    return nil unless connected?
    "/cloud_integrations/#{integration.id}"
  end

  def provider_description
    case provider
    when 'google_drive'
      'Import documents from Google Drive and export your work back to Drive.'
    when 'dropbox'
      'Sync files with Dropbox for seamless document management.'
    when 'notion'
      'Connect to Notion to import pages and export documents as Notion pages.'
    else
      "Connect your #{provider_name} account to import and export documents."
    end
  end

  def integration_data
    return {} unless integration
    
    {
      id: integration.id,
      provider: integration.provider,
      active: integration.active?,
      expires_at: integration.expires_at,
      file_count: file_count,
      last_sync: integration.cloud_files.maximum(:last_synced_at)
    }
  end

  def oauth_controller_data
    return {} if connected?
    
    {
      controller: 'cloud-oauth',
      'cloud-oauth-provider-value': provider,
      'cloud-oauth-auth-url-value': connect_url,
      'cloud-oauth-width-value': oauth_popup_width,
      'cloud-oauth-height-value': oauth_popup_height
    }
  end

  def oauth_popup_width
    case provider
    when 'google_drive' then 500
    when 'dropbox' then 600
    when 'notion' then 700
    else 600
    end
  end

  def oauth_popup_height
    case provider
    when 'google_drive' then 600
    when 'dropbox' then 700
    when 'notion' then 800
    else 700
    end
  end

  def card_css_classes
    classes = ['provider-card', "provider-card--#{provider}"]
    classes << (connected? ? 'provider-card--connected' : 'provider-card--disconnected')
    classes << 'provider-card--expired' if integration&.expired?
    classes.join(' ')
  end

  def sync_status_data
    return {} unless connected?
    
    {
      'integration-id': integration.id,
      target: 'cloud-integration-manager.syncStatus'
    }
  end
end