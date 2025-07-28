class CloudFilesController < ApplicationController
  # Authentication is already handled by ApplicationController via Authentication concern
  before_action :set_cloud_integration
  before_action :set_cloud_file, only: [:import, :show]
  
  def index
    @cloud_files = @cloud_integration.cloud_files
                                     .includes(:document)
                                     .page(params[:page])
                                     .per(20)
    
    # Filter by importable status if requested
    if params[:importable] == 'true'
      @cloud_files = @cloud_files.importable
    end
    
    # Sync files if requested or if last sync was over an hour ago
    if params[:sync] == 'true' || @cloud_integration.cloud_files.empty? || sync_needed?
      CloudFileSyncJob.perform_later(@cloud_integration)
      flash.now[:notice] = "Syncing files in the background..."
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
    last_file.nil? || last_file.last_synced_at < 1.hour.ago
  end
  
  def cloud_service_for(integration)
    case integration.provider
    when 'google_drive'
      CloudServices::GoogleDriveService.new(integration)
    when 'dropbox'
      CloudServices::DropboxService.new(integration)
    when 'notion'
      CloudServices::NotionService.new(integration)
    else
      raise "Unknown provider: #{integration.provider}"
    end
  end
  
  def export_options
    params.permit(:folder_id, :folder_path, :parent_page_id).to_h.symbolize_keys
  end
end