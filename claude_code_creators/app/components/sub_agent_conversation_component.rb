# frozen_string_literal: true

class SubAgentConversationComponent < ViewComponent::Base
  def initialize(sub_agent:, current_user:, messages: nil)
    @sub_agent = sub_agent
    @current_user = current_user
    @messages = messages || sub_agent.claude_messages.includes(:claude_session).recent.limit(50).reverse
  end

  private

  attr_reader :sub_agent, :current_user, :messages

  def document
    @document ||= sub_agent.document
  end

  def conversation_container_classes
    "flex flex-col h-full bg-white"
  end

  def message_list_classes
    "flex-1 overflow-y-auto px-4 py-4 space-y-4"
  end

  def message_bubble_classes(message)
    base_classes = "max-w-3xl rounded-lg px-4 py-3"
    
    if message.user?
      "#{base_classes} ml-auto bg-blue-600 text-white"
    else
      "#{base_classes} bg-gray-100 text-gray-900"
    end
  end

  def message_wrapper_classes(message)
    if message.user?
      "flex justify-end"
    else
      "flex justify-start"
    end
  end

  def format_message_time(timestamp)
    if timestamp.today?
      timestamp.strftime("%l:%M %p")
    elsif timestamp.yesterday?
      "Yesterday at #{timestamp.strftime('%l:%M %p')}"
    else
      timestamp.strftime("%B %d at %l:%M %p")
    end
  end

  def input_form_classes
    "border-t border-gray-200 px-4 py-3 bg-gray-50"
  end

  def input_field_classes
    "w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
  end

  def send_button_classes(disabled: false)
    base_classes = "inline-flex items-center px-4 py-2 text-sm font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
    
    if disabled
      "#{base_classes} bg-gray-300 text-gray-500 cursor-not-allowed"
    else
      "#{base_classes} bg-blue-600 text-white hover:bg-blue-700"
    end
  end

  def merge_button_classes
    "inline-flex items-center px-3 py-1.5 text-sm font-medium bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
  end

  def loading_indicator_visible?
    sub_agent.active? && messages.any? && messages.last.user?
  end

  def can_merge_content?
    messages.any? { |m| m.assistant? && m.content.present? }
  end

  def agent_status_banner_classes
    base_classes = "px-4 py-2 text-sm font-medium"
    
    case sub_agent.status
    when "active"
      "#{base_classes} bg-green-50 text-green-800 border-b border-green-200"
    when "completed"
      "#{base_classes} bg-blue-50 text-blue-800 border-b border-blue-200"
    when "failed"
      "#{base_classes} bg-red-50 text-red-800 border-b border-red-200"
    when "paused"
      "#{base_classes} bg-yellow-50 text-yellow-800 border-b border-yellow-200"
    else
      "#{base_classes} bg-gray-50 text-gray-800 border-b border-gray-200"
    end
  end

  def format_message_content(message)
    if message.assistant?
      # Convert markdown to HTML for assistant messages
      simple_format(message.content, class: "whitespace-pre-wrap")
    else
      simple_format(message.content)
    end
  end

  def agent_icon(agent_type)
    agent_types = {
      "ruby-rails-expert" => "🚂",
      "javascript-package-expert" => "📦",
      "tailwind-css-expert" => "🎨",
      "test-runner-fixer" => "🧪",
      "error-debugger" => "🐛",
      "project-orchestrator" => "📋",
      "git-auto-commit" => "🔀"
    }
    agent_types[agent_type] || "🤖"
  end

  def empty_conversation?
    messages.empty?
  end

  def agent_introduction
    case sub_agent.agent_type
    when "ruby-rails-expert"
      "Hello! I'm your Rails/Ruby expert. I can help with backend development, models, controllers, and Rails best practices."
    when "javascript-package-expert"
      "Hi there! I'm your JavaScript expert. I can assist with frontend code, npm packages, and JavaScript frameworks."
    when "tailwind-css-expert"
      "Hey! I'm your Tailwind CSS expert. I'll help you with styling, responsive design, and UI components."
    when "test-runner-fixer"
      "Greetings! I'm the test runner. I can help write tests, fix failing specs, and improve test coverage."
    when "error-debugger"
      "Hello! I'm the error debugger. I'll help you track down bugs and resolve issues in your code."
    when "project-orchestrator"
      "Welcome! I'm the project orchestrator. I coordinate complex tasks and help plan your development workflow."
    when "git-auto-commit"
      "Hi! I'm the git auto-commit agent. I'll help manage your version control and create meaningful commits."
    else
      "Hello! I'm ready to assist you with your document."
    end
  end
end