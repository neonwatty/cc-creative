# frozen_string_literal: true

class ContextSidebarComponent < ViewComponent::Base
  def initialize(document:, current_user:, active_tab: "snippets", sort_by: "recent", search_query: "", filter_type: "", date_from: nil, date_to: nil)
    @document = document
    @current_user = current_user
    @active_tab = active_tab
    @sort_by = sort_by
    @search_query = search_query
    @filter_type = filter_type
    @date_from = date_from
    @date_to = date_to
  end

  private

  attr_reader :document, :current_user, :active_tab, :sort_by, :search_query, :filter_type, :date_from, :date_to

  def context_items
    @context_items ||= document.context_items
  end

  def filtered_items(type)
    items = context_items.send(type.to_s)

    # Apply search and filters using the model's filtered_search scope
    items = items.filtered_search(
      query: search_query,
      item_type: filter_type.presence,
      date_from: date_from,
      date_to: date_to
    )

    # Apply sorting
    case sort_by
    when "recent"
      items.order(created_at: :desc)
    when "alphabetical"
      items.order(title: :asc)
    when "modified"
      items.order(updated_at: :desc)
    when "manual"
      items.ordered
    else
      items.recent
    end
  end

  def snippets
    @snippets ||= filtered_items(:snippets)
  end

  def drafts
    @drafts ||= filtered_items(:drafts)
  end

  def versions
    @versions ||= filtered_items(:versions)
  end

  def tab_classes(tab)
    base_classes = "px-4 py-2 text-sm font-medium rounded-t-lg transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"

    if tab == active_tab
      "#{base_classes} bg-white text-blue-600 border-b-2 border-blue-600"
    else
      "#{base_classes} text-gray-600 hover:text-gray-900 hover:bg-gray-50"
    end
  end

  def item_icon(type)
    case type
    when "snippet"
      "📋"
    when "draft"
      "📝"
    when "version"
      "📚"
    else
      "📄"
    end
  end

  def item_count(type)
    case type
    when :snippets
      snippets.count
    when :drafts
      drafts.count
    when :versions
      versions.count
    else
      0
    end
  end

  def format_date(date)
    if date.today?
      "Today at #{date.strftime('%l:%M %p')}"
    elsif date.yesterday?
      "Yesterday at #{date.strftime('%l:%M %p')}"
    elsif date > 7.days.ago
      date.strftime("%A at %l:%M %p")
    else
      date.strftime("%B %d, %Y")
    end
  end

  def truncate_content(content, length = 100)
    return "" if content.blank?

    plain_text = ActionText::Content.new(content).to_plain_text
    plain_text.truncate(length, separator: " ")
  end

  def search_active?
    search_query.present? || filter_type.present? || date_from.present? || date_to.present?
  end

  def search_results_count
    @search_results_count ||= begin
      count = 0
      count += snippets.count if active_tab == "snippets"
      count += drafts.count if active_tab == "drafts"
      count += versions.count if active_tab == "versions"
      count
    end
  end

  def date_range_options
    [
      [ "All time", "" ],
      [ "Today", "today" ],
      [ "This week", "week" ],
      [ "This month", "month" ],
      [ "Last 3 months", "quarter" ],
      [ "This year", "year" ]
    ]
  end

  def type_filter_options
    [
      [ "All types", "" ],
      [ "Snippets only", "snippet" ],
      [ "Drafts only", "draft" ],
      [ "Versions only", "version" ]
    ]
  end

  def highlighted_items(items)
    return items unless search_query.present?

    items.map do |item|
      highlights = item.search_highlights(search_query)
      {
        item: item,
        highlighted_title: highlights[:title] || item.title,
        highlighted_content: highlights[:content] || truncate_content(item.content)
      }
    end
  end
end
