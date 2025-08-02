class CloudIntegration < ApplicationRecord
  belongs_to :user
  has_many :cloud_files, dependent: :destroy

  # Serialize settings as JSON for SQLite compatibility
  serialize :settings, coder: JSON, type: Hash

  # Encryption for tokens
  encrypts :access_token
  encrypts :refresh_token

  # Supported providers
  PROVIDERS = %w[google_drive dropbox notion].freeze

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :access_token, presence: true
  validates :user_id, uniqueness: { scope: :provider, message: "already has an integration for this provider" }

  # Scopes
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :for_provider, ->(provider) { where(provider: provider) }

  # Check if the integration is active
  def active?
    expires_at.nil? || expires_at > Time.current
  end

  def expired?
    !active?
  end

  # Token refresh logic will be handled by service objects
  def needs_refresh?
    return false if expires_at.nil?
    expires_at <= 1.hour.from_now
  end

  # Settings helpers
  def get_setting(key)
    settings&.dig(key.to_s)
  end

  def set_setting(key, value)
    self.settings ||= {}
    self.settings[key.to_s] = value
  end

  # Provider-specific helpers
  def google_drive?
    provider == "google_drive"
  end

  def dropbox?
    provider == "dropbox"
  end

  def notion?
    provider == "notion"
  end

  # Display name for the provider
  def provider_name
    case provider
    when "google_drive"
      "Google Drive"
    when "dropbox"
      "Dropbox"
    when "notion"
      "Notion"
    else
      provider.humanize
    end
  end
end
