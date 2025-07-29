require_relative '../services/cloud_services/base_service'

class CloudFileImportJob < ApplicationJob
  queue_as :default
  discard_on CloudServices::AuthenticationError, CloudServices::AuthorizationError
  
  def self.discard_on
    [CloudServices::AuthenticationError, CloudServices::AuthorizationError]
  end
  
  def perform(cloud_file, user)
    return unless cloud_file.importable?
    
    begin
      # Broadcast import started
      ActionCable.server.broadcast(
        "cloud_import_#{user.id}",
        {
          type: 'import_started',
          file_id: cloud_file.id,
          file_name: cloud_file.name
        }
      )
      
      service = cloud_service_for(cloud_file.cloud_integration)
      
      # Import file content
      file_data = service.import_file(cloud_file.file_id)
      
      # Create document from imported content
      title = file_data[:title] || file_data[:name] || cloud_file.name
      
      # Ensure unique title
      sanitized_title = sanitize_title(title)
      if user.documents.exists?(title: sanitized_title)
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        sanitized_title = "#{sanitized_title} (#{timestamp})"
      end
      
      document = user.documents.build(
        title: sanitized_title,
        description: "Imported from #{cloud_file.cloud_integration.provider_name}"
      )
      
      # Set content based on file type
      content_type = file_data[:content_type] || file_data[:mime_type] || 'text/plain'
      content = process_content(file_data[:content], content_type)
      
      # Ensure content is not blank
      if content.blank?
        content = "<p>Document imported from #{cloud_file.name}</p>"
      end
      
      document.content = content
      
      # Add import tag if method exists
      if document.respond_to?(:add_tag)
        document.add_tag("imported-#{cloud_file.cloud_integration.provider}")
        document.add_tag("cloud-import")
      end
      
      ActiveRecord::Base.transaction do
        document.save!
        # Link cloud file to document
        cloud_file.update!(document: document)
        
        # Broadcast import completed
        ActionCable.server.broadcast(
          "cloud_import_#{user.id}",
          {
            type: 'import_completed',
            file_id: cloud_file.id,
            file_name: cloud_file.name,
            document_id: document.id
          }
        )
        
        Rails.logger.info "Successfully imported #{cloud_file.name} as document #{document.id} for user #{user.id}"
      end
      
    rescue CloudServices::AuthenticationError, CloudServices::AuthorizationError => e
      # Broadcast auth failure
      ActionCable.server.broadcast(
        "cloud_import_#{user.id}",
        {
          type: 'import_failed',
          file_id: cloud_file.id,
          file_name: cloud_file.name,
          error: e.message
        }
      )
      Rails.logger.error "Import error for cloud file #{cloud_file.id}: #{e.message}"
      # Don't retry auth errors - they're discarded
    rescue CloudServices::ApiError, CloudServices::NotFoundError => e
      # Handle service errors without re-raising
      ActionCable.server.broadcast(
        "cloud_import_#{user.id}",
        {
          type: 'import_failed',
          file_id: cloud_file.id,
          file_name: cloud_file.name,
          error: e.message
        }
      )
      Rails.logger.error "Import error for cloud file #{cloud_file.id}: #{e.message}"
      # Don't re-raise service errors
    rescue ActiveRecord::RecordInvalid => e
      # Handle database validation errors
      ActionCable.server.broadcast(
        "cloud_import_#{user.id}",
        {
          type: 'import_failed',
          file_id: cloud_file.id,
          file_name: cloud_file.name,
          error: e.message
        }
      )
      Rails.logger.error "Import error for cloud file #{cloud_file.id}: #{e.message}"
    rescue => e
      # Broadcast generic failure and re-raise for retry
      ActionCable.server.broadcast(
        "cloud_import_#{user.id}",
        {
          type: 'import_failed',
          file_id: cloud_file.id,
          file_name: cloud_file.name,
          error: e.message
        }
      )
      Rails.logger.error "Import error for cloud file #{cloud_file.id}: #{e.message}"
      raise e
    end
  end
  
  private
  
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
  
  def sanitize_title(title)
    # Handle nil or empty title
    return "Imported Document" if title.blank?
    
    # Remove file extension and clean up title
    title = File.basename(title, File.extname(title))
    title = title.gsub(/[^\w\s\-_]/, '').strip
    title.present? ? title : "Imported Document"
  end
  
  def process_content(raw_content, mime_type)
    case mime_type
    when 'text/plain'
      # Convert plain text to basic HTML paragraphs
      paragraphs = raw_content.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
      paragraphs.map { |p| "<p>#{CGI.escapeHTML(p)}</p>" }.join("\n")
      
    when 'text/html'
      # Clean up HTML content
      clean_html(raw_content)
      
    when 'text/markdown'
      # Convert Markdown to HTML (basic implementation)
      markdown_to_html(raw_content)
      
    when 'application/pdf'
      # For PDF, we'd need a gem like pdf-reader
      # For now, just indicate it's a PDF
      "<p><strong>PDF Import:</strong> #{CGI.escapeHTML(raw_content.truncate(500))}</p>"
      
    when 'application/vnd.google-apps.document'
      # Google Docs are exported as HTML
      clean_html(raw_content)
      
    else
      # Default: treat as plain text
      "<p>#{CGI.escapeHTML(raw_content.truncate(5000))}</p>"
    end
  end
  
  def clean_html(html_content)
    # Remove script tags and clean up HTML
    # In a real app, you'd want to use a proper HTML sanitizer like Sanitize
    cleaned = html_content.gsub(/<script[^>]*>.*?<\/script>/mi, '')
    cleaned = cleaned.gsub(/<style[^>]*>.*?<\/style>/mi, '')
    
    # Remove Google Docs specific styling that might break our layout
    cleaned = cleaned.gsub(/style\s*=\s*["'][^"']*["']/i, '')
    
    cleaned
  end
  
  def markdown_to_html(markdown_content)
    # Basic Markdown to HTML conversion
    # In a real app, you'd use a gem like redcarpet or kramdown
    html = markdown_content.dup
    
    # Headers
    html.gsub!(/^### (.+)$/, '<h3>\1</h3>')
    html.gsub!(/^## (.+)$/, '<h2>\1</h2>')
    html.gsub!(/^# (.+)$/, '<h1>\1</h1>')
    
    # Bold and italic
    html.gsub!(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    html.gsub!(/\*(.+?)\*/, '<em>\1</em>')
    
    # Paragraphs
    paragraphs = html.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
    paragraphs.map { |p| "<p>#{p}</p>" }.join("\n")
  end
end