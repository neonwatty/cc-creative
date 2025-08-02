require "google/apis/drive_v3"
require "googleauth"

module CloudServices
  class GoogleDriveService < BaseService
    SCOPES = [ "https://www.googleapis.com/auth/drive.readonly",
              "https://www.googleapis.com/auth/drive.file" ].freeze

    def initialize(integration)
      super
      @drive_service = Google::Apis::DriveV3::DriveService.new
      @drive_service.authorization = google_auth
    end

    # OAuth2 configuration for Google
    def self.oauth2_config
      {
        client_id: Rails.application.credentials.dig(:google, :client_id),
        client_secret: Rails.application.credentials.dig(:google, :client_secret),
        redirect_uri: build_callback_url("/cloud_integrations/google/callback"),
        scope: SCOPES.join(" "),
        access_type: "offline",
        prompt: "consent"
      }
    end

    # Generate OAuth2 authorization URL
    def self.authorization_url
      params = oauth2_config.slice(:client_id, :redirect_uri, :scope, :access_type, :prompt)
      params[:response_type] = "code"

      "https://accounts.google.com/o/oauth2/v2/auth?#{params.to_query}"
    end

    # Exchange authorization code for tokens
    def self.exchange_code(code)
      response = HTTParty.post("https://oauth2.googleapis.com/token", {
        body: {
          code: code,
          client_id: oauth2_config[:client_id],
          client_secret: oauth2_config[:client_secret],
          redirect_uri: oauth2_config[:redirect_uri],
          grant_type: "authorization_code"
        }
      })

      raise ApiError, "Failed to exchange code: #{response.body}" unless response.success?

      JSON.parse(response.body)
    end

    # List files from Google Drive
    def list_files(options = {})
      page_token = options[:page_token]
      query = options[:query] || "mimeType != 'application/vnd.google-apps.folder'"

      begin
        response = @drive_service.list_files(
          q: query,
          page_size: 100,
          page_token: page_token,
          fields: "files(id, name, mimeType, size, modifiedTime, webViewLink), nextPageToken"
        )

        files = response.files.map do |file|
          {
            id: file.id,
            name: file.name,
            mime_type: file.mime_type,
            size: file.size&.to_i,
            metadata: {
              modified_time: file.modified_time,
              web_view_link: file.web_view_link
            }
          }
        end

        {
          files: files,
          next_page_token: response.next_page_token
        }
      rescue Google::Apis::Error => e
        handle_google_api_error(e)
      end
    end

    # Import a file from Google Drive
    def import_file(file_id)
      begin
        file = @drive_service.get_file(file_id)

        content = case file.mime_type
        when "application/vnd.google-apps.document"
          # Export Google Docs as HTML
          @drive_service.export_file(file_id, "text/html")
        when "application/vnd.google-apps.spreadsheet"
          # Export Google Sheets as CSV
          @drive_service.export_file(file_id, "text/csv")
        when "application/vnd.google-apps.presentation"
          # Export Google Slides as PDF
          @drive_service.export_file(file_id, "application/pdf")
        else
          # Download regular files
          @drive_service.get_file(file_id, download_dest: StringIO.new)
        end

        {
          name: file.name,
          content: content,
          mime_type: file.mime_type,
          size: content.bytesize
        }
      rescue Google::Apis::Error => e
        handle_google_api_error(e)
      end
    end

    # Export a document to Google Drive
    def export_document(document, options = {})
      folder_id = options[:folder_id] || "root"

      file_metadata = {
        name: document.title,
        parents: [ folder_id ]
      }

      # Convert document content to HTML
      content = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{CGI.escapeHTML(document.title)}</title>
        </head>
        <body>
          #{document.content}
        </body>
        </html>
      HTML

      begin
        file = @drive_service.create_file(
          file_metadata,
          fields: "id, name, webViewLink",
          upload_source: StringIO.new(content),
          content_type: "text/html"
        )

        # Create or update cloud file record
        cloud_file = integration.cloud_files.find_or_create_by(
          file_id: file.id
        )

        cloud_file.update!(
          provider: "google_drive",
          name: file.name,
          mime_type: "text/html",
          size: content.bytesize,
          document: document,
          metadata: { web_view_link: file.web_view_link },
          last_synced_at: Time.current
        )

        cloud_file
      rescue Google::Apis::Error => e
        handle_google_api_error(e)
      end
    end

    private

    def google_auth
      # Create Google auth credentials from tokens
      Google::Auth::UserRefreshCredentials.new(
        client_id: Rails.application.credentials.dig(:google, :client_id),
        client_secret: Rails.application.credentials.dig(:google, :client_secret),
        scope: SCOPES,
        access_token: integration.access_token,
        refresh_token: integration.refresh_token,
        expires_at: integration.expires_at
      )
    end

    def oauth2_refresh_request
      response = HTTParty.post("https://oauth2.googleapis.com/token", {
        body: {
          refresh_token: integration.refresh_token,
          client_id: Rails.application.credentials.dig(:google, :client_id),
          client_secret: Rails.application.credentials.dig(:google, :client_secret),
          grant_type: "refresh_token"
        }
      })

      raise ApiError, "Failed to refresh token: #{response.body}" unless response.success?

      JSON.parse(response.body)
    end

    def handle_google_api_error(error)
      case error.status_code
      when 401
        raise AuthenticationError, "Google authentication failed: #{error.message}"
      when 403
        raise AuthorizationError, "Google authorization failed: #{error.message}"
      when 404
        raise NotFoundError, "Google resource not found: #{error.message}"
      else
        raise ApiError, "Google API error: #{error.message}"
      end
    end
  end
end
