# frozen_string_literal: true

class SubAgentSidebarComponent < ViewComponent::Base
  def initialize(document:, current_user:, active_agent: nil)
    @document = document
    @current_user = current_user
    @active_agent = active_agent
  end

  private

  attr_reader :document, :current_user, :active_agent

  def sub_agents
    @sub_agents ||= document.sub_agents.includes(:claude_messages).recent
  end

  def active_agents
    @active_agents ||= sub_agents.active
  end

  def completed_agents
    @completed_agents ||= sub_agents.completed
  end

  def agent_types
    [
      { value: "ruby-rails-expert", label: "Rails/Ruby Expert", icon: "🚂", description: "Backend development" },
      { value: "javascript-package-expert", label: "JavaScript Expert", icon: "📦", description: "Frontend & packages" },
      { value: "tailwind-css-expert", label: "Tailwind CSS Expert", icon: "🎨", description: "Styling & UI" },
      { value: "test-runner-fixer", label: "Test Runner", icon: "🧪", description: "Testing & QA" },
      { value: "error-debugger", label: "Error Debugger", icon: "🐛", description: "Bug fixing" },
      { value: "project-orchestrator", label: "Project Orchestrator", icon: "📋", description: "Planning & coordination" },
      { value: "git-auto-commit", label: "Git Auto-Commit", icon: "🔀", description: "Version control" }
    ]
  end

  def agent_icon(agent_type)
    agent_types.find { |type| type[:value] == agent_type }&.dig(:icon) || "🤖"
  end

  def status_badge_classes(status)
    base_classes = "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium badge"
    
    case status
    when "active"
      "#{base_classes} bg-green-500 text-white"
    when "completed"
      "#{base_classes} bg-gray-500 text-white"
    when "failed"
      "#{base_classes} bg-red-500 text-white"
    when "idle"
      "#{base_classes} bg-yellow-500 text-white"
    when "pending"
      "#{base_classes} bg-gray-100 text-gray-800"
    else
      "#{base_classes} bg-gray-100 text-gray-800"
    end
  end

  def status_icon(status)
    case status
    when "active"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path>
      </svg>'
    when "completed"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
      </svg>'
    when "failed"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
      </svg>'
    when "paused"
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"></path>
      </svg>'
    else
      '<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"></path>
      </svg>'
    end
  end

  def format_timestamp(timestamp)
    return "" unless timestamp
    
    if timestamp.today?
      timestamp.strftime("%l:%M %p")
    elsif timestamp.yesterday?
      "Yesterday"
    else
      timestamp.strftime("%b %d")
    end
  end

  def agent_selected?(agent)
    active_agent && active_agent.id == agent.id
  end

  def new_agent_button_classes
    "w-full inline-flex items-center justify-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
  end

  def empty_state_visible?
    sub_agents.empty?
  end
end