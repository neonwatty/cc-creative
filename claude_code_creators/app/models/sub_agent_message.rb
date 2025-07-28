class SubAgentMessage < ApplicationRecord
  belongs_to :sub_agent
  belongs_to :user

  # Validations
  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true, length: { maximum: 100_000 }

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :strip_content

  # Instance methods
  def user_message?
    role == "user"
  end

  def assistant_message?
    role == "assistant"
  end

  def system_message?
    role == "system"
  end

  def word_count
    content.to_s.split.size
  end

  def truncate_content(max_length = 100)
    return content if content.length <= max_length
    "#{content[0...max_length]}..."
  end

  def formatted_for_display
    {
      id: id,
      role: role,
      content: content,
      created_at: created_at,
      user_name: user.name
    }
  end

  def export
    {
      role: role,
      content: content,
      timestamp: created_at,
      user: user.name
    }
  end

  private

  def strip_content
    self.content = content.to_s.strip
  end
end
