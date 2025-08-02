class SubAgent < ApplicationRecord
  # Associations
  belongs_to :document
  belongs_to :user
  has_many :messages, class_name: "SubAgentMessage", dependent: :destroy
  has_many :claude_messages, foreign_key: :sub_agent_name, primary_key: :name

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :agent_type, presence: true, inclusion: {
    in: %w[ruby-rails-expert javascript-package-expert tailwind-css-expert
           test-runner-fixer error-debugger project-orchestrator git-auto-commit custom]
  }
  validates :status, presence: true, inclusion: { in: %w[active idle completed] }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :idle, -> { where(status: "idle") }
  scope :completed, -> { where(status: "completed") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_document, ->(document) { where(document: document) }
  scope :by_agent_type, ->(type) { where(agent_type: type) }

  # Callbacks
  after_initialize :set_defaults
  before_save :ensure_context_hash

  # Status state machine methods
  def activate!
    update!(status: "active")
  end

  def deactivate!
    update!(status: "idle")
  end

  def complete!
    update!(status: "completed")
  end

  def pause!
    # Since we don't have a 'paused' status, we'll set it to idle
    update!(status: "idle")
  end

  # Status checks
  def active?
    status == "active"
  end

  def idle?
    status == "idle"
  end

  def completed?
    status == "completed"
  end

  # Agent type checks
  def backend_agent?
    agent_type == "ruby-rails-expert"
  end

  def frontend_agent?
    %w[javascript-package-expert tailwind-css-expert].include?(agent_type)
  end

  def quality_agent?
    %w[test-runner-fixer error-debugger].include?(agent_type)
  end

  def coordination_agent?
    %w[project-orchestrator git-auto-commit].include?(agent_type)
  end

  # Message management
  def message_count
    messages.count
  end

  def last_message
    messages.recent.first
  end

  def has_conversation?
    return true if messages.empty? # No messages means ready for conversation
    messages.by_role("user").exists? && messages.by_role("assistant").exists?
  end

  def recent_messages(limit: 10)
    messages.recent.limit(limit)
  end

  # Context management
  def update_context(new_context)
    update!(context: new_context)
  end

  def merge_context(additional_context)
    update!(context: (context || {}).merge(additional_context))
  end

  def clear_context
    update!(context: {})
  end

  # Summary and export
  def summary
    {
      id: id,
      name: name,
      agent_type: agent_type,
      status: status,
      message_count: message_count,
      last_message: last_message&.content,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def export_conversation
    {
      agent_name: name,
      agent_type: agent_type,
      status: status,
      context: context,
      messages: messages.map { |m| { role: m.role, content: m.content, timestamp: m.created_at } },
      exported_at: Time.current
    }
  end

  # Metadata helpers
  def add_metadata(key, value)
    update!(metadata: metadata.merge(key => value))
  end

  def get_metadata(key)
    metadata[key]
  end

  # Display helpers
  def display_name
    "#{agent_type_label} - #{name}"
  end

  def agent_type_label
    case agent_type
    when "ruby-rails-expert" then "Rails/Ruby Expert"
    when "javascript-package-expert" then "JavaScript Expert"
    when "tailwind-css-expert" then "Tailwind CSS Expert"
    when "test-runner-fixer" then "Test Runner"
    when "error-debugger" then "Error Debugger"
    when "project-orchestrator" then "Project Orchestrator"
    when "git-auto-commit" then "Git Auto-Commit"
    else agent_type.humanize
    end
  end

  def status_badge_color
    case status
    when "active" then "green"
    when "completed" then "blue"
    when "failed" then "red"
    when "paused" then "yellow"
    when "pending" then "gray"
    else "gray"
    end
  end

  private

  def set_defaults
    self.metadata ||= {}
    self.context ||= {}
    self.status ||= "active"
  end

  def ensure_context_hash
    self.context = {} if context.nil?
  end
end
