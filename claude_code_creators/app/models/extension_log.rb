class ExtensionLog < ApplicationRecord
  # Associations
  belongs_to :plugin
  belongs_to :user

  # Validations
  validates :plugin, presence: true
  validates :user, presence: true
  validates :action, presence: true
  validates :status, presence: true, inclusion: { in: %w[success error warning info] }
  validate :validate_resource_usage_structure

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_plugin, ->(plugin) { where(plugin: plugin) }
  scope :for_user, ->(user) { where(user: user) }
  scope :successful, -> { where(status: "success") }
  scope :errors, -> { where(status: "error") }
  scope :since, ->(date) { where("created_at >= ?", date) }

  # Instance methods
  def success?
    status == "success"
  end

  def error?
    status == "error"
  end

  def execution_duration
    return nil unless execution_time
    "#{execution_time}ms"
  end

  def memory_usage
    return nil unless resource_usage&.dig("memory_used")
    "#{resource_usage['memory_used']}MB"
  end

  def cpu_usage
    return nil unless resource_usage&.dig("cpu_time")
    "#{resource_usage['cpu_time']}ms"
  end

  def formatted_created_at
    created_at.strftime("%Y-%m-%d %H:%M:%S")
  end

  def self.performance_metrics(plugin_id, days: 30)
    logs = where(plugin_id: plugin_id)
           .where("created_at >= ?", days.days.ago)

    total_count = logs.count
    success_count = logs.successful.count
    error_count = logs.errors.count
    avg_execution_time = logs.where.not(execution_time: nil).average(:execution_time)

    {
      total_executions: total_count,
      success_rate: total_count > 0 ? (success_count.to_f / total_count * 100).round(2) : 0,
      error_rate: total_count > 0 ? (error_count.to_f / total_count * 100).round(2) : 0,
      average_execution_time: avg_execution_time&.round(2) || 0,
      recent_errors: logs.errors.recent.limit(5).pluck(:error_message, :created_at)
    }
  end

  def self.resource_usage_trends(plugin_id, days: 7)
    logs = where(plugin_id: plugin_id)
           .where("created_at >= ?", days.days.ago)
           .where.not(resource_usage: nil)

    memory_usage = logs.map { |log| log.resource_usage&.dig("memory_used") }.compact
    cpu_usage = logs.map { |log| log.resource_usage&.dig("cpu_time") }.compact

    {
      memory_trend: {
        average: memory_usage.any? ? (memory_usage.sum.to_f / memory_usage.size).round(2) : 0,
        max: memory_usage.max || 0,
        min: memory_usage.min || 0
      },
      cpu_trend: {
        average: cpu_usage.any? ? (cpu_usage.sum.to_f / cpu_usage.size).round(2) : 0,
        max: cpu_usage.max || 0,
        min: cpu_usage.min || 0
      },
      sample_count: logs.count
    }
  end

  private

  def validate_resource_usage_structure
    return unless resource_usage.present?

    unless resource_usage.is_a?(Hash)
      errors.add(:resource_usage, "must be a valid JSON object")
    end
  end
end
