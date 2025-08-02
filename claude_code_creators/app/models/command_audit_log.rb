class CommandAuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :document

  validates :command, presence: true
  validates :executed_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[success error] }
  validates :execution_time, numericality: { greater_than_or_equal_to: 0 }

  # Serialize parameters and metadata as JSON for SQLite compatibility
  serialize :parameters, coder: JSON, type: Array
  serialize :metadata, coder: JSON, type: Hash

  # Scopes for audit queries
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_document, ->(document) { where(document: document) }
  scope :by_command, ->(command) { where(command: command) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_ip, ->(ip_address) { where(ip_address: ip_address) }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "error") }
  scope :within_timeframe, ->(start_time, end_time) { where(executed_at: start_time..end_time) }

  # Security-focused scopes
  scope :suspicious_activity, -> {
    where("execution_time > ? OR status = ?", 5.0, "error")
      .where("created_at > ?", 1.hour.ago)
  }

  scope :failed_attempts, ->(limit = 5) {
    failed.where("executed_at > ?", 1.hour.ago).limit(limit)
  }

  scope :by_user_agent_pattern, ->(pattern) {
    where("user_agent LIKE ?", "%#{pattern}%")
  }

  # Audit trail methods
  def self.log_command_execution(command:, parameters:, user:, document:,
                                execution_time:, status:, error_message: nil,
                                ip_address: nil, user_agent: nil, session_id: nil,
                                metadata: {})
    create!(
      command: command,
      parameters: parameters,
      user: user,
      document: document,
      executed_at: Time.current,
      execution_time: execution_time,
      status: status,
      error_message: error_message,
      ip_address: ip_address,
      user_agent: user_agent,
      session_id: session_id,
      metadata: metadata
    )
  end

  def self.security_summary(timeframe = 24.hours)
    scope = where("executed_at > ?", timeframe.ago)

    {
      total_commands: scope.count,
      unique_users: scope.distinct.count(:user_id),
      unique_ips: scope.where.not(ip_address: nil).distinct.count(:ip_address),
      failed_commands: scope.failed.count,
      success_rate: calculate_success_rate(scope),
      most_active_users: most_active_users(scope),
      command_breakdown: command_breakdown(scope),
      suspicious_patterns: detect_suspicious_patterns(scope)
    }
  end

  def self.user_activity_summary(user, timeframe = 24.hours)
    scope = by_user(user).where("executed_at > ?", timeframe.ago)

    {
      total_commands: scope.count,
      successful_commands: scope.successful.count,
      failed_commands: scope.failed.count,
      unique_documents: scope.distinct.count(:document_id),
      command_types: scope.group(:command).count,
      average_execution_time: scope.average(:execution_time) || 0.0,
      sessions: scope.where.not(session_id: nil).distinct.count(:session_id)
    }
  end

  # Instance methods
  def success?
    status == "success"
  end

  def error?
    status == "error"
  end

  def parameters_list
    parameters || []
  end

  def metadata_hash
    metadata || {}
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

  def user_info
    "#{user.name} (#{user.email_address})"
  end

  def session_info
    session_id.present? ? session_id[0..8] : "N/A"
  end

  def location_info
    ip_address.present? ? ip_address : "Unknown"
  end

  private

  def self.calculate_success_rate(scope)
    total = scope.count
    return 0.0 if total.zero?

    successful = scope.successful.count
    (successful.to_f / total * 100).round(2)
  end

  def self.most_active_users(scope, limit = 5)
    scope.group(:user_id)
         .order("count_all DESC")
         .limit(limit)
         .count
         .map { |user_id, count| { user_id: user_id, command_count: count } }
  end

  def self.command_breakdown(scope)
    scope.group(:command, :status).count
  end

  def self.detect_suspicious_patterns(scope)
    patterns = []

    # Multiple failed attempts from same IP
    failed_by_ip = scope.failed.group(:ip_address).having("count(*) > 3").count
    patterns << { type: "multiple_failures_by_ip", data: failed_by_ip } if failed_by_ip.any?

    # Unusual command patterns
    unusual_commands = scope.group(:command).having("count(*) > 100").count
    patterns << { type: "high_volume_commands", data: unusual_commands } if unusual_commands.any?

    patterns
  end
end
