class Admin::AnalyticsController < ApplicationController
  before_action :ensure_admin_access
  before_action :set_time_range, only: [ :index, :users, :performance, :errors ]
  
  # Performance optimizations
  ANALYTICS_CACHE_TTL = 2.minutes
  EXPENSIVE_ANALYTICS_TTL = 10.minutes

  def index
    # Use parallel execution for better performance
    analytics_data = Concurrent::Hash.new
    
    futures = [
      Concurrent::Future.execute { analytics_data[:overview_stats] = AnalyticsService.overview_stats_cached(@time_range) },
      Concurrent::Future.execute { analytics_data[:user_activity] = AnalyticsService.user_activity_stats_cached(@time_range) },
      Concurrent::Future.execute { analytics_data[:system_health] = AnalyticsService.system_health_stats_cached },
      Concurrent::Future.execute { analytics_data[:recent_errors] = ErrorLog.recent_cached.limit(10) }
    ]
    
    # Wait for all operations to complete
    futures.each(&:wait!)
    
    @overview_stats = analytics_data[:overview_stats]
    @user_activity = analytics_data[:user_activity]
    @system_health = analytics_data[:system_health]
    @recent_errors = analytics_data[:recent_errors]
  end

  def users
    # Cache and parallelize user analytics
    cache_key = "analytics_users_#{cache_key_for_time_range(@time_range)}"
    
    @analytics_data = Rails.cache.fetch(cache_key, expires_in: ANALYTICS_CACHE_TTL) do
      analytics_data = Concurrent::Hash.new
      
      futures = [
        Concurrent::Future.execute { analytics_data[:user_metrics] = AnalyticsService.user_metrics(@time_range) },
        Concurrent::Future.execute { analytics_data[:user_retention] = AnalyticsService.user_retention_stats(@time_range) },
        Concurrent::Future.execute { analytics_data[:active_users_chart] = AnalyticsService.active_users_chart_data(@time_range) }
      ]
      
      futures.each(&:wait!)
      analytics_data.to_h
    end
    
    @user_metrics = @analytics_data[:user_metrics]
    @user_retention = @analytics_data[:user_retention]
    @active_users_chart = @analytics_data[:active_users_chart]
  end

  def performance
    # Cache and parallelize performance analytics
    cache_key = "analytics_performance_#{cache_key_for_time_range(@time_range)}"
    
    @analytics_data = Rails.cache.fetch(cache_key, expires_in: ANALYTICS_CACHE_TTL) do
      analytics_data = Concurrent::Hash.new
      
      futures = [
        Concurrent::Future.execute { analytics_data[:performance_overview] = AnalyticsService.performance_overview(@time_range) },
        Concurrent::Future.execute { analytics_data[:slow_operations] = AnalyticsService.slow_operations(@time_range) },
        Concurrent::Future.execute { analytics_data[:database_metrics] = AnalyticsService.database_performance(@time_range) },
        Concurrent::Future.execute { analytics_data[:response_time_chart] = AnalyticsService.response_time_chart_data(@time_range) }
      ]
      
      futures.each(&:wait!)
      analytics_data.to_h
    end
    
    @performance_overview = @analytics_data[:performance_overview]
    @slow_operations = @analytics_data[:slow_operations]
    @database_metrics = @analytics_data[:database_metrics]
    @response_time_chart = @analytics_data[:response_time_chart]
  end

  def errors
    # Cache and parallelize error analytics
    cache_key = "analytics_errors_#{cache_key_for_time_range(@time_range)}"
    
    @analytics_data = Rails.cache.fetch(cache_key, expires_in: ANALYTICS_CACHE_TTL) do
      analytics_data = Concurrent::Hash.new
      
      futures = [
        Concurrent::Future.execute { analytics_data[:error_summary] = AnalyticsService.error_summary(@time_range) },
        Concurrent::Future.execute { analytics_data[:error_trends] = AnalyticsService.error_trends(@time_range) },
        Concurrent::Future.execute { analytics_data[:critical_errors] = ErrorLog.critical_cached.recent.limit(20) }
      ]
      
      futures.each(&:wait!)
      analytics_data.to_h
    end
    
    @error_summary = @analytics_data[:error_summary]
    @error_trends = @analytics_data[:error_trends]
    @critical_errors = @analytics_data[:critical_errors]
  end

  def system
    @system_metrics = MetricsCollectionService.new.collect_all
    @health_checks = HealthCheckService.new.perform
    @backup_status = BackupStatusService.backup_summary
  end

  def export
    format = params[:format] || "json"
    data_type = params[:data_type] || "overview"

    case data_type
    when "users"
      data = AnalyticsService.user_metrics(@time_range)
    when "performance"
      data = AnalyticsService.performance_overview(@time_range)
    when "errors"
      data = AnalyticsService.error_summary(@time_range)
    else
      data = AnalyticsService.overview_stats(@time_range)
    end

    respond_to do |format|
      format.json { render json: data }
      format.csv {
        send_data AnalyticsExportService.to_csv(data, data_type),
                  filename: "analytics_#{data_type}_#{Date.current}.csv"
      }
    end
  end

  private

  def ensure_admin_access
    # Simple admin check - in production, implement proper admin authorization
    unless current_user&.admin? || Rails.env.development?
      redirect_to root_path, alert: "Access denied"
    end
  end

  def set_time_range
    @time_range = case params[:period]
    when "1h"
                   1.hour.ago..Time.current
    when "24h"
                   24.hours.ago..Time.current
    when "7d"
                   7.days.ago..Time.current
    when "30d"
                   30.days.ago..Time.current
    when "90d"
                   90.days.ago..Time.current
    else
                   24.hours.ago..Time.current
    end
  end

  def cache_key_for_time_range(time_range)
    # Create a stable cache key based on time range
    start_time = time_range.begin
    end_time = time_range.end
    
    # Round to nearest minute for better cache hit rates
    start_rounded = Time.at((start_time.to_i / 60) * 60)
    end_rounded = Time.at((end_time.to_i / 60) * 60)
    
    "#{start_rounded.to_i}_#{end_rounded.to_i}"
  end
end
