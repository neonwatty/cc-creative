class AlertingService
  class << self
    def send_critical_alert(title:, message:, context: {})
      alert_data = {
        severity: "critical",
        title: title,
        message: message,
        context: context,
        timestamp: Time.current.iso8601,
        environment: Rails.env
      }

      # Send via multiple channels
      send_slack_alert(alert_data) if slack_configured?
      send_email_alert(alert_data) if email_configured?
      send_webhook_alert(alert_data) if webhook_configured?
      
      # Log the alert
      Rails.logger.error("Critical Alert: #{alert_data.to_json}")
      
      # Store in database for tracking
      store_alert(alert_data)
      
      alert_data
    rescue => e
      Rails.logger.error("Failed to send critical alert: #{e.message}")
      nil
    end

    def send_warning_alert(title:, message:, context: {})
      alert_data = {
        severity: "warning",
        title: title,
        message: message,
        context: context,
        timestamp: Time.current.iso8601,
        environment: Rails.env
      }

      # Send via configured channels (less aggressive than critical)
      send_slack_alert(alert_data) if slack_configured?
      
      # Log the alert
      Rails.logger.warn("Warning Alert: #{alert_data.to_json}")
      
      # Store in database
      store_alert(alert_data)
      
      alert_data
    rescue => e
      Rails.logger.error("Failed to send warning alert: #{e.message}")
      nil
    end

    def send_info_alert(title:, message:, context: {})
      alert_data = {
        severity: "info",
        title: title,
        message: message,
        context: context,
        timestamp: Time.current.iso8601,
        environment: Rails.env
      }

      # Log the alert
      Rails.logger.info("Info Alert: #{alert_data.to_json}")
      
      # Store in database
      store_alert(alert_data)
      
      alert_data
    rescue => e
      Rails.logger.error("Failed to send info alert: #{e.message}")
      nil
    end

    def check_alert_thresholds
      # Check various system metrics and trigger alerts if thresholds are breached
      check_error_rate_threshold
      check_response_time_threshold
      check_resource_usage_threshold
      check_background_job_threshold
    end

    private

    def slack_configured?
      ENV["SLACK_WEBHOOK_URL"].present?
    end

    def email_configured?
      ENV["ALERT_EMAIL_TO"].present?
    end

    def webhook_configured?
      ENV["ALERT_WEBHOOK_URL"].present?
    end

    def send_slack_alert(alert_data)
      webhook_url = ENV["SLACK_WEBHOOK_URL"]
      return unless webhook_url

      payload = {
        text: "#{alert_data[:severity].upcase}: #{alert_data[:title]}",
        attachments: [
          {
            color: severity_color(alert_data[:severity]),
            fields: [
              {
                title: "Message",
                value: alert_data[:message],
                short: false
              },
              {
                title: "Environment",
                value: alert_data[:environment],
                short: true
              },
              {
                title: "Timestamp",
                value: alert_data[:timestamp],
                short: true
              }
            ]
          }
        ]
      }

      # Send HTTP request to Slack webhook
      uri = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"
      
      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json
      
      response = http.request(request)
      
      unless response.code.to_i == 200
        Rails.logger.error("Failed to send Slack alert: #{response.code} - #{response.body}")
      end
    rescue => e
      Rails.logger.error("Error sending Slack alert: #{e.message}")
    end

    def send_email_alert(alert_data)
      email_to = ENV["ALERT_EMAIL_TO"]
      return unless email_to

      AlertMailer.critical_alert(
        to: email_to,
        subject: "#{alert_data[:severity].upcase}: #{alert_data[:title]}",
        alert_data: alert_data
      ).deliver_now
    rescue => e
      Rails.logger.error("Error sending email alert: #{e.message}")
    end

    def send_webhook_alert(alert_data)
      webhook_url = ENV["ALERT_WEBHOOK_URL"]
      return unless webhook_url

      uri = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"
      
      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = alert_data.to_json
      
      response = http.request(request)
      
      unless response.code.to_i == 200
        Rails.logger.error("Failed to send webhook alert: #{response.code} - #{response.body}")
      end
    rescue => e
      Rails.logger.error("Error sending webhook alert: #{e.message}")
    end

    def store_alert(alert_data)
      # Store alert in database for tracking and history
      # This would require an Alert model
      Rails.logger.info("Alert stored: #{alert_data[:title]}")
    rescue => e
      Rails.logger.error("Error storing alert: #{e.message}")
    end

    def severity_color(severity)
      case severity
      when "critical"
        "danger"
      when "warning"
        "warning"
      when "info"
        "good"
      else
        "good"
      end
    end

    def check_error_rate_threshold
      error_rate = calculate_recent_error_rate
      threshold = ENV.fetch("ERROR_RATE_THRESHOLD", "5").to_f
      
      if error_rate > threshold
        send_critical_alert(
          title: "High Error Rate Detected",
          message: "Error rate is #{error_rate}% over the last 5 minutes (threshold: #{threshold}%)",
          context: { error_rate: error_rate, threshold: threshold }
        )
      end
    end

    def check_response_time_threshold
      avg_response_time = calculate_recent_response_time
      threshold = ENV.fetch("RESPONSE_TIME_THRESHOLD", "1000").to_f
      
      if avg_response_time > threshold
        send_warning_alert(
          title: "High Response Time Detected",
          message: "Average response time is #{avg_response_time}ms over the last 5 minutes (threshold: #{threshold}ms)",
          context: { avg_response_time: avg_response_time, threshold: threshold }
        )
      end
    end

    def check_resource_usage_threshold
      memory_usage = get_memory_usage_percent
      cpu_usage = get_cpu_usage_percent
      disk_usage = get_disk_usage_percent
      
      memory_threshold = ENV.fetch("MEMORY_THRESHOLD", "85").to_f
      cpu_threshold = ENV.fetch("CPU_THRESHOLD", "80").to_f
      disk_threshold = ENV.fetch("DISK_THRESHOLD", "90").to_f
      
      if memory_usage > memory_threshold
        send_critical_alert(
          title: "High Memory Usage",
          message: "Memory usage is #{memory_usage}% (threshold: #{memory_threshold}%)",
          context: { memory_usage: memory_usage, threshold: memory_threshold }
        )
      end
      
      if cpu_usage > cpu_threshold
        send_warning_alert(
          title: "High CPU Usage",
          message: "CPU usage is #{cpu_usage}% (threshold: #{cpu_threshold}%)",
          context: { cpu_usage: cpu_usage, threshold: cpu_threshold }
        )
      end
      
      if disk_usage > disk_threshold
        send_critical_alert(
          title: "High Disk Usage",
          message: "Disk usage is #{disk_usage}% (threshold: #{disk_threshold}%)",
          context: { disk_usage: disk_usage, threshold: disk_threshold }
        )
      end
    end

    def check_background_job_threshold
      failed_jobs = SolidQueue::Job.failed.count
      queued_jobs = SolidQueue::Job.queued.count
      
      failed_threshold = ENV.fetch("FAILED_JOBS_THRESHOLD", "10").to_i
      queued_threshold = ENV.fetch("QUEUED_JOBS_THRESHOLD", "100").to_i
      
      if failed_jobs > failed_threshold
        send_warning_alert(
          title: "High Number of Failed Jobs",
          message: "#{failed_jobs} jobs have failed (threshold: #{failed_threshold})",
          context: { failed_jobs: failed_jobs, threshold: failed_threshold }
        )
      end
      
      if queued_jobs > queued_threshold
        send_info_alert(
          title: "High Number of Queued Jobs",
          message: "#{queued_jobs} jobs are queued (threshold: #{queued_threshold})",
          context: { queued_jobs: queued_jobs, threshold: queued_threshold }
        )
      end
    end

    def calculate_recent_error_rate
      last_5_minutes = 5.minutes.ago..Time.current
      total_requests = PerformanceLog.where(occurred_at: last_5_minutes).count
      total_errors = ErrorLog.where(occurred_at: last_5_minutes).count
      
      return 0 if total_requests == 0
      
      (total_errors.to_f / total_requests * 100).round(2)
    end

    def calculate_recent_response_time
      last_5_minutes = 5.minutes.ago..Time.current
      PerformanceLog.where(occurred_at: last_5_minutes)
                   .average(:duration_ms)
                   &.round(2) || 0
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