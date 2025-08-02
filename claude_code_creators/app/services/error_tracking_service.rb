class ErrorTrackingService
  class << self
    def track_error(error, context = {})
      error_data = {
        timestamp: Time.current.iso8601,
        error_class: error.class.name,
        message: error.message,
        backtrace: error.backtrace&.first(20),
        context: sanitize_context(context),
        environment: Rails.env,
        application_version: Rails.application.config.version || "unknown",
        request_id: current_request_id
      }

      # Log to Rails logger
      Rails.logger.error("Error tracked: #{error_data.to_json}")

      # Send to external error tracking service if configured
      send_to_sentry(error_data) if sentry_configured?

      # Store in database for local tracking
      store_error_locally(error_data)

      # Trigger alerts for critical errors
      trigger_alert_if_critical(error_data)

      error_data
    rescue => tracking_error
      # Don't let error tracking itself cause failures
      Rails.logger.error("Error tracking failed: #{tracking_error.message}")
      nil
    end

    def track_performance(operation, duration_ms, metadata = {})
      performance_data = {
        timestamp: Time.current.iso8601,
        operation: operation,
        duration_ms: duration_ms,
        metadata: sanitize_context(metadata),
        environment: Rails.env,
        request_id: current_request_id
      }

      # Log performance data
      Rails.logger.info("Performance: #{performance_data.to_json}")

      # Store for analytics
      store_performance_data(performance_data)

      performance_data
    end

    def track_business_event(event_name, data = {})
      event_data = {
        timestamp: Time.current.iso8601,
        event_name: event_name,
        data: sanitize_context(data),
        environment: Rails.env,
        request_id: current_request_id
      }

      # Log business event
      Rails.logger.info("Business Event: #{event_data.to_json}")

      # Store for analytics
      store_business_event(event_data)

      event_data
    end

    private

    def sanitize_context(context)
      # Remove sensitive information from context
      sensitive_keys = %w[password token secret key api_key authorization]

      case context
      when Hash
        context.deep_dup.tap do |sanitized|
          sanitized.each do |key, value|
            if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
              sanitized[key] = "[FILTERED]"
            elsif value.is_a?(Hash)
              sanitized[key] = sanitize_context(value)
            end
          end
        end
      when Array
        context.map { |item| sanitize_context(item) }
      else
        context
      end
    end

    def current_request_id
      Thread.current[:request_id] || SecureRandom.uuid
    end

    def sentry_configured?
      ENV["SENTRY_DSN"].present?
    end

    def send_to_sentry(error_data)
      # Integration with Sentry (if configured)
      return unless defined?(Sentry)

      Sentry.capture_message(
        "#{error_data[:error_class]}: #{error_data[:message]}",
        level: :error,
        extra: error_data[:context],
        tags: {
          environment: error_data[:environment],
          version: error_data[:application_version]
        }
      )
    rescue => e
      Rails.logger.error("Failed to send to Sentry: #{e.message}")
    end

    def store_error_locally(error_data)
      # Store in database for local error tracking
      ErrorLog.create!(
        error_class: error_data[:error_class],
        message: error_data[:message],
        backtrace: error_data[:backtrace]&.join("\n"),
        context: error_data[:context],
        environment: error_data[:environment],
        request_id: error_data[:request_id],
        occurred_at: Time.current
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to store error locally: #{e.message}")
    end

    def store_performance_data(performance_data)
      PerformanceLog.create!(
        operation: performance_data[:operation],
        duration_ms: performance_data[:duration_ms],
        metadata: performance_data[:metadata],
        environment: performance_data[:environment],
        request_id: performance_data[:request_id],
        occurred_at: Time.current
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to store performance data: #{e.message}")
    end

    def store_business_event(event_data)
      BusinessEventLog.create!(
        event_name: event_data[:event_name],
        event_data: event_data[:data],
        environment: event_data[:environment],
        request_id: event_data[:request_id],
        occurred_at: Time.current
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to store business event: #{e.message}")
    end

    def trigger_alert_if_critical(error_data)
      # Define critical error patterns
      critical_patterns = [
        /database.*connection/i,
        /redis.*connection/i,
        /authentication.*failed/i,
        /authorization.*denied/i,
        /payment.*failed/i,
        /security.*violation/i
      ]

      is_critical = critical_patterns.any? do |pattern|
        error_data[:message].match?(pattern) || error_data[:error_class].match?(pattern)
      end

      if is_critical
        AlertingService.send_critical_alert(
          title: "Critical Error Detected",
          message: "#{error_data[:error_class]}: #{error_data[:message]}",
          context: error_data[:context]
        )
      end
    end
  end
end
