# Optimized error handling and exception processing for production
Rails.application.configure do
  if Rails.env.production?
    # Enhanced error tracking with performance optimization
    config.consider_all_requests_local = false
    config.action_dispatch.show_exceptions = true
    
    # Custom exception handling middleware for better performance
    config.middleware.insert_before ActionDispatch::ShowExceptions, ErrorHandlingOptimizer
  end
end

# Performance-optimized error handling middleware
class ErrorHandlingOptimizer
  IGNORED_ERRORS = [
    ActionController::RoutingError,
    ActionController::InvalidAuthenticityToken,
    ActionDispatch::Http::MimeNegotiation::InvalidType
  ].freeze
  
  RATE_LIMITED_ERRORS = [
    ActiveRecord::RecordNotFound,
    ActionController::ParameterMissing
  ].freeze
  
  ERROR_SAMPLING_RATES = {
    'ActionController::RoutingError' => 0.1,        # Log 10% of 404s
    'ActiveRecord::RecordNotFound' => 0.2,          # Log 20% of not found
    'ActionController::ParameterMissing' => 0.1,    # Log 10% of parameter errors
    'StandardError' => 1.0                          # Log 100% of other errors
  }.freeze
  
  def initialize(app)
    @app = app
    @error_cache = LruRedux::Cache.new(1000)  # Cache recent errors
    @rate_limiter = {}
  end
  
  def call(env)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    
    begin
      response = @app.call(env)
    rescue => exception
      handle_exception_optimized(exception, env, start_time)
      raise
    end
    
    response
  end
  
  private
  
  def handle_exception_optimized(exception, env, start_time)
    return if should_ignore_error?(exception)
    
    # Rate limiting for common errors
    return if rate_limited?(exception)
    
    # Sampling for high-volume errors
    return unless should_sample_error?(exception)
    
    # Fast error data collection
    error_data = collect_error_data_fast(exception, env, start_time)
    
    # Async error logging to avoid blocking request
    ErrorLoggingJob.perform_later(error_data) if defined?(ErrorLoggingJob)
    
    # Update error cache for debugging
    update_error_cache(exception, error_data)
  end
  
  def should_ignore_error?(exception)
    IGNORED_ERRORS.any? { |error_class| exception.is_a?(error_class) }
  end
  
  def rate_limited?(exception)
    return false unless RATE_LIMITED_ERRORS.any? { |error_class| exception.is_a?(error_class) }
    
    error_key = "#{exception.class.name}_#{exception.message[0..50]}"
    current_time = Time.current.to_i
    
    @rate_limiter[error_key] ||= { count: 0, window_start: current_time }
    rate_data = @rate_limiter[error_key]
    
    # Reset window every minute
    if current_time - rate_data[:window_start] > 60
      rate_data[:count] = 0
      rate_data[:window_start] = current_time
    end
    
    rate_data[:count] += 1
    
    # Limit to 5 errors per minute for rate limited types
    rate_data[:count] > 5
  end
  
  def should_sample_error?(exception)
    error_class = exception.class.name
    sampling_rate = ERROR_SAMPLING_RATES[error_class] || ERROR_SAMPLING_RATES['StandardError']
    
    rand <= sampling_rate
  end
  
  def collect_error_data_fast(exception, env, start_time)
    request = ActionDispatch::Request.new(env)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    
    {
      error_class: exception.class.name,
      message: exception.message.truncate(500),
      backtrace: exception.backtrace&.first(10), # Only top 10 lines
      occurred_at: Time.current,
      environment: Rails.env,
      request_id: request.uuid,
      request_path: request.path,
      request_method: request.method,
      user_agent: request.user_agent&.truncate(200),
      ip_address: request.remote_ip,
      duration_ms: duration_ms,
      memory_usage: current_memory_usage_mb,
      context: extract_minimal_context(env)
    }
  end
  
  def update_error_cache(exception, error_data)
    cache_key = "#{exception.class.name}_#{Digest::MD5.hexdigest(exception.message)}"
    
    cached_error = @error_cache[cache_key]
    if cached_error
      cached_error[:count] += 1
      cached_error[:last_seen] = Time.current
    else
      @error_cache[cache_key] = {
        error_data: error_data,
        count: 1,
        first_seen: Time.current,
        last_seen: Time.current
      }
    end
  end
  
  def extract_minimal_context(env)
    {
      controller: env['action_controller.instance']&.class&.name,
      action: env['action_dispatch.request.path_parameters']&.dig(:action),
      user_id: env['warden']&.user&.id,
      session_id: env['rack.session']&.id&.to_s&.truncate(20)
    }
  end
  
  def current_memory_usage_mb
    return 0 unless defined?(Process)
    
    # Use cached value to avoid frequent system calls
    @last_memory_check ||= { time: 0, value: 0 }
    
    current_time = Time.current.to_i
    if current_time - @last_memory_check[:time] > 30  # Cache for 30 seconds
      begin
        pid = Process.pid
        memory_kb = `ps -o rss= -p #{pid}`.strip.to_i
        @last_memory_check = {
          time: current_time,
          value: (memory_kb / 1024.0).round(2)
        }
      rescue
        @last_memory_check[:value] = 0
      end
    end
    
    @last_memory_check[:value]
  end
