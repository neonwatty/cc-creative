class ClaudeContext < ApplicationRecord
  # Associations
  belongs_to :claude_session, foreign_key: :session_id, primary_key: :session_id, optional: true
  belongs_to :document, optional: true
  belongs_to :user, optional: true

  # Serialization
  serialize :context_data, coder: JSON

  # Validations
  validates :session_id, presence: true
  validates :context_type, presence: true
  validates :token_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Callbacks
  after_initialize :set_defaults
  before_save :calculate_tokens

  # Context types
  CONTEXT_TYPES = %w[
    document
    code
    reference
    system_prompt
    user_preference
    file_content
    sub_agent_context
    file_include
    loaded_content
  ].freeze

  validates :context_type, inclusion: { in: CONTEXT_TYPES }

  # Scopes
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_type, ->(type) { where(context_type: type) }
  scope :documents, -> { by_type("document") }
  scope :code_contexts, -> { by_type("code") }
  scope :recent, -> { order(updated_at: :desc) }

  # Class methods
  def self.total_tokens_for_session(session_id)
    by_session(session_id).sum(:token_count)
  end

  def self.compress_context(session_id, max_tokens: 50_000)
    total = total_tokens_for_session(session_id)
    return unless total > max_tokens

    # Remove oldest contexts until under limit
    contexts = by_session(session_id).order(updated_at: :asc)
    removed_tokens = 0

    contexts.find_each do |context|
      break if total - removed_tokens <= max_tokens

      removed_tokens += context.token_count
      context.destroy
    end
  end

  # Instance methods
  def document?
    context_type == "document"
  end

  def code?
    context_type == "code"
  end

  def add_content(key, value)
    self.content ||= {}
    self.content[key] = value
    save!
  end

  def remove_content(key)
    self.content ||= {}
    self.content.delete(key)
    save!
  end

  def estimated_tokens
    return 0 if content.blank?

    # Simple estimation based on content size
    content.to_json.length / 4
  end

  private

  def set_defaults
    self.content ||= {}
    self.token_count ||= 0
    self.session_id ||= generate_session_id if document_id.present?
    self.context_type ||= "document" if document_id.present?
  end

  def generate_session_id
    "doc_#{SecureRandom.hex(8)}"
  end

  def calculate_tokens
    self.token_count = estimated_tokens
  end
end
