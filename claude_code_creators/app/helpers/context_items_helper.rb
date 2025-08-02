# frozen_string_literal: true

module ContextItemsHelper
  # Renders a context item preview modal component
  #
  # @param context_item [ContextItem] the context item to preview
  # @param options [Hash] additional options for customization
  # @return [String] rendered HTML for the preview modal
  def context_item_preview_modal(context_item, options = {}, &block)
    return unless context_item

    component = ContextItemPreviewComponent.new(context_item: context_item)

    if block_given?
      render(component, &block)
    else
      render(component)
    end
  end

  # Creates a button that opens a context item preview modal
  #
  # @param context_item [ContextItem] the context item to preview
  # @param text [String] button text (optional)
  # @param options [Hash] additional HTML options for the button
  # @return [String] rendered HTML for the trigger button
  def context_item_preview_button(context_item, text: nil, **options)
    return unless context_item

    text ||= "Preview #{context_item.title.truncate(30)}"

    default_options = {
      type: "button",
      class: "inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
      data: {
        action: "click->context-sidebar#showPreview",
        context_item_id: context_item.id
      }
    }

    button_tag(text, **default_options.merge(options))
  end

  # Renders a compact context item card with preview capability
  #
  # @param context_item [ContextItem] the context item to display
  # @param options [Hash] additional options for customization
  # @return [String] rendered HTML for the context item card
  def context_item_card(context_item, options = {})
    return unless context_item

    content_tag :div,
      class: "bg-white overflow-hidden shadow rounded-lg border border-gray-200 hover:shadow-md transition-shadow duration-200 #{options[:class]}" do
      content_tag :div, class: "px-4 py-5 sm:p-6" do
        content_tag(:div, class: "flex items-start justify-between") do
          content_tag(:div, class: "flex-1 min-w-0") do
            # Title and type
            content_tag(:div, class: "flex items-center space-x-2 mb-2") do
              content_tag(:h3, context_item.title,
                class: "text-sm font-medium text-gray-900 truncate") +

              content_tag(:span, context_item.item_type.capitalize,
                class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{item_type_badge_classes(context_item.item_type)}")
            end +

            # Content preview
            content_tag(:p, truncate(strip_tags(context_item.content), length: 100),
              class: "text-sm text-gray-500 mb-3") +

            # Timestamp
            content_tag(:p, "#{time_ago_in_words(context_item.created_at)} ago",
              class: "text-xs text-gray-400")
          end +

          # Preview button
          content_tag(:div, class: "ml-4 flex-shrink-0") do
            context_item_preview_button(context_item,
              text: content_tag(:svg,
                content_tag(:path, "",
                  d: "M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z",
                  stroke: "currentColor",
                  fill: "none",
                  "stroke-width": "1.5"
                ) +
                content_tag(:path, "",
                  d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z",
                  stroke: "currentColor",
                  fill: "none",
                  "stroke-width": "1.5"
                ),
                xmlns: "http://www.w3.org/2000/svg",
                class: "h-4 w-4",
                fill: "none",
                viewBox: "0 0 24 24"
              ),
              class: "text-gray-400 hover:text-gray-600 p-1"
            )
          end
        end
      end
    end
  end

  # Returns the appropriate CSS classes for item type badges
  #
  # @param item_type [String] the type of context item
  # @return [String] CSS classes for the badge
  def item_type_badge_classes(item_type)
    case item_type
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

  # Detects and returns a user-friendly content type description
  #
  # @param context_item [ContextItem] the context item to analyze
  # @return [String] human-readable content type
  def context_item_content_type(context_item)
    return "Unknown" unless context_item

    component = ContextItemPreviewComponent.new(context_item: context_item)

    case component.send(:detect_content_type)
    when :markdown
      "Markdown"
    when :code
      language = component.code_language
      language ? "#{language.capitalize} Code" : "Code"
    else
      "Text"
    end
  end

  # Renders syntax highlighting indicator for code content
  #
  # @param context_item [ContextItem] the context item to check
  # @return [String] HTML for language indicator or empty string
  def syntax_language_indicator(context_item)
    return "" unless context_item

    component = ContextItemPreviewComponent.new(context_item: context_item)

    if component.send(:detect_content_type) == :code && component.code_language
      content_tag(:span, component.code_language.upcase,
        class: "inline-flex items-center px-2 py-1 rounded text-xs font-mono font-medium bg-gray-100 text-gray-800")
    else
      ""
    end
  end
end
