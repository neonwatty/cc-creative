# frozen_string_literal: true

class OperationalTransform < ApplicationRecord
  belongs_to :document
  belongs_to :user

  validates :operation_type, inclusion: { in: %w[insert delete replace] }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :timestamp, presence: true
  validates :operation_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[pending applied failed] }

  scope :for_document, ->(doc_id) { where(document_id: doc_id) }
  scope :recent, ->(since = 1.hour.ago) { where("applied_at > ?", since) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :successful, -> { where(status: "applied") }
  scope :pending, -> { where(status: "pending") }

  before_validation :generate_operation_id, if: -> { operation_id.blank? }

  def to_operation_hash
    {
      type: operation_type,
      position: position,
      length: length,
      content: content,
      user_id: user_id,
      timestamp: timestamp.to_f,
      operation_id: operation_id,
      applied_at: applied_at,
      status: status,
      conflict_resolved: conflict_resolved
    }
  end

  def self.from_operation_hash(hash)
    new(
      operation_type: hash[:type],
      position: hash[:position],
      length: hash[:length],
      content: hash[:content],
      user_id: hash[:user_id],
      timestamp: hash[:timestamp],
      operation_id: hash[:operation_id],
      status: hash[:status] || "pending"
    )
  end

  private

  def generate_operation_id
    self.operation_id = "op_#{SecureRandom.uuid}"
  end
end
