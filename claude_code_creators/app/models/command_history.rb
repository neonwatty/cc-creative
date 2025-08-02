class CommandHistory < ApplicationRecord
  belongs_to :user
  belongs_to :document

  validates :command, presence: true
  validates :executed_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[success error] }
  validates :execution_time, numericality: { greater_than_or_equal_to: 0 }

  # Serialize parameters and result_data as JSON for SQLite compatibility
  serialize :parameters, coder: JSON, type: Array
  serialize :result_data, coder: JSON, type: Hash

  # Scopes for common queries
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_document, ->(document) { where(document: document) }
  scope :by_command, ->(command) { where(command: command) }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "error") }
  scope :within_timeframe, ->(start_time, end_time) { where(executed_at: start_time..end_time) }

  # Performance tracking
  scope :slow_commands, ->(threshold = 1.0) { where("execution_time > ?", threshold) }
  scope :fast_commands, ->(threshold = 0.1) { where("execution_time <= ?", threshold) }

  # Analytics methods
  def self.average_execution_time(command = nil)
    scope = command ? by_command(command) : all
    scope.average(:execution_time) || 0.0
  end

  def self.success_rate(command = nil)
    scope = command ? by_command(command) : all
    total = scope.count
    return 0.0 if total.zero?

    successful_count = scope.successful.count
    (successful_count.to_f / total * 100).round(2)
  end

  def self.command_usage_stats
    group(:command)
      .group(:status)
      .count
      .transform_keys { |key| { command: key[0], status: key[1] } }
  end

  # Instance methods
  def success?
    status == "success"
  end

  def error?
    status == "error"
  end

  def slow?(threshold = 1.0)
    execution_time && execution_time > threshold
  end

  def parameters_list
    parameters || []
  end

  def result_hash
    result_data || {}
  end

  def formatted_execution_time
    return "N/A" unless execution_time

    if execution_time < 0.001
      "< 1ms"
    elsif execution_time < 1.0
      "#{(execution_time * 1000).round(1)}ms"
    else
      "#{execution_time.round(2)}s"
    end
  end

  def command_summary
    params_str = parameters_list.any? ? " (#{parameters_list.join(', ')})" : ""
    "#{command}#{params_str}"
  end
end
