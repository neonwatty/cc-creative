# frozen_string_literal: true

class ContextSidebarComponent < ViewComponent::Base
  def initialize(document:, current_user:)
    @document = document
    @current_user = current_user
    @context_items = @document.context_items
                              .where(user: @current_user)
                              .ordered
  end

  def snippets
    @context_items.by_type('snippet')
  end

  def drafts
    @context_items.by_type('draft')
  end

  def versions
    @context_items.by_type('version')
  end

  def context_item_icon(item_type)
    case item_type
    when 'snippet'
      svg_icon_tag('snippet')
    when 'draft'
      svg_icon_tag('draft')
    when 'version'
      svg_icon_tag('version')
    end
  end

  private

  def svg_icon_tag(icon_type)
    case icon_type
    when 'snippet'
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"></path></svg>'.html_safe
    when 'draft'
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>'.html_safe
    when 'version'
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'.html_safe
    end
  end
end
