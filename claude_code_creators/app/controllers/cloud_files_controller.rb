class CloudFilesController < ApplicationController
  # Authentication is already handled by ApplicationController via Authentication concern
  before_action :set_cloud_integration
  before_action :set_cloud_file, only: [ :import, :show ]

  def index
    @cloud_files = @cloud_integration.cloud_files
                                     .includes(:document)
                                     .limit(20)

    # Filter by importable status if requested
    if params[:importable] == "true"
      @cloud_files = @cloud_files.importable
    end

    # Load the files into memory to avoid extra queries
    files_array = @cloud_files.to_a

    # Sync files if requested or if last sync was over an hour ago
    # Use the already loaded files to check sync status
    if params[:sync] == "true" || files_array.empty? || sync_needed_for_files?(files_array)
      begin
        CloudFileSyncJob.perform_later(@cloud_integration)
        flash.now[:notice] = "Syncing files in the background..."
      rescue => e
        Rails.logger.error "Failed to enqueue sync job: #{e.message}"
        flash.now[:alert] = "Unable to sync files at this time. Please try again later."
      end
    end
  end

  def show
    # Show file details and import options
  end

  def import
    unless @cloud_file.importable?
      redirect_to cloud_integration_cloud_files_path(@cloud_integration),
                  alert: "This file type cannot be imported"
      return
    end

    # Queue import job
    CloudFileImportJob.perform_later(@cloud_file, current_user)

    redirect_to cloud_integration_cloud_files_path(@cloud_integration),
                notice: "File import queued. You'll be notified when it's ready."
  end

  def export
    @document = current_user.documents.find(params[:document_id])

    begin
      service = cloud_service_for(@cloud_integration)
      cloud_file = service.export_document(@document, export_options)

      redirect_to document_path(@document),
                  notice: "Document exported to #{@cloud_integration.provider_name}"
    rescue => e
      Rails.logger.error "Export error: #{e.message}"
      redirect_to document_path(@document),
                  alert: "Failed to export: #{e.message}"
    end
  end

  private

  def set_cloud_integration
    @cloud_integration = current_user.cloud_integrations.find(params[:cloud_integration_id])
  end

  def set_cloud_file
    @cloud_file = @cloud_integration.cloud_files.find(params[:id])
  end

  def sync_needed?
    last_file = @cloud_integration.cloud_files.order(:last_synced_at).last
    last_file.nil? || last_file.last_synced_at.nil? || last_file.last_synced_at < 1.hour.ago
  end

  def sync_needed_for_files?(files)
    return true if files.empty?

    # Find the most recently synced file from the already loaded array
    last_synced = files.max_by { |f| f.last_synced_at || Time.at(0) }
    last_synced.last_synced_at.nil? || last_synced.last_synced_at < 1.hour.ago
  end

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

  def export_options
    params.permit(:folder_id, :folder_path, :parent_page_id).to_h.symbolize_keys
  end
end
