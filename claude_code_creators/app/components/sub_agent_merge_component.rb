# frozen_string_literal: true

class SubAgentMergeComponent < ViewComponent::Base
  def initialize(sub_agent:, current_user:, merge_content: nil)
    @sub_agent = sub_agent
    @current_user = current_user
    @merge_content = merge_content || extract_mergeable_content
  end

  private

  attr_reader :sub_agent, :current_user, :merge_content

  def document
    @document ||= sub_agent.document
  end

  def extract_mergeable_content
    # Get all assistant messages that could be merged
    assistant_messages = sub_agent.messages
                                  .where(role: "assistant")
                                  .order(created_at: :desc)
                                  .limit(10)

    # Combine recent assistant responses
    assistant_messages.map(&:content).join("\n\n---\n\n")
  end

  def dialog_classes
    "fixed inset-0 z-50 overflow-y-auto"
  end

  def backdrop_classes
    "fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
  end

  def dialog_panel_classes
    "relative bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:max-w-3xl sm:w-full"
  end

  def header_classes
    "bg-gray-50 px-6 py-4 border-b border-gray-200"
  end

  def content_preview_classes
    "bg-gray-50 border border-gray-200 rounded-lg p-4 max-h-96 overflow-y-auto"
  end

  def button_classes(variant = :primary)
    base_classes = "inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2"

    case variant
    when :primary
      "#{base_classes} bg-green-600 text-white hover:bg-green-700 focus:ring-green-500"
    when :secondary
      "#{base_classes} bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-blue-500"
    when :cancel
      "#{base_classes} bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-gray-500"
    end
  end

  def merge_location_options
    [
      { value: "cursor", label: "Insert at cursor", description: "Insert at the current cursor location" },
      { value: "end", label: "Append to end", description: "Append to the end of the document" },
      { value: "beginning", label: "Insert at beginning", description: "Insert at the start of the document" },
      { value: "replace", label: "Replace entire document", description: "Replace all existing content" }
    ]
  end

  def format_content_preview(content)
    # Truncate very long content for preview
    truncated = content.length > 1000 ? "#{content[0..1000]}..." : content
    simple_format(truncated, class: "whitespace-pre-wrap text-sm text-gray-700")
  end

  def merge_summary
    message_count = sub_agent.messages.where(role: "assistant").count
    word_count_value = word_count(merge_content)

    "Merging #{message_count} assistant #{'response'.pluralize(message_count)} (#{word_count_value} words)"
  end

  def word_count(content)
    content.to_s.split.size
  end

  def assistant_message_count
    sub_agent.messages.where(role: "assistant").count
  end

  def has_content_to_merge?
    assistant_message_count > 0
  end

  def content_is_long?
    merge_content.length > 1000
  end

  def is_large_merge?
    assistant_message_count > 10 || word_count(merge_content) > 1000
  end

  def success_message_classes
    "rounded-md bg-green-50 p-4 mb-4"
  end

  def error_message_classes
    "rounded-md bg-red-50 p-4 mb-4"
  end

  def checkbox_input_classes
    "h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
  end

  def label_classes
    "ml-2 block text-sm text-gray-900"
  end

  def description_classes
    "ml-6 text-xs text-gray-500"
  end
end