end

# Optimized error tracking service
class OptimizedErrorTracker
  class << self
    def track_error(exception, context = {})
      return if should_skip_tracking?(exception)
      
      # Fast error fingerprinting
      fingerprint = generate_error_fingerprint(exception)
      
      # Check if we've seen this error recently
      if recently_tracked?(fingerprint)
        increment_error_count(fingerprint)
        return
      end
      
      # Full error tracking for new errors
      track_full_error(exception, context, fingerprint)
    end
    
    def error_summary_cached(timeframe = 1.hour)
      Rails.cache.fetch("error_summary_#{timeframe.to_i}", expires_in: 5.minutes) do
        {
          total_errors: ErrorLog.where("occurred_at > ?", timeframe.ago).count,
          unique_errors: ErrorLog.where("occurred_at > ?", timeframe.ago).distinct.count(:error_class),
          critical_errors: ErrorLog.where("occurred_at > ?", timeframe.ago).where(error_class: critical_error_classes).count,
          error_rate: calculate_error_rate(timeframe),
          top_errors: top_errors_in_timeframe(timeframe)
        }
      end
    end
    
    def health_check
      Rails.cache.fetch("error_tracker_health", expires_in: 1.minute) do
        recent_errors = ErrorLog.where("occurred_at > ?", 5.minutes.ago).count
        
        {
          status: recent_errors > 50 ? 'degraded' : 'healthy',
          recent_error_count: recent_errors,
          last_critical_error: ErrorLog.where(error_class: critical_error_classes)
                                       .order(:occurred_at)
                                       .last&.occurred_at,
          error_processing_lag: calculate_processing_lag
        }
      end
    end
    
    private
    
    def should_skip_tracking?(exception)
      # Skip tracking for non-critical errors in certain conditions
      exception.is_a?(ActionController::RoutingError) ||
      exception.is_a?(ActionController::InvalidAuthenticityToken) ||
      (exception.is_a?(ActiveRecord::RecordNotFound) && ENV['SKIP_404_TRACKING'] == 'true')
    end
    
    def generate_error_fingerprint(exception)
      # Create a stable fingerprint for error deduplication
      content = "#{exception.class.name}:#{exception.message}:#{exception.backtrace&.first}"
      Digest::SHA256.hexdigest(content)[0..15]  # Use first 16 chars
    end
    
    def recently_tracked?(fingerprint)
      Rails.cache.exist?("error_fingerprint_#{fingerprint}")
    end
    
    def increment_error_count(fingerprint)
      Rails.cache.increment("error_count_#{fingerprint}", 1, expires_in: 1.hour)
    end
    
    def track_full_error(exception, context, fingerprint)
      # Mark as tracked to prevent duplicates
      Rails.cache.write("error_fingerprint_#{fingerprint}", true, expires_in: 10.minutes)
      Rails.cache.write("error_count_#{fingerprint}", 1, expires_in: 1.hour)
      
      # Create error log record
      ErrorLog.create!(
        error_class: exception.class.name,
        message: exception.message.truncate(1000),
        backtrace: exception.backtrace&.first(20)&.join("\n"),
        context: context.to_json,
        environment: Rails.env,
        request_id: context[:request_id],
        occurred_at: Time.current
      )
    rescue => e
      Rails.logger.error "Failed to track error: #{e.message}"
    end
    
    def critical_error_classes
      %w[
        NoMemoryError
        SystemStackError
        SecurityError
        ActiveRecord::ConnectionNotEstablished
        Redis::ConnectionError
        Timeout::Error
      ]
    end
    
    def calculate_error_rate(timeframe)
      total_requests = begin
        # This would integrate with request logging
        1000  # Placeholder
      rescue
        1
      end
      
      error_count = ErrorLog.where("occurred_at > ?", timeframe.ago).count
      return 0 if total_requests == 0
      
      ((error_count.to_f / total_requests) * 100).round(2)
    end
    
    def top_errors_in_timeframe(timeframe)
      ErrorLog.where("occurred_at > ?", timeframe.ago)
              .group(:error_class)
              .order('COUNT(*) DESC')
              .limit(5)
              .count
    end
    
    def calculate_processing_lag
      # Calculate delay between error occurrence and logging
      latest_error = ErrorLog.order(:created_at).last
      return 0 unless latest_error
      
      lag_seconds = latest_error.created_at - latest_error.occurred_at
      lag_seconds > 0 ? lag_seconds.round(2) : 0
    end
  end
