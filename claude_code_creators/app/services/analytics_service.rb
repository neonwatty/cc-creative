class AnalyticsService
  class << self
    def overview_stats(time_range = 24.hours.ago..Time.current)
      {
        period: time_range,
        users: {
          total: User.count,
          active_in_period: User.where(last_seen_at: time_range).count,
          new_signups: User.where(created_at: time_range).count
        },
        documents: {
          total: Document.count,
          created_in_period: Document.where(created_at: time_range).count,
          updated_in_period: Document.where(updated_at: time_range).count
        },
        contexts: {
          total: ClaudeContext.count,
          created_in_period: ClaudeContext.where(created_at: time_range).count
        },
        system: {
          error_count: ErrorLog.where(occurred_at: time_range).count,
          avg_response_time: PerformanceLog.where(occurred_at: time_range).average(:duration_ms)&.round(2),
          uptime_percentage: calculate_uptime_percentage(time_range)
        }
      }
    end

    def user_activity_stats(time_range = 24.hours.ago..Time.current)
      {
        active_users: {
          last_hour: User.where("last_seen_at > ?", 1.hour.ago).count,
          last_24h: User.where("last_seen_at > ?", 24.hours.ago).count,
          last_week: User.where("last_seen_at > ?", 1.week.ago).count
        },
        user_actions: BusinessEventLog.where(occurred_at: time_range).group(:event_name).count,
        top_users_by_activity: top_active_users(time_range),
        session_statistics: calculate_session_stats(time_range)
      }
    end

    def user_metrics(time_range = 24.hours.ago..Time.current)
      {
        registration_funnel: calculate_registration_funnel(time_range),
        user_engagement: calculate_user_engagement(time_range),
        feature_usage: calculate_feature_usage(time_range),
        user_retention: calculate_user_retention(time_range)
      }
    end

    def user_retention_stats(time_range = 30.days.ago..Time.current)
      cohorts = {}

      # Calculate weekly cohorts
      (0..12).each do |week_offset|
        cohort_start = week_offset.weeks.ago.beginning_of_week
        cohort_end = cohort_start.end_of_week

        cohort_users = User.where(created_at: cohort_start..cohort_end).pluck(:id)
        next if cohort_users.empty?

        retention_data = []
        (0..12).each do |retention_week|
          period_start = cohort_start + retention_week.weeks
          period_end = period_start.end_of_week

          active_users = User.where(
            id: cohort_users,
            last_seen_at: period_start..period_end
          ).count

          retention_data << {
            week: retention_week,
            retained_users: active_users,
            retention_rate: cohort_users.size > 0 ? (active_users.to_f / cohort_users.size * 100).round(2) : 0
          }
        end

        cohorts[cohort_start.strftime("%Y-W%U")] = {
          cohort_size: cohort_users.size,
          cohort_start: cohort_start,
          retention_data: retention_data
        }
      end

      cohorts
    end

    def performance_overview(time_range = 24.hours.ago..Time.current)
      logs = PerformanceLog.where(occurred_at: time_range)

      {
        total_operations: logs.count,
        average_response_time: logs.average(:duration_ms)&.round(2) || 0,
        median_response_time: logs.median(:duration_ms)&.round(2) || 0,
        p95_response_time: logs.percentile(95, :duration_ms)&.round(2) || 0,
        p99_response_time: logs.percentile(99, :duration_ms)&.round(2) || 0,
        slowest_operations: logs.slowest_operations(10, time_range.begin.hours),
        operations_by_type: logs.group(:operation).count,
        error_rate: calculate_error_rate(time_range)
      }
    end

    def slow_operations(time_range = 24.hours.ago..Time.current, threshold_ms = 1000)
      PerformanceLog.where(occurred_at: time_range)
                   .where("duration_ms > ?", threshold_ms)
                   .order(duration_ms: :desc)
                   .limit(50)
                   .map do |log|
        {
          operation: log.operation,
          duration_ms: log.duration_ms,
          occurred_at: log.occurred_at,
          metadata: log.metadata
        }
      end
    end

    def database_performance(time_range = 24.hours.ago..Time.current)
      db_logs = PerformanceLog.where(occurred_at: time_range, operation: /database|query|sql/i)

      {
        query_count: db_logs.count,
        avg_query_time: db_logs.average(:duration_ms)&.round(2) || 0,
        slow_queries: db_logs.where("duration_ms > ?", 100).count,
        connection_pool_stats: get_connection_pool_stats
      }
    end

    def error_summary(time_range = 24.hours.ago..Time.current)
      errors = ErrorLog.where(occurred_at: time_range)

      {
        total_errors: errors.count,
        errors_by_class: errors.group(:error_class).count.sort_by { |_, count| -count },
        errors_by_environment: errors.group(:environment).count,
        critical_errors: errors.critical.count,
        error_rate_per_hour: calculate_hourly_error_rate(time_range),
        top_error_messages: top_error_messages(time_range)
      }
    end

    def error_trends(time_range = 7.days.ago..Time.current)
      daily_errors = ErrorLog.where(occurred_at: time_range)
                            .group_by_day(:occurred_at)
                            .count

      {
        daily_error_counts: daily_errors,
        trending_errors: calculate_trending_errors(time_range),
        error_resolution_time: calculate_error_resolution_time(time_range)
      }
    end

    def system_health_stats
      {
        current_metrics: MetricsCollectionService.new.collect_all,
        health_status: HealthCheckService.new.perform,
        resource_utilization: calculate_resource_utilization,
        background_job_stats: background_job_statistics
      }
    end

    def active_users_chart_data(time_range = 7.days.ago..Time.current)
      BusinessEventLog.where(occurred_at: time_range, event_name: "user_login")
                     .group_by_hour(:occurred_at)
                     .count
                     .map { |hour, count| { time: hour.iso8601, active_users: count } }
    end

    def response_time_chart_data(time_range = 24.hours.ago..Time.current)
      PerformanceLog.where(occurred_at: time_range)
                   .group_by_hour(:occurred_at)
                   .average(:duration_ms)
                   .map { |hour, avg_time| { time: hour.iso8601, avg_response_time: avg_time&.round(2) || 0 } }
    end

    private

    def calculate_uptime_percentage(time_range)
      # Simple uptime calculation based on error logs
      total_minutes = (time_range.end - time_range.begin) / 60.0
      critical_error_minutes = ErrorLog.critical
                                      .where(occurred_at: time_range)
                                      .count * 5 # Assume each critical error causes 5 minutes downtime

      uptime_minutes = [ total_minutes - critical_error_minutes, 0 ].max
      (uptime_minutes / total_minutes * 100).round(4)
    end

    def top_active_users(time_range, limit = 10)
      BusinessEventLog.where(occurred_at: time_range)
                     .where.not(event_data: nil)
                     .where("event_data ? 'user_id'")
                     .group("event_data->>'user_id'")
                     .count
                     .sort_by { |_, count| -count }
                     .first(limit)
                     .map do |user_id, event_count|
        user = User.find_by(id: user_id)
        {
          user_id: user_id,
          user_email: user&.email || "Unknown",
          event_count: event_count
        }
      end
    end

    def calculate_session_stats(time_range)
      login_events = BusinessEventLog.where(
        occurred_at: time_range,
        event_name: "user_login"
      )

      logout_events = BusinessEventLog.where(
        occurred_at: time_range,
        event_name: "user_logout"
      )

      {
        total_sessions: login_events.count,
        avg_session_duration: calculate_avg_session_duration(time_range),
        bounce_rate: calculate_bounce_rate(time_range)
      }
    end

    def calculate_registration_funnel(time_range)
      {
        page_views: BusinessEventLog.where(occurred_at: time_range, event_name: "page_view").count,
        signup_starts: BusinessEventLog.where(occurred_at: time_range, event_name: "signup_start").count,
        signup_completions: User.where(created_at: time_range).count,
        email_verifications: BusinessEventLog.where(occurred_at: time_range, event_name: "email_verified").count
      }
    end

    def calculate_user_engagement(time_range)
      {
        documents_created: Document.where(created_at: time_range).count,
        contexts_created: ClaudeContext.where(created_at: time_range).count,
        commands_executed: BusinessEventLog.where(occurred_at: time_range, event_name: "command_executed").count,
        avg_session_length: calculate_avg_session_duration(time_range)
      }
    end

    def calculate_feature_usage(time_range)
      feature_events = BusinessEventLog.where(occurred_at: time_range)
                                      .where(event_name: [
                                        "document_created",
                                        "context_created",
                                        "command_executed",
                                        "file_uploaded",
                                        "collaboration_started"
                                      ])
                                      .group(:event_name)
                                      .count

      total_events = feature_events.values.sum

      feature_events.transform_values do |count|
        {
          count: count,
          percentage: total_events > 0 ? (count.to_f / total_events * 100).round(2) : 0
        }
      end
    end

    def calculate_user_retention(time_range)
      period_start = time_range.begin
      period_users = User.where(created_at: period_start..period_start.end_of_week)

      return { day_1: 0, day_7: 0, day_30: 0 } if period_users.empty?

      {
        day_1: calculate_retention_for_period(period_users, 1.day),
        day_7: calculate_retention_for_period(period_users, 7.days),
        day_30: calculate_retention_for_period(period_users, 30.days)
      }
    end

    def calculate_retention_for_period(users, period)
      retained_users = users.where("last_seen_at > ?", users.minimum(:created_at) + period).count
      (retained_users.to_f / users.count * 100).round(2)
    end

    def calculate_error_rate(time_range)
      total_operations = PerformanceLog.where(occurred_at: time_range).count
      total_errors = ErrorLog.where(occurred_at: time_range).count

      return 0 if total_operations == 0

      (total_errors.to_f / total_operations * 100).round(4)
    end

    def get_connection_pool_stats
      pool = ActiveRecord::Base.connection_pool
      {
        size: pool.size,
        checked_out: pool.connections.count(&:in_use?),
        checked_in: pool.available_connection_count,
        dead: pool.connections.count { |conn| !conn.active? }
      }
    end

    def calculate_hourly_error_rate(time_range)
      ErrorLog.where(occurred_at: time_range)
              .group_by_hour(:occurred_at)
              .count
    end

    def top_error_messages(time_range, limit = 10)
      ErrorLog.where(occurred_at: time_range)
              .group(:message)
              .count
              .sort_by { |_, count| -count }
              .first(limit)
              .map { |message, count| { message: message.truncate(100), count: count } }
    end

    def calculate_trending_errors(time_range)
      # Compare current period with previous period
      current_period = time_range
      previous_period = (time_range.begin - (time_range.end - time_range.begin))..(time_range.begin)

      current_errors = ErrorLog.where(occurred_at: current_period).group(:error_class).count
      previous_errors = ErrorLog.where(occurred_at: previous_period).group(:error_class).count

      current_errors.map do |error_class, current_count|
        previous_count = previous_errors[error_class] || 0
        change_percent = previous_count > 0 ? ((current_count - previous_count).to_f / previous_count * 100).round(2) : Float::INFINITY

        {
          error_class: error_class,
          current_count: current_count,
          previous_count: previous_count,
          change_percent: change_percent,
          trend: change_percent > 50 ? "increasing" : change_percent < -50 ? "decreasing" : "stable"
        }
      end.sort_by { |error| -error[:change_percent] }
    end

    def calculate_error_resolution_time(time_range)
      # This would typically track from error occurrence to resolution
      # For now, return placeholder data
      {
        avg_resolution_time_hours: 2.5,
        median_resolution_time_hours: 1.0,
        unresolved_errors: ErrorLog.where(occurred_at: time_range).count
      }
    end

    def calculate_resource_utilization
      # Basic resource utilization metrics
      {
        memory_usage_percent: get_memory_usage_percent,
        cpu_usage_percent: get_cpu_usage_percent,
        disk_usage_percent: get_disk_usage_percent
      }
    end

    def background_job_statistics
      {
        queued: SolidQueue::Job.queued.count,
        running: SolidQueue::Job.running.count,
        failed: SolidQueue::Job.failed.count,
        completed_last_hour: SolidQueue::Job.where("finished_at > ?", 1.hour.ago).count
      }
    end

    def calculate_avg_session_duration(time_range)
      # Simplified session duration calculation
      # In production, you'd track actual session start/end times
      avg_events_per_user = BusinessEventLog.where(occurred_at: time_range)
                                           .group("event_data->>'user_id'")
                                           .count
                                           .values
                                           .sum.to_f / User.count

      # Estimate: more events = longer session
      (avg_events_per_user * 5).round(2) # 5 minutes per event average
    end

    def calculate_bounce_rate(time_range)
      # Users with only one event (simplistic bounce rate)
      single_event_users = BusinessEventLog.where(occurred_at: time_range)
                                          .group("event_data->>'user_id'")
                                          .count
                                          .select { |_, count| count == 1 }
                                          .size

      total_active_users = BusinessEventLog.where(occurred_at: time_range)
                                          .distinct
                                          .count("event_data->>'user_id'")

      return 0 if total_active_users == 0

      (single_event_users.to_f / total_active_users * 100).round(2)
    end

    def get_memory_usage_percent
      memory_info = `free | grep Mem`.split
      return 0 unless memory_info.size >= 3

      total = memory_info[1].to_f
      used = memory_info[2].to_f
      (used / total * 100).round(2)
    rescue
      0
    end

    def get_cpu_usage_percent
      # Simple CPU usage check
      cpu_info = `top -bn1 | grep "Cpu(s)"`.match(/(\d+\.\d+)%us/)
      cpu_info ? cpu_info[1].to_f : 0
    rescue
      0
    end

    def get_disk_usage_percent
      disk_info = `df / | tail -1`.split
      return 0 unless disk_info.size >= 5

      disk_info[4].to_i
    rescue
      0
    end
  end
end
