module CloudServices
  class DropboxService < BaseService
    BASE_URL = 'https://api.dropboxapi.com/2'
    CONTENT_URL = 'https://content.dropboxapi.com/2'
    OAUTH_URL = 'https://www.dropbox.com/oauth2'
    
    # OAuth2 configuration for Dropbox
    def self.oauth2_config
      {
        client_id: Rails.application.credentials.dig(:dropbox, :client_id),
        client_secret: Rails.application.credentials.dig(:dropbox, :client_secret),
        redirect_uri: build_callback_url('/cloud_integrations/dropbox/callback')
      }
    end
    
    # Generate OAuth2 authorization URL
    def self.authorization_url
      params = {
        client_id: oauth2_config[:client_id],
        redirect_uri: oauth2_config[:redirect_uri],
        response_type: 'code',
        token_access_type: 'offline'
      }
      
      "#{OAUTH_URL}/authorize?#{params.to_query}"
    end
    
    # Exchange authorization code for tokens
    def self.exchange_code(code)
      response = HTTParty.post("#{BASE_URL.sub('/2', '')}/oauth2/token", {
        body: {
          code: code,
          client_id: oauth2_config[:client_id],
          client_secret: oauth2_config[:client_secret],
          redirect_uri: oauth2_config[:redirect_uri],
          grant_type: 'authorization_code'
        }
      })
      
      raise ApiError, "Failed to exchange code: #{response.body}" unless response.success?
      
      JSON.parse(response.body)
    end
    
    # List files from Dropbox
    def list_files(options = {})
      path = options[:path] || ''
      cursor = options[:cursor]
      
      begin
        if cursor
          # Continue from cursor
          response = api_request('/files/list_folder/continue', { cursor: cursor })
        else
          # Initial request
          response = api_request('/files/list_folder', {
            path: path,
            recursive: false,
            include_deleted: false,
            include_has_explicit_shared_members: false,
            include_mounted_folders: true,
            limit: 100
          })
        end
        
        files = response['entries'].select { |e| e['.tag'] == 'file' }.map do |file|
          {
            id: file['id'],
            name: file['name'],
            mime_type: mime_type_from_path(file['name']),
            size: file['size'],
            metadata: {
              path_lower: file['path_lower'],
              path_display: file['path_display'],
              rev: file['rev'],
              server_modified: file['server_modified']
            }
          }
        end
        
        {
          files: files,
          cursor: response['cursor'],
          has_more: response['has_more']
        }
      rescue => e
        handle_api_error(e)
      end
    end
    
    # Import a file from Dropbox
    def import_file(file_id)
      begin
        # Get file metadata first
        metadata = api_request('/files/get_metadata', { path: file_id })
        
        # Download file content
        response = HTTParty.post("#{CONTENT_URL}/files/download", {
          headers: {
            'Authorization' => "Bearer #{integration.access_token}",
            'Dropbox-API-Arg' => { path: file_id }.to_json
          }
        })
        
        raise ApiError, "Failed to download file" unless response.success?
        
        {
          name: metadata['name'],
          content: response.body,
          mime_type: mime_type_from_path(metadata['name']),
          size: metadata['size']
        }
      rescue => e
        handle_api_error(e)
      end
    end
    
    # Export a document to Dropbox
    def export_document(document, options = {})
      folder_path = options[:folder_path] || ''
      file_name = "#{document.title}.html"
      path = folder_path.present? ? "#{folder_path}/#{file_name}" : "/#{file_name}"
      
      # Convert document content to HTML
      content = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{CGI.escapeHTML(document.title)}</title>
        </head>
        <body>
          <h1>#{CGI.escapeHTML(document.title)}</h1>
          #{document.content.to_s}
        </body>
        </html>
      HTML
      
      begin
        # Upload file
        response = HTTParty.post("#{CONTENT_URL}/files/upload", {
          headers: {
            'Authorization' => "Bearer #{integration.access_token}",
            'Dropbox-API-Arg' => {
              path: path,
              mode: 'add',
              autorename: true,
              mute: false
            }.to_json,
            'Content-Type' => 'application/octet-stream'
          },
          body: content
        })
        
        raise ApiError, "Failed to upload file: #{response.body}" unless response.success?
        
        file_data = JSON.parse(response.body)
        
        # Create or update cloud file record
        cloud_file = integration.cloud_files.find_or_create_by(
          file_id: file_data['id']
        )
        
        cloud_file.update!(
          provider: 'dropbox',
          name: file_data['name'],
          mime_type: 'text/html',
          size: file_data['size'],
          document: document,
          metadata: {
            path_lower: file_data['path_lower'],
            path_display: file_data['path_display'],
            rev: file_data['rev']
          },
          last_synced_at: Time.current
        )
        
        cloud_file
      rescue => e
        handle_api_error(e)
      end
    end
    
    private
    
    def api_request(endpoint, body)
      response = HTTParty.post("#{BASE_URL}#{endpoint}", {
        headers: {
          'Authorization' => "Bearer #{integration.access_token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      })
      
      raise ApiError, "API request failed: #{response.body}" unless response.success?
      
      JSON.parse(response.body)
    end
    
    def oauth2_refresh_request
      response = HTTParty.post("#{BASE_URL.sub('/2', '')}/oauth2/token", {
        body: {
          refresh_token: integration.refresh_token,
          client_id: Rails.application.credentials.dig(:dropbox, :client_id),
          client_secret: Rails.application.credentials.dig(:dropbox, :client_secret),
          grant_type: 'refresh_token'
        }
      })
      
      raise ApiError, "Failed to refresh token: #{response.body}" unless response.success?
      
      JSON.parse(response.body)
    end
    
    def mime_type_from_path(path)
      extension = File.extname(path).downcase
      
      case extension
      when '.txt' then 'text/plain'
      when '.html', '.htm' then 'text/html'
      when '.pdf' then 'application/pdf'
      when '.doc' then 'application/msword'
      when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      when '.md' then 'text/markdown'
      else 'application/octet-stream'
      end
    end
  end
end