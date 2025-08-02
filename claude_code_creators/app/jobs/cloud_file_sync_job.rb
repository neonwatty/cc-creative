class CloudFileSyncJob < ApplicationJob
  queue_as :default

  def perform(cloud_integration)
    return unless cloud_integration.active?

    begin
      service = cloud_service_for(cloud_integration)
      synced_count = service.sync_files

      Rails.logger.info "Synced #{synced_count} files for #{cloud_integration.provider} integration (User: #{cloud_integration.user.email_address})"

      # Update integration settings with last sync time
      cloud_integration.set_setting("last_sync_at", Time.current)
      cloud_integration.save!

    rescue CloudServices::AuthenticationError => e
      Rails.logger.error "Authentication error during sync for #{cloud_integration.provider}: #{e.message}"
      # Could notify user that re-authentication is needed

    rescue => e
      Rails.logger.error "Sync error for #{cloud_integration.provider}: #{e.message}"
      raise e
    end
  end

  private

  def cloud_service_for(integration)
    case integration.provider
    when "google_drive"
      CloudServices::GoogleDriveService.new(integration)
    when "dropbox"
      CloudServices::DropboxService.new(integration)
    when "notion"
      CloudServices::NotionService.new(integration)
    else
      raise "Unknown provider: #{integration.provider}"
    end
  end
end
