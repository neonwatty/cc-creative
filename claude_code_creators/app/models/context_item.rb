class ContextItem < ApplicationRecord
  belongs_to :document
  belongs_to :user

  validates :content, presence: true
  validates :item_type, inclusion: { in: %w[snippet draft version] }
  validates :title, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :desc) }
  scope :by_type, ->(type) { where(item_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  before_create :set_default_position

  private

  def set_default_position
    return if position.present?
    
    max_position = document.context_items.maximum(:position) || 0
    self.position = max_position + 1
  end
end
