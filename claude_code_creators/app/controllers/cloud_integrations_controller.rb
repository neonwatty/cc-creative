class CloudIntegrationsController < ApplicationController
  # Authentication is already handled by ApplicationController via Authentication concern
  before_action :set_cloud_integration, only: [:show, :destroy]
  
  def index
    @cloud_integrations = current_user.cloud_integrations.includes(:cloud_files)
    @available_providers = CloudIntegration::PROVIDERS.map do |provider|
      {
        name: provider,
        display_name: provider.humanize,
        connected: @cloud_integrations.exists?(provider: provider),
        integration: @cloud_integrations.find_by(provider: provider)
      }
    end
  end
  
  def new
    @provider = params[:provider]
    
    unless CloudIntegration::PROVIDERS.include?(@provider)
      redirect_to cloud_integrations_path, alert: "Invalid provider"
      return
    end
    
    # Check if already connected
    if current_user.cloud_integrations.exists?(provider: @provider)
      redirect_to cloud_integrations_path, notice: "Already connected to #{@provider.humanize}"
      return
    end
    
    # Redirect to OAuth authorization
    redirect_to authorization_url_for(@provider), allow_other_host: true
  end
  
  def destroy
    provider_name = @cloud_integration.provider_name
    @cloud_integration.destroy
    redirect_to cloud_integrations_path, notice: "Disconnected from #{provider_name}"
  end
  
  # OAuth callbacks
  def google_callback
    handle_oauth_callback('google_drive')
  end
  
  def dropbox_callback
    handle_oauth_callback('dropbox')
  end
  
  def notion_callback
    handle_oauth_callback('notion')
  end
  
  private
  
  def set_cloud_integration
    @cloud_integration = current_user.cloud_integrations.find(params[:id])
  end
  
  def authorization_url_for(provider)
    case provider
    when 'google_drive'
      CloudServices::GoogleDriveService.authorization_url
    when 'dropbox'
      CloudServices::DropboxService.authorization_url
    when 'notion'
      CloudServices::NotionService.authorization_url
    else
      raise "Unknown provider: #{provider}"
    end
  end
  
  def handle_oauth_callback(provider)
    if params[:error]
      redirect_to cloud_integrations_path, alert: "Authorization failed: #{params[:error_description] || params[:error]}"
      return
    end
    
    code = params[:code]
    
    unless code
      redirect_to cloud_integrations_path, alert: "Authorization code not received"
      return
    end
    
    begin
      # Exchange code for tokens
      token_data = case provider
      when 'google_drive'
        CloudServices::GoogleDriveService.exchange_code(code)
      when 'dropbox'
        CloudServices::DropboxService.exchange_code(code)
      when 'notion'
        CloudServices::NotionService.exchange_code(code)
      else
        raise "Unknown provider: #{provider}"
      end
      
      # Create or update integration
      integration = current_user.cloud_integrations.find_or_initialize_by(provider: provider)
      
      integration.update!(
        access_token: token_data['access_token'],
        refresh_token: token_data['refresh_token'],
        expires_at: calculate_expiry(token_data['expires_in']),
        settings: extract_additional_data(token_data, provider)
      )
      
      # Queue initial sync
      CloudFileSyncJob.perform_later(integration)
      
      redirect_to cloud_integrations_path, notice: "Successfully connected to #{provider.humanize}"
    rescue => e
      Rails.logger.error "OAuth callback error for #{provider}: #{e.message}"
      redirect_to cloud_integrations_path, alert: "Failed to connect: #{e.message}"
    end
  end
  
  def calculate_expiry(expires_in)
    return nil if expires_in.nil?
    Time.current + expires_in.seconds
  end
  
  def extract_additional_data(token_data, provider)
    case provider
    when 'google_drive'
      {
        scope: token_data['scope'],
        token_type: token_data['token_type']
      }
    when 'dropbox'
      {
        account_id: token_data['account_id'],
        uid: token_data['uid']
      }
    when 'notion'
      {
        bot_id: token_data['bot_id'],
        workspace_name: token_data['workspace_name'],
        workspace_icon: token_data['workspace_icon'],
        workspace_id: token_data['workspace_id']
      }
    else
      {}
    end
  end
end