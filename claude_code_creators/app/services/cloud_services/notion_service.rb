require 'notion-ruby-client'
require 'nokogiri'

module CloudServices
  class NotionService < BaseService
    OAUTH_URL = 'https://api.notion.com/v1/oauth'
    
    def initialize(integration)
      super
      @client = Notion::Client.new(token: integration.access_token)
    end
    
    # OAuth2 configuration for Notion
    def self.oauth2_config
      {
        client_id: Rails.application.credentials.dig(:notion, :client_id),
        client_secret: Rails.application.credentials.dig(:notion, :client_secret),
        redirect_uri: build_callback_url('/cloud_integrations/notion/callback')
      }
    end
    
    # Generate OAuth2 authorization URL
    def self.authorization_url
      params = {
        client_id: oauth2_config[:client_id],
        redirect_uri: oauth2_config[:redirect_uri],
        response_type: 'code',
        owner: 'user'
      }
      
      "#{OAUTH_URL}/authorize?#{params.to_query}"
    end
    
    # Exchange authorization code for tokens
    def self.exchange_code(code)
      response = HTTParty.post("#{OAUTH_URL}/token", {
        headers: {
          'Authorization' => "Basic #{Base64.strict_encode64("#{oauth2_config[:client_id]}:#{oauth2_config[:client_secret]}")}",
          'Content-Type' => 'application/json'
        },
        body: {
          grant_type: 'authorization_code',
          code: code,
          redirect_uri: oauth2_config[:redirect_uri]
        }.to_json
      })
      
      raise ApiError, "Failed to exchange code: #{response.body}" unless response.success?
      
      JSON.parse(response.body)
    end
    
    # List pages from Notion
    def list_pages(options = {})
      start_cursor = options[:start_cursor]
      
      begin
        response = @client.search(
          filter: { property: 'object', value: 'page' },
          start_cursor: start_cursor,
          page_size: 100
        )
        
        files = response.results.map do |page|
          {
            id: page.id,
            name: extract_page_title(page),
            mime_type: 'application/x-notion-page',
            size: nil, # Notion doesn't provide size
            metadata: {
              url: page.url,
              created_time: page.created_time,
              last_edited_time: page.last_edited_time,
              parent_type: page.parent.type,
              parent_id: page.parent[page.parent.type.to_sym]
            }
          }
        end
        
        {
          files: files,
          next_cursor: response.next_cursor,
          has_more: response.has_more
        }
      rescue Notion::Api::Errors::NotionError => e
        handle_notion_api_error(e)
      end
    end
    
    alias_method :list_files, :list_pages
    
    # Import a page from Notion
    def import_page(page_id)
      begin
        # Get page details
        page = @client.page(page_id: page_id)
        
        # Get page content blocks
        blocks = []
        start_cursor = nil
        
        loop do
          response = @client.block_children(
            block_id: page_id,
            start_cursor: start_cursor,
            page_size: 100
          )
          
          blocks.concat(response.results)
          start_cursor = response.next_cursor
          
          break unless response.has_more
        end
        
        # Convert blocks to HTML
        content = blocks_to_html(blocks)
        title = extract_page_title(page)
        
        {
          name: title,
          content: content,
          mime_type: 'text/html',
          size: content.bytesize
        }
      rescue Notion::Api::Errors::NotionError => e
        handle_notion_api_error(e)
      end
    end
    
    alias_method :import_file, :import_page
    
    # Export a document to Notion
    def export_document(document, options = {})
      parent_page_id = options[:parent_page_id]
      
      begin
        # Create page properties
        properties = {
          'title' => {
            'title' => [
              {
                'type' => 'text',
                'text' => { 'content' => document.title }
              }
            ]
          }
        }
        
        # Create page
        page = @client.create_page(
          parent: parent_page_id ? { page_id: parent_page_id } : { type: 'workspace' },
          properties: properties
        )
        
        # Add content blocks
        blocks = html_to_blocks(document.content.to_s)
        
        if blocks.any?
          @client.update_block_children(
            block_id: page.id,
            children: blocks
          )
        end
        
        # Create or update cloud file record
        cloud_file = integration.cloud_files.find_or_create_by(
          file_id: page.id
        )
        
        cloud_file.update!(
          provider: 'notion',
          name: document.title,
          mime_type: 'application/x-notion-page',
          size: nil,
          document: document,
          metadata: {
            url: page.url,
            created_time: page.created_time,
            last_edited_time: page.last_edited_time
          },
          last_synced_at: Time.current
        )
        
        cloud_file
      rescue Notion::Api::Errors::NotionError => e
        handle_notion_api_error(e)
      end
    end
    
    private
    
    def extract_page_title(page)
      # Try to extract title from properties
      if page.properties && page.properties['title']
        title_property = page.properties['title']
        if title_property['title'] && title_property['title'].any?
          return title_property['title'].map { |t| t['plain_text'] }.join
        end
      end
      
      # Try other common property names
      %w[Title Name Page].each do |prop_name|
        if page.properties && page.properties[prop_name]
          prop = page.properties[prop_name]
          if prop['title'] && prop['title'].any?
            return prop['title'].map { |t| t['plain_text'] }.join
          end
        end
      end
      
      'Untitled'
    end
    
    def blocks_to_html(blocks)
      html_parts = blocks.map do |block|
        case block.type
        when 'paragraph'
          text = extract_rich_text(block.paragraph.rich_text)
          "<p>#{text}</p>"
        when 'heading_1'
          text = extract_rich_text(block.heading_1.rich_text)
          "<h1>#{text}</h1>"
        when 'heading_2'
          text = extract_rich_text(block.heading_2.rich_text)
          "<h2>#{text}</h2>"
        when 'heading_3'
          text = extract_rich_text(block.heading_3.rich_text)
          "<h3>#{text}</h3>"
        when 'bulleted_list_item'
          text = extract_rich_text(block.bulleted_list_item.rich_text)
          "<li>#{text}</li>"
        when 'numbered_list_item'
          text = extract_rich_text(block.numbered_list_item.rich_text)
          "<li>#{text}</li>"
        when 'quote'
          text = extract_rich_text(block.quote.rich_text)
          "<blockquote>#{text}</blockquote>"
        when 'code'
          text = extract_rich_text(block.code.rich_text)
          language = block.code.language
          "<pre><code class=\"language-#{language}\">#{CGI.escapeHTML(text)}</code></pre>"
        else
          # Skip unsupported block types
          ''
        end
      end
      
      html_parts.join("\n")
    end
    
    def extract_rich_text(rich_text_array)
      return '' unless rich_text_array
      
      rich_text_array.map do |rt|
        text = CGI.escapeHTML(rt['plain_text'])
        
        # Apply formatting
        if rt['annotations']
          text = "<strong>#{text}</strong>" if rt['annotations']['bold']
          text = "<em>#{text}</em>" if rt['annotations']['italic']
          text = "<u>#{text}</u>" if rt['annotations']['underline']
          text = "<s>#{text}</s>" if rt['annotations']['strikethrough']
          text = "<code>#{text}</code>" if rt['annotations']['code']
        end
        
        # Add link if present
        if rt['href']
          text = "<a href=\"#{CGI.escapeHTML(rt['href'])}\">#{text}</a>"
        end
        
        text
      end.join
    end
    
    def html_to_blocks(html_content)
      # Simple HTML to Notion blocks conversion
      # This is a basic implementation - could be expanded
      doc = Nokogiri::HTML::DocumentFragment.parse(html_content)
      blocks = []
      
      doc.children.each do |node|
        block = case node.name
        when 'p'
          {
            'object' => 'block',
            'type' => 'paragraph',
            'paragraph' => {
              'rich_text' => [{ 'type' => 'text', 'text' => { 'content' => node.text } }]
            }
          }
        when 'h1'
          {
            'object' => 'block',
            'type' => 'heading_1',
            'heading_1' => {
              'rich_text' => [{ 'type' => 'text', 'text' => { 'content' => node.text } }]
            }
          }
        when 'h2'
          {
            'object' => 'block',
            'type' => 'heading_2',
            'heading_2' => {
              'rich_text' => [{ 'type' => 'text', 'text' => { 'content' => node.text } }]
            }
          }
        when 'h3'
          {
            'object' => 'block',
            'type' => 'heading_3',
            'heading_3' => {
              'rich_text' => [{ 'type' => 'text', 'text' => { 'content' => node.text } }]
            }
          }
        when 'blockquote'
          {
            'object' => 'block',
            'type' => 'quote',
            'quote' => {
              'rich_text' => [{ 'type' => 'text', 'text' => { 'content' => node.text } }]
            }
          }
        else
          next
        end
        
        blocks << block if block
      end
      
      blocks
    end
    
    def handle_notion_api_error(error)
      case error.code
      when 'unauthorized'
        raise AuthenticationError, "Notion authentication failed: #{error.message}"
      when 'restricted_resource'
        raise AuthorizationError, "Notion access restricted: #{error.message}"
      when 'object_not_found'
        raise NotFoundError, "Notion resource not found: #{error.message}"
      else
        raise ApiError, "Notion API error: #{error.message}"
      end
    end
    
    # Notion doesn't use refresh tokens in the same way
    def oauth2_refresh_request
      # Notion tokens don't expire by default
      { 'access_token' => integration.access_token }
    end
  end
end