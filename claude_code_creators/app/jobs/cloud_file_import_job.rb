class CloudFileImportJob < ApplicationJob
  queue_as :default
  
  def perform(cloud_file, user)
    return unless cloud_file.importable?
    
    begin
      service = cloud_service_for(cloud_file.cloud_integration)
      
      # Import file content
      file_data = service.import_file(cloud_file.file_id)
      
      # Create document from imported content
      document = user.documents.build(
        title: sanitize_title(file_data[:name]),
        description: "Imported from #{cloud_file.cloud_integration.provider_name}"
      )
      
      # Set content based on file type
      content = process_content(file_data[:content], file_data[:mime_type])
      document.content = content
      
      # Add import tag
      document.add_tag("imported-#{cloud_file.cloud_integration.provider}")
      document.add_tag("cloud-import")
      
      if document.save
        # Link cloud file to document
        cloud_file.update!(document: document)
        
        Rails.logger.info "Successfully imported #{cloud_file.name} as document #{document.id} for user #{user.email_address}"
        
        # Could send notification to user here
        # UserMailer.document_imported(user, document, cloud_file).deliver_later
        
      else
        Rails.logger.error "Failed to save imported document: #{document.errors.full_messages.join(', ')}"
        raise "Failed to save document: #{document.errors.full_messages.join(', ')}"
      end
      
    rescue => e
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