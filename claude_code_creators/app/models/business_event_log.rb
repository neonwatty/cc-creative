class BusinessEventLog < ApplicationRecord
  validates :event_name, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_event, ->(name) { where(event_name: name) }
  scope :in_timeframe, ->(timeframe) { where("occurred_at > ?", timeframe.ago) }

  def self.event_counts(timeframe = 24.hours)
    in_timeframe(timeframe)
      .group(:event_name)
      .count
      .sort_by { |_, count| -count }
  end

  def self.user_activity_summary(timeframe = 24.hours)
    user_events = in_timeframe(timeframe).where(event_name: [
      "user_login",
      "user_logout",
      "document_created",
      "context_created",
      "command_executed"
    ])

    {
      total_events: user_events.count,
      event_breakdown: user_events.group(:event_name).count,
      unique_users: user_events.where.not(event_data: nil)
                                .where("event_data ? 'user_id'")
                                .distinct
                                .count("event_data->>'user_id'")
    }
  end

  def self.cleanup_old_logs(keep_for = 90.days)
    where("occurred_at < ?", keep_for.ago).delete_all
  end

  def user_id
    event_data&.dig("user_id")
  end

  def session_id
    event_data&.dig("session_id")
  end
end
