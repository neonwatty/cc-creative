class ClaudeSession < ApplicationRecord
  # Associations
  has_many :claude_messages, foreign_key: :session_id, primary_key: :session_id, dependent: :destroy
  has_many :claude_contexts, foreign_key: :session_id, primary_key: :session_id, dependent: :destroy

  # Validations
  validates :session_id, presence: true, uniqueness: true

  # Callbacks
  after_initialize :set_defaults

  # Scopes
  scope :active, -> { where("updated_at > ?", 24.hours.ago) }
  scope :with_messages, -> { joins(:claude_messages).distinct }

  # Instance methods
  def add_context(key, value)
    self.context ||= {}
    self.context[key] = value
    save!
  end

  def remove_context(key)
    self.context ||= {}
    self.context.delete(key)
    save!
  end

  def message_count
    claude_messages.count
  end

  def last_message
    claude_messages.order(created_at: :desc).first
  end

  def total_tokens_used
    claude_messages.sum { |msg| msg.message_metadata&.dig("usage", "total_tokens") || 0 }
  end

  private

  def set_defaults
    self.context ||= {}
    self.metadata ||= {}
  end
end
