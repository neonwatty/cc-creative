# frozen_string_literal: true

class ContextItemPreviewComponent < ViewComponent::Base
  def initialize(context_item:)
    @context_item = context_item
  end

  def item_type_icon
    case @context_item.item_type
    when 'snippet'
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"></path></svg>'.html_safe
    when 'draft'
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>'.html_safe
    when 'version'
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'.html_safe
    end
  end

  def formatted_metadata
    return {} unless @context_item.metadata.present?
    @context_item.metadata
  end

  def truncated_content(length = 300)
    return "" unless @context_item.content.present?
    
    # Strip HTML tags for preview
    text = strip_tags(@context_item.content)
    text.truncate(length, separator: ' ')
  end

  private

  def strip_tags(html)
    ActionView::Base.full_sanitizer.sanitize(html)
  end
end
