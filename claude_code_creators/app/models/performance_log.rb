class PerformanceLog < ApplicationRecord
  validates :operation, presence: true
  validates :duration_ms, presence: true, numericality: { greater_than: 0 }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_operation, ->(op) { where(operation: op) }
  scope :slow_operations, ->(threshold_ms = 1000) { where("duration_ms > ?", threshold_ms) }
  scope :in_timeframe, ->(timeframe) { where("occurred_at > ?", timeframe.ago) }

  def self.average_duration_for(operation, timeframe = 1.hour)
    by_operation(operation)
      .in_timeframe(timeframe)
      .average(:duration_ms)
      &.round(2) || 0
  end

  def self.slowest_operations(limit = 10, timeframe = 1.hour)
    in_timeframe(timeframe)
      .group(:operation)
      .average(:duration_ms)
      .sort_by { |_, avg| -avg }
      .first(limit)
      .map { |op, avg| { operation: op, avg_duration_ms: avg.round(2) } }
  end

  def self.performance_summary(timeframe = 1.hour)
    logs = in_timeframe(timeframe)

    {
      total_operations: logs.count,
      average_duration_ms: logs.average(:duration_ms)&.round(2) || 0,
      median_duration_ms: logs.median(:duration_ms)&.round(2) || 0,
      p95_duration_ms: logs.percentile(95, :duration_ms)&.round(2) || 0,
      p99_duration_ms: logs.percentile(99, :duration_ms)&.round(2) || 0,
      slow_operations_count: logs.slow_operations.count
    }
  end

  def self.cleanup_old_logs(keep_for = 7.days)
    where("occurred_at < ?", keep_for.ago).delete_all
  end

  def slow?(threshold_ms = 1000)
    duration_ms > threshold_ms
  end
end
