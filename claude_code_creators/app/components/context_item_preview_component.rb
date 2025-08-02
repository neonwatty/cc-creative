# frozen_string_literal: true

class ContextItemPreviewComponent < ViewComponent::Base
  include ActionView::Helpers::SanitizeHelper
  include ActionView::Helpers::TextHelper

  attr_reader :context_item

  renders_one :primary_action
  renders_many :secondary_actions

  def initialize(context_item:)
    @context_item = context_item
  end

  def render?
    context_item.present?
  end

  def modal_id
    "context-item-preview-#{context_item.id}"
  end

  def content_type_class
    case detect_content_type
    when :markdown
      "markdown-content"
    when :code
      "code-content"
    else
      "plain-text-content"
    end
  end

  def formatted_content
    case detect_content_type
    when :markdown
      sanitize_markdown(context_item.content)
    when :code
      prepare_code_content(context_item.content)
    else
      simple_format(sanitize(context_item.content))
    end
  end

  def code_language
    return nil unless detect_content_type == :code

    detect_language_from_content ||
    extract_language_from_metadata ||
    "plaintext"
  end

  def preview_data_attributes
    {
      controller: "context-item-preview",
      context_item_preview_id_value: context_item.id,
      context_item_preview_type_value: context_item.item_type,
      context_item_preview_content_type_value: detect_content_type.to_s,
      context_item_preview_modal_id_value: modal_id
    }
  end

  def item_type_badge_class
    case context_item.item_type
    when "snippet"
      "bg-blue-100 text-blue-800"
    when "draft"
      "bg-yellow-100 text-yellow-800"
    when "version"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  private

  def detect_content_type
    return :code if code_content?
    return :markdown if markdown_content?
    :plain_text
  end

  def markdown_content?
    # Check for common markdown patterns
    content = context_item.content
    return true if context_item.metadata&.dig("content_type") == "markdown"

    # Look for markdown indicators (excluding code blocks which are handled separately)
    content.match?(/^\#{1,6}\s+/m) || # Headers
    content.match?(/\*\*[^*]+\*\*/) || # Bold
    content.match?(/\[[^\]]+\]\([^)]+\)/) || # Links
    content.match?(/^[-*+]\s+/m) # Lists
  end

  def code_content?
    return true if context_item.metadata&.dig("content_type") == "code"
    return true if context_item.metadata&.dig("language").present?

    # Look for code indicators
    content = context_item.content

    # Check for fenced code blocks first (strongest indicator)
    return true if content.match?(/^```[\w]*\n.*\n```$/m)

    # Check for common programming language keywords
    return true if content.match?(/^\s*(def|class|module|function|const|let|var|import|require|from|export)\s+/m)

    # Check for code-like patterns (with more specificity)
    return true if content.match?(/[{};]\s*$/m) &&
                  content.length > 10 &&
                  content.count("{") > 0 &&
                  content.count("}") > 0

    false
  end

  def sanitize_markdown(content)
    # For now, just treat markdown as plain text with basic formatting
    # In a real app, you'd want to use a proper markdown processor like Redcarpet or Kramdown
    # and then sanitize the output

    # Basic markdown-to-HTML conversion for testing
    html_content = content
      .gsub(/^# (.+)$/, '<h1>\1</h1>')
      .gsub(/^## (.+)$/, '<h2>\1</h2>')
      .gsub(/^### (.+)$/, '<h3>\1</h3>')
      .gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
      .gsub(/\*([^*]+)\*/, '<em>\1</em>')
      .gsub(/\n\n/, "</p><p>")
      .prepend("<p>")
      .concat("</p>")

    # Allow safe markdown-related HTML tags
    allowed_tags = %w[
      p br strong em u i b code pre blockquote
      h1 h2 h3 h4 h5 h6 ul ol li a img hr
      table thead tbody tr td th
    ]

    allowed_attributes = {
      "a" => %w[href title target rel],
      "img" => %w[src alt title width height],
      "code" => %w[class],
      "pre" => %w[class data-language]
    }

    sanitize(html_content, tags: allowed_tags, attributes: allowed_attributes)
  end

  def prepare_code_content(content)
    # Remove any markdown code fence markers if present
    clean_content = content.gsub(/^```[\w]*\n?/, "").gsub(/\n?```$/, "")

    # Escape HTML to prevent XSS but preserve for syntax highlighting
    escaped_content = ERB::Util.html_escape(clean_content)

    content_tag(:pre,
      content_tag(:code,
        escaped_content,
        class: "language-#{code_language}",
        data: { language: code_language }
      ),
      class: "code-block",
      data: { controller: "syntax-highlight" }
    )
  end

  def detect_language_from_content
    content = context_item.content

    # Check for fenced code block with language
    if match = content.match(/^```(\w+)/)
      return match[1]
    end

    # Detect by file extension patterns in content
    return "ruby" if content.match?(/\.rb\b/) || content.match?(/^\s*(class|module|def|end)\s+/)
    return "javascript" if content.match?(/\.js\b/) || content.match?(/^\s*(function|const|let|var)\s+/)
    return "css" if content.match?(/\.css\b/) || content.match?(/^\s*[.#][\w-]+\s*\{/)
    return "html" if content.match?(/\.html?\b/) || content.match?(/^\s*<[^>]+>/)
    return "sql" if content.match?(/^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\s+/i)

    nil
  end

  def extract_language_from_metadata
    context_item.metadata&.dig("language") ||
    context_item.metadata&.dig("file_type") ||
    context_item.metadata&.dig("syntax")
  end
end
