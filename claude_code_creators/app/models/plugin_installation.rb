class PluginInstallation < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :plugin

  # Validations
  validates :user, presence: true
  validates :plugin, presence: true
  validates :status, presence: true, inclusion: { in: %w[installed uninstalled disabled error updating installing] }
  validates :plugin_id, uniqueness: { scope: :user_id }
  validate :validate_configuration_structure
  validate :validate_plugin_compatibility

  # Callbacks
  before_save :set_installed_at_on_install
  after_create :set_initial_installed_at

  # Scopes
  scope :installed, -> { where(status: "installed") }
  scope :active, -> { where(status: %w[installed]) }
  scope :for_user, ->(user) { where(user: user) }

  # Instance methods
  def active?
    status == "installed"
  end

  def touch_last_used!
    update!(last_used_at: Time.current)
  end

  def config_value(key, default = nil)
    return default unless configuration.present?
    configuration[key.to_s] || default
  end

  def set_config_value(key, value)
    self.configuration ||= {}
    self.configuration[key.to_s] = value
    save!
  end

  def usage_metrics
    {
      installed_at: installed_at,
      last_used_at: last_used_at,
      days_since_install: days_since_install,
      status: status,
      configuration: configuration
    }
  end

  def days_since_install
    return 0 unless installed_at
    ((Time.current - installed_at) / 1.day).round
  end

  def mark_installed!
    update!(
      status: "installed",
      installed_at: Time.current
    )
  end

  def mark_disabled!
    update!(status: "disabled")
  end

  def mark_uninstalled!
    update!(status: "uninstalled")
  end

  def mark_error!(error_message)
    self.configuration ||= {}
    self.configuration["error_message"] = error_message
    self.configuration["error_at"] = Time.current.iso8601
    update!(status: "error")
  end

  def error_message
    return nil unless status == "error"
    configuration&.dig("error_message")
  end

  def last_error_at
    return nil unless status == "error"
    error_time = configuration&.dig("error_at")
    return nil unless error_time
    Time.parse(error_time) rescue nil
  end

  def installation_valid?
    plugin.present? && plugin.status == "active" && plugin.compatible_with_platform?
  end

  def execution_logs(limit: 10)
    ExtensionLog.where(plugin: plugin, user: user)
                .order(created_at: :desc)
                .limit(limit)
  end

  def recent_activity(days: 7)
    since_date = days.days.ago
    ExtensionLog.where(plugin: plugin, user: user)
                .where("created_at >= ?", since_date)
                .group(:action)
                .count
  end

  def performance_summary
    logs = ExtensionLog.where(plugin: plugin, user: user)
                      .where("created_at >= ?", 30.days.ago)

    total_executions = logs.count
    successful_executions = logs.where(status: "success").count
    average_execution_time = logs.where.not(execution_time: nil).average(:execution_time)

    {
      total_executions: total_executions,
      success_rate: total_executions > 0 ? (successful_executions.to_f / total_executions * 100).round(2) : 0,
      average_execution_time: average_execution_time&.round(2) || 0,
      last_execution: logs.maximum(:created_at)
    }
  end

  private

  def validate_configuration_structure
    return unless configuration.present?

    unless configuration.is_a?(Hash)
      errors.add(:configuration, "must be a valid JSON object")
    end
  end

  def validate_plugin_compatibility
    return unless plugin.present?

    unless plugin.compatible_with_platform?
      errors.add(:plugin, "is not compatible with current platform")
    end
  end

  def set_installed_at_on_install
    if status_changed? && status == "installed" && installed_at.blank?
      self.installed_at = Time.current
    end
  end

  def set_initial_installed_at
    if status == "installed" && installed_at.blank?
      update_column(:installed_at, Time.current)
    end
  end
end
