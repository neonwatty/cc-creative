# frozen_string_literal: true

class CloudSyncStatusComponent < ViewComponent::Base
  def initialize(integrations: [], current_user: nil, show_global: true, show_details: true)
    @integrations = integrations
    @current_user = current_user
    @show_global = show_global
    @show_details = show_details
  end

  private

  attr_reader :integrations, :current_user, :show_global, :show_details

  def component_data
    {
      controller: 'cloud-sync-status',
      'cloud-sync-status-user-id-value': current_user&.id,
      'cloud-sync-status-refresh-interval-value': 30000
    }
  end

  def component_css_classes
    classes = ['cloud-sync-status']
    classes << 'cloud-sync-status--global' if show_global
    classes << 'cloud-sync-status--detailed' if show_details
    classes.join(' ')
  end

  def has_integrations?
    integrations.any?
  end

  def connected_integrations
    @connected_integrations ||= integrations.select(&:active?)
  end

  def syncing_integrations
    # This would be determined by checking background job status
    # For now, we'll simulate based on recent sync activity
    @syncing_integrations ||= connected_integrations.select do |integration|
      # Check if sync was started recently (within last 5 minutes)
      integration.cloud_files.exists?(['last_synced_at > ?', 5.minutes.ago]) ||
      has_active_sync_job?(integration)
    end
  end

  def has_active_sync_job?(integration)
    # This would check for active CloudFileSyncJob instances
    # For now, return false as we don't have job tracking implemented
    false
  end

  def global_status
    return 'no_integrations' unless has_integrations?
    return 'syncing' if syncing_integrations.any?
    return 'connected' if connected_integrations.any?
    'disconnected'
  end

  def global_status_text
    case global_status
    when 'no_integrations'
      'No cloud integrations configured'
    when 'syncing'
      "Syncing #{syncing_integrations.count} integration#{syncing_integrations.count > 1 ? 's' : ''}..."
    when 'connected'
      "#{connected_integrations.count} integration#{connected_integrations.count > 1 ? 's' : ''} connected"
    when 'disconnected'
      'All integrations disconnected'
    else
      'Unknown status'
    end
  end

  def global_status_icon
    case global_status
    when 'no_integrations'
      'cloud-off'
    when 'syncing'
      'sync'
    when 'connected'
      'cloud-check'
    when 'disconnected'
      'cloud-off'
    else
      'cloud'
    end
  end

  def status_color_class
    case global_status
    when 'no_integrations'
      'sync-status--neutral'
    when 'syncing'
      'sync-status--syncing'
    when 'connected'
      'sync-status--success'
    when 'disconnected'
      'sync-status--error'
    else
      'sync-status--neutral'
    end
  end

  def total_files_count
    @total_files_count ||= connected_integrations.sum { |i| i.cloud_files.count }
  end

  def last_sync_time
    return nil unless connected_integrations.any?
    
    @last_sync_time ||= begin
      all_files = connected_integrations.flat_map(&:cloud_files)
      return nil if all_files.empty?
      
      all_files.filter_map(&:last_synced_at).max
    end
  end

  def last_sync_text
    return 'Never synced' unless last_sync_time
    
    "Last synced #{time_ago_in_words(last_sync_time)} ago"
  end

  def sync_progress_data
    return {} unless syncing_integrations.any?
    
    # This would be populated from actual job progress
    # For now, we'll return empty data
    {}
  end

  def integration_status_list
    return [] unless show_details
    
    integrations.map do |integration|
      {
        id: integration.id,
        name: integration.provider_name,
        provider: integration.provider,
        active: integration.active?,
        syncing: syncing_integrations.include?(integration),
        file_count: integration.cloud_files.count,
        last_sync: integration.cloud_files.maximum(:last_synced_at),
        error: integration.expired? ? 'Token expired' : nil
      }
    end
  end

  def render_integration_status(status)
    css_class = ['integration-status']
    css_class << 'integration-status--active' if status[:active]
    css_class << 'integration-status--syncing' if status[:syncing]
    css_class << 'integration-status--error' if status[:error]
    
    content_tag :div, class: css_class.join(' '), data: { 'integration-id': status[:id] } do
      concat(render_integration_icon(status))
      concat(render_integration_info(status))
      concat(render_integration_sync_indicator(status))
    end
  end

  def render_integration_icon(status)
    icon_class = "provider-icon provider-icon--#{status[:provider]}"
    
    content_tag :div, class: 'integration-status__icon' do
      content_tag :i, '', class: icon_class
    end
  end

  def render_integration_info(status)
    content_tag :div, class: 'integration-status__info' do
      concat(content_tag(:div, status[:name], class: 'integration-status__name'))
      concat(render_integration_meta(status))
    end
  end

  def render_integration_meta(status)
    meta_parts = []
    
    if status[:active]
      meta_parts << pluralize(status[:file_count], 'file')
      
      if status[:last_sync]
        meta_parts << "synced #{time_ago_in_words(status[:last_sync])} ago"
      else
        meta_parts << 'never synced'
      end
    else
      meta_parts << 'not connected'
    end
    
    if status[:error]
      meta_parts << status[:error]
    end
    
    content_tag :div, meta_parts.join(' • '), class: 'integration-status__meta'
  end

  def render_integration_sync_indicator(status)
    indicator_class = ['sync-indicator']
    indicator_text = 'Ready'
    
    if status[:error]
      indicator_class << 'sync-indicator--error'
      indicator_text = 'Error'
    elsif status[:syncing]
      indicator_class << 'sync-indicator--syncing'
      indicator_text = 'Syncing...'
    elsif status[:active]
      indicator_class << 'sync-indicator--ready'
      indicator_text = 'Ready'
    else
      indicator_class << 'sync-indicator--inactive'
      indicator_text = 'Inactive'
    end
    
    content_tag :div, class: 'integration-status__sync' do
      concat(content_tag(:div, '', class: indicator_class.join(' ')))
      concat(content_tag(:span, indicator_text, class: 'sync-indicator__text'))
    end
  end

  def render_sync_progress
    return unless syncing_integrations.any?
    
    content_tag :div, class: 'sync-progress' do
      concat(content_tag(:div, 'Syncing in progress...', class: 'sync-progress__text'))
      concat(render_progress_bar)
    end
  end

  def render_progress_bar
    # This would show actual progress from background jobs
    # For now, we'll show an indeterminate progress bar
    
    content_tag :div, class: 'progress-bar progress-bar--indeterminate' do
      content_tag :div, '', class: 'progress-bar__fill'
    end
  end

  def render_global_actions
    return unless show_global && connected_integrations.any?
    
    content_tag :div, class: 'sync-status__actions' do
      if syncing_integrations.any?
        content_tag(:span, 'Sync in progress...', class: 'sync-status__note')
      else
        content_tag(:button, 
                   class: 'btn btn--sm btn--secondary',
                   data: { action: 'click->cloud-sync-status#syncAll' }) do
          content_tag(:i, '', class: 'icon icon--sync') + ' Sync All'
        end
      end
    end
  end

  def render_empty_state
    content_tag :div, class: 'sync-status__empty' do
      concat(content_tag(:div, class: 'empty-state__icon') do
        content_tag(:i, '', class: 'icon icon--cloud-off')
      end)
      concat(content_tag(:h3, 'No Cloud Integrations', class: 'empty-state__title'))
      concat(content_tag(:p, 'Connect to cloud providers to sync your files.', class: 'empty-state__message'))
      concat(content_tag(:div, class: 'empty-state__actions') do
        link_to('Connect Provider', '/cloud_integrations', class: 'btn btn--primary')
      end)
    end
  end

  def auto_refresh?
    # Only auto-refresh if there are active syncs
    syncing_integrations.any?
  end

  def refresh_interval
    # Refresh every 5 seconds during sync, 30 seconds otherwise
    syncing_integrations.any? ? 5000 : 30000
  end
end