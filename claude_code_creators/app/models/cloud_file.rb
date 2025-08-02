class CloudFile < ApplicationRecord
  belongs_to :cloud_integration
  has_one :user, through: :cloud_integration

  # Optional association to Document if imported
  belongs_to :document, optional: true

  # Serialize metadata as JSON for SQLite compatibility
  serialize :metadata, coder: JSON, type: Hash

  validates :provider, presence: true
  validates :file_id, presence: true, uniqueness: { scope: :cloud_integration_id }
  validates :name, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :synced, -> { where.not(last_synced_at: nil) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :importable, -> { where(mime_type: IMPORTABLE_MIME_TYPES) }

  # Supported file types for import
  IMPORTABLE_MIME_TYPES = [
    "text/plain",
    "text/html",
    "text/markdown",
    "application/pdf",
    "application/vnd.google-apps.document",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/msword"
  ].freeze

  # Check if file can be imported as a document
  def importable?
    IMPORTABLE_MIME_TYPES.include?(mime_type)
  end

  # Human-readable file size
  def human_size
    return "Unknown" if size.nil?

    if size < 1024
      "#{size} B"
    elsif size < 1_048_576
      "#{(size / 1024.0).round(1)} KB"
    elsif size < 1_073_741_824
      "#{(size / 1_048_576.0).round(1)} MB"
    else
      "#{(size / 1_073_741_824.0).round(1)} GB"
    end
  end

  # File type helpers
  def google_doc?
    mime_type == "application/vnd.google-apps.document"
  end

  def pdf?
    mime_type == "application/pdf"
  end

  def text?
    mime_type&.start_with?("text/")
  end

  def word_doc?
    mime_type.in?([
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/msword"
    ])
  end

  # Metadata helpers
  def get_metadata(key)
    metadata&.dig(key.to_s)
  end

  def set_metadata(key, value)
    self.metadata ||= {}
    self.metadata[key.to_s] = value
  end

  # Sync status
  def synced?
    last_synced_at.present?
  end

  def sync_needed?
    !synced? || last_synced_at < 1.hour.ago
  end

  # Provider-specific file URL (for display purposes)
  def provider_url
    case provider
    when "google_drive"
      "https://drive.google.com/file/d/#{file_id}/view"
    when "dropbox"
      "https://www.dropbox.com/home?preview=#{file_id}"
    when "notion"
      # Notion URLs are stored in metadata
      get_metadata("url")
    end
  end
end
