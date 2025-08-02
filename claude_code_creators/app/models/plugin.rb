class Plugin < ApplicationRecord
  # Associations
  has_many :plugin_installations, dependent: :destroy
  has_many :users, through: :plugin_installations
  has_many :extension_logs, dependent: :destroy
  has_many :plugin_permissions, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { scope: :version }
  validates :version, presence: true, format: { with: /\A\d+\.\d+\.\d+(-\w+)?\z/, message: "must be in semver format (e.g., 1.0.0)" }
  validates :description, presence: true
  validates :author, presence: true
  validates :category, presence: true, inclusion: { in: %w[editor command integration theme workflow] }
  validates :status, presence: true, inclusion: { in: %w[active inactive deprecated pending] }

  # JSON validations
  validates :metadata, presence: true
  validates :permissions, presence: true
  validates :sandbox_config, presence: true
  validate :validate_metadata_structure
  validate :validate_permissions_structure
  validate :validate_sandbox_config_structure

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :by_category, ->(category) { where(category: category) }
  scope :search, ->(query) { where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") }

  # Instance methods
  def installed_for?(user)
    plugin_installations.where(user: user, status: %w[installed disabled]).exists?
  end

  def installation_for(user)
    plugin_installations.find_by(user: user)
  end

  def compatible_with_platform?(platform_version = nil)
    return true unless metadata["min_version"] || metadata["max_version"]

    # Use provided version or fallback to a default
    platform_version ||= Rails.application.config.respond_to?(:version) ? Rails.application.config.version : "1.0.0"

    min_version = metadata["min_version"]
    max_version = metadata["max_version"]

    platform_semver = Gem::Version.new(platform_version)

    if min_version && platform_semver < Gem::Version.new(min_version)
      return false
    end

    if max_version && platform_semver > Gem::Version.new(max_version)
      return false
    end

    true
  end

  def sandbox_identifier
    return nil unless persisted?
    "plugin_#{id}_#{Digest::SHA256.hexdigest(name + version)[0..7]}"
  end

  def requires_permissions?
    permissions.present? && permissions.any? { |_key, value| value == true }
  end

  def entry_point
    metadata["entry_point"] || "index.js"
  end

  def dependencies
    metadata["dependencies"] || []
  end

  def api_version
    metadata["api_version"] || "1.0"
  end

  def documentation
    metadata["documentation"]
  end

  def icon_url
    metadata["icon_url"]
  end

  def homepage_url
    metadata["homepage_url"]
  end

  def repository_url
    metadata["repository_url"]
  end

  def license
    metadata["license"] || "MIT"
  end

  def keywords
    metadata["keywords"] || []
  end

  private

  def validate_metadata_structure
    return unless metadata.present?

    unless metadata.is_a?(Hash)
      errors.add(:metadata, "must be a valid JSON object")
      return
    end

    required_fields = %w[entry_point]
    required_fields.each do |field|
      unless metadata[field].present?
        errors.add(:metadata, "must include #{field}")
      end
    end

    if metadata["dependencies"].present? && !metadata["dependencies"].is_a?(Array)
      errors.add(:metadata, "dependencies must be an array")
    end

    if metadata["api_version"].present? && !metadata["api_version"].match?(/\A\d+\.\d+\z/)
      errors.add(:metadata, "api_version must be in format X.Y")
    end
  end

  def validate_permissions_structure
    return unless permissions.present?

    unless permissions.is_a?(Hash)
      errors.add(:permissions, "must be a valid JSON object")
      return
    end

    valid_permissions = %w[
      read_files write_files delete_files
      network_access api_access
      clipboard_access
      system_notifications
      user_data_access
      editor_integration
      command_execution
    ]

    permissions.each do |permission, value|
      unless valid_permissions.include?(permission)
        errors.add(:permissions, "#{permission} is not a valid permission")
      end

      unless [ true, false ].include?(value)
        errors.add(:permissions, "#{permission} must be true or false")
      end
    end
  end

  def validate_sandbox_config_structure
    return unless sandbox_config.present?

    unless sandbox_config.is_a?(Hash)
      errors.add(:sandbox_config, "must be a valid JSON object")
      return
    end

    if sandbox_config["memory_limit"].present?
      memory_limit = sandbox_config["memory_limit"]
      unless memory_limit.is_a?(Integer) && memory_limit > 0 && memory_limit <= 1000
        errors.add(:sandbox_config, "memory_limit must be an integer between 1 and 1000 MB")
      end
    end

    if sandbox_config["cpu_limit"].present?
      cpu_limit = sandbox_config["cpu_limit"]
      unless cpu_limit.is_a?(Integer) && cpu_limit > 0 && cpu_limit <= 100
        errors.add(:sandbox_config, "cpu_limit must be an integer between 1 and 100%")
      end
    end

    if sandbox_config["timeout"].present?
      timeout = sandbox_config["timeout"]
      unless timeout.is_a?(Integer) && timeout > 0 && timeout <= 300
        errors.add(:sandbox_config, "timeout must be an integer between 1 and 300 seconds")
      end
    end
  end
end
