module CloudServices
  class BaseService
    attr_reader :integration, :user
    
    def initialize(integration)
      @integration = integration
      @user = integration.user
    end
    
    # Common OAuth2 configuration
    def oauth2_client
      raise NotImplementedError, "Subclasses must implement oauth2_client"
    end
    
    # Refresh access token if needed
    def refresh_token!
      return unless integration.needs_refresh?
      
      begin
        response = oauth2_refresh_request
        
        integration.update!(
          access_token: response['access_token'],
          refresh_token: response['refresh_token'] || integration.refresh_token,
          expires_at: calculate_expiry(response['expires_in'])
        )
        
        true
      rescue => e
        Rails.logger.error "Failed to refresh token for #{integration.provider}: #{e.message}"
        false
      end
    end
    
    # List files from the cloud service
    def list_files(options = {})
      raise NotImplementedError, "Subclasses must implement list_files"
    end
    
    # Import a file from cloud service
    def import_file(file_id)
      raise NotImplementedError, "Subclasses must implement import_file"
    end
    
    # Export a document to cloud service
    def export_document(document, options = {})
      raise NotImplementedError, "Subclasses must implement export_document"
    end
    
    # Sync files metadata
    def sync_files
      refresh_token! if integration.needs_refresh?
      
      result = list_files
      files = result.is_a?(Hash) ? result[:files] : result
      
      files.each do |file_data|
        cloud_file = integration.cloud_files.find_or_initialize_by(
          file_id: file_data[:id]
        )
        
        cloud_file.update!(
          provider: integration.provider,
          name: file_data[:name],
          mime_type: file_data[:mime_type],
          size: file_data[:size],
          metadata: file_data[:metadata] || {},
          last_synced_at: Time.current
        )
      end
      
      integration.cloud_files.synced.count
    end
    
    protected
    
    # Build callback URL with proper host and protocol
    def self.build_callback_url(path)
      options = Rails.application.config.action_mailer.default_url_options
      protocol = Rails.env.production? ? 'https' : 'http'
      host = options[:host]
      port = options[:port]
      
      url = "#{protocol}://#{host}"
      url += ":#{port}" if port && port != 80 && port != 443
      url += path
      url
    end
    
    # Calculate token expiry time
    def calculate_expiry(expires_in)
      return nil if expires_in.nil?
      Time.current + expires_in.seconds
    end
    
    # Common error handling
    def handle_api_error(error)
      case error
      when Net::HTTPUnauthorized
        raise AuthenticationError, "Invalid or expired credentials"
      when Net::HTTPForbidden
        raise AuthorizationError, "Access denied"
      when Net::HTTPNotFound
        raise NotFoundError, "Resource not found"
      else
        raise ApiError, "API request failed: #{error.message}"
      end
    end
    
    # Parse response body
    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      response.body
    end
    
    private
    
    def oauth2_refresh_request
      raise NotImplementedError, "Subclasses must implement oauth2_refresh_request"
    end
  end
  
  # Custom error classes
  class ApiError < StandardError; end
  class AuthenticationError < ApiError; end
  class AuthorizationError < ApiError; end
  class NotFoundError < ApiError; end
end