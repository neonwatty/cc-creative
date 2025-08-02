# frozen_string_literal: true

class CollaborationSession < ApplicationRecord
  belongs_to :document
  belongs_to :user # Session owner

  validates :session_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active ended terminated] }
  validates :max_users, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  validates :active_users_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :started_at, presence: true

  scope :active, -> { where(status: "active") }
  scope :for_document, ->(doc_id) { where(document_id: doc_id) }
  scope :recent, ->(since = 1.hour.ago) { where("started_at > ?", since) }

  before_validation :generate_session_id, if: -> { session_id.blank? }
  before_validation :set_started_at, if: -> { started_at.blank? }

  # Check if session has expired
  def expired?
    expires_at.present? && expires_at < Time.current
  end

  # Check if session can accept more users
  def can_accept_users?
    active? && active_users_count < max_users
  end

  def active?
    status == "active" && !expired?
  end

  def settings_hash
    settings.present? ? JSON.parse(settings) : {}
  rescue JSON::ParserError
    {}
  end

  def update_settings!(new_settings)
    merged_settings = settings_hash.merge(new_settings)
    update!(settings: merged_settings.to_json)
  end

  # Get session duration
  def duration
    return nil unless started_at

    end_time = status == "active" ? Time.current : updated_at
    end_time - started_at
  end

  private

  def generate_session_id
    self.session_id = "collab_#{SecureRandom.hex(16)}"
  end

  def set_started_at
    self.started_at = Time.current
  end
end