end

# Circuit breaker pattern for error-prone operations
class CircuitBreaker
  class << self
    def call(name, failure_threshold: 5, recovery_timeout: 60, &block)
      circuit = get_circuit(name)
      
      case circuit[:state]
      when :closed
        execute_with_monitoring(circuit, &block)
      when :open
        if Time.current.to_i - circuit[:last_failure_time] > recovery_timeout
          circuit[:state] = :half_open
          execute_with_monitoring(circuit, &block)
        else
          raise CircuitOpenError, "Circuit breaker #{name} is open"
        end
      when :half_open
        execute_with_monitoring(circuit, &block)
      end
    end
    
    private
    
    def get_circuit(name)
      @circuits ||= {}
      @circuits[name] ||= {
        state: :closed,
        failure_count: 0,
        last_failure_time: 0,
        failure_threshold: 5
      }
    end
    
    def execute_with_monitoring(circuit)
      result = yield
      
      # Reset on success
      circuit[:failure_count] = 0
      circuit[:state] = :closed if circuit[:state] == :half_open
      
      result
    rescue => e
      circuit[:failure_count] += 1
      circuit[:last_failure_time] = Time.current.to_i
      
      if circuit[:failure_count] >= circuit[:failure_threshold]
        circuit[:state] = :open
        Rails.logger.warn "Circuit breaker opened due to #{circuit[:failure_count]} failures"
      end
      
      raise e
    end
  end
  
  class CircuitOpenError < StandardError; end
end

# Background job for async error logging is defined in app/jobs/error_logging_job.rb

# Initialize error handling optimizations
Rails.application.config.after_initialize do
  if Rails.env.production?
    # Set up global exception handler
    ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |name, started, finished, unique_id, data|
      if data[:exception_object]
        OptimizedErrorTracker.track_error(
          data[:exception_object],
          {
            controller: data[:controller],
            action: data[:action],
            request_id: unique_id,
            duration: finished - started
          }
        )
      end
    end
    
    Rails.logger.info "[ERROR_OPTIMIZATION] Error handling optimizations initialized"
  end
end