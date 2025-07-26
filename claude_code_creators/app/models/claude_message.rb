class ClaudeMessage < ApplicationRecord
  # Associations
  belongs_to :claude_session, foreign_key: :session_id, primary_key: :session_id, optional: true
  
  # Validations
  validates :session_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
  
  # Callbacks
  after_initialize :set_defaults
  before_save :calculate_token_estimate
  
  # Scopes
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_sub_agent, ->(name) { where(sub_agent_name: name) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Class methods
  def self.conversation_pairs(session_id, limit: 10)
    messages = by_session(session_id).recent.limit(limit * 2)
    messages.each_slice(2).select { |pair| pair.size == 2 }
  end
  
  # Instance methods
  def user?
    role == 'user'
  end
  
  def assistant?
    role == 'assistant'
  end
  
  def system?
    role == 'system'
  end
  
  def token_count
    message_metadata&.dig('token_count') || estimate_tokens
  end
  
  def formatted_content
    return content unless assistant?
    
    # Add any formatting logic here for assistant responses
    content
  end
  
  private
  
  def set_defaults
    self.context ||= {}
    self.message_metadata ||= {}
  end
  
  def calculate_token_estimate
    # Simple token estimation (actual implementation would use tiktoken or similar)
    self.message_metadata['token_count'] = estimate_tokens
  end
  
  def estimate_tokens
    # Rough estimation: ~4 characters per token
    (content.length / 4.0).ceil
  end
end
