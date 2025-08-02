class ErrorLog < ApplicationRecord
  validates :error_class, presence: true
  validates :message, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_environment, ->(env) { where(environment: env) }
  scope :by_error_class, ->(klass) { where(error_class: klass) }
  scope :critical, -> { where("message ILIKE ANY(ARRAY[?])", critical_patterns) }

  def self.critical_patterns
    [
      "%database%connection%",
      "%redis%connection%",
      "%authentication%failed%",
      "%authorization%denied%",
      "%security%violation%"
    ]
  end

  def self.error_summary(timeframe = 1.hour)
    where("occurred_at > ?", timeframe.ago)
      .group(:error_class)
      .count
      .sort_by { |_, count| -count }
  end

  def self.cleanup_old_logs(keep_for = 30.days)
    where("occurred_at < ?", keep_for.ago).delete_all
  end

  def critical?
    self.class.critical_patterns.any? { |pattern| message.downcase.include?(pattern.tr("%", "")) }
  end

  def formatted_backtrace
    return [] unless backtrace.present?

    backtrace.split("\n").map(&:strip)
  end
end
