class HealthCheckService
  def perform
    checks = []
    overall_healthy = true

    # Database connectivity check
    db_check = database_check
    checks << db_check
    overall_healthy &&= db_check[:healthy]

    # Redis connectivity check
    redis_check = redis_check
    checks << redis_check
    overall_healthy &&= redis_check[:healthy]

    # Background job system check
    job_check = background_job_check
    checks << job_check
    overall_healthy &&= job_check[:healthy]

    # Memory usage check
    memory_check = memory_check
    checks << memory_check
    overall_healthy &&= memory_check[:healthy]

    # Disk space check
    disk_check = disk_space_check
    checks << disk_check
    overall_healthy &&= disk_check[:healthy]

    {
      healthy: overall_healthy,
      timestamp: Time.current.iso8601,
      checks: checks,
      version: Rails.application.config.version || "unknown",
      uptime: uptime_seconds
    }
  end

  private

  def database_check
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      name: "database",
      healthy: true,
      response_time_ms: response_time,
      message: "Database connection successful"
    }
  rescue => e
    {
      name: "database",
      healthy: false,
      error: e.message,
      message: "Database connection failed"
    }
  end

  def redis_check
    start_time = Time.current
    Redis.current.ping
    response_time = ((Time.current - start_time) * 1000).round(2)

    {
      name: "redis",
      healthy: true,
      response_time_ms: response_time,
      message: "Redis connection successful"
    }
  rescue => e
    {
      name: "redis",
      healthy: false,
      error: e.message,
      message: "Redis connection failed"
    }
  end

  def background_job_check
    queue_size = SolidQueue::Job.queued.count
    failed_jobs = SolidQueue::Job.failed.count

    # Consider unhealthy if too many failed jobs or queue is backing up
    healthy = failed_jobs < 10 && queue_size < 1000

    {
      name: "background_jobs",
      healthy: healthy,
      queue_size: queue_size,
      failed_jobs: failed_jobs,
      message: healthy ? "Background jobs healthy" : "Background jobs experiencing issues"
    }
  rescue => e
    {
      name: "background_jobs",
      healthy: false,
      error: e.message,
      message: "Background job system check failed"
    }
  end

  def memory_check
    # Check available memory (basic implementation)
    memory_info = `free -m 2>/dev/null`.split("\n")[1]&.split
    if memory_info
      total_memory = memory_info[1].to_i
      used_memory = memory_info[2].to_i
      memory_usage_percent = (used_memory.to_f / total_memory * 100).round(2)

      healthy = memory_usage_percent < 90

      {
        name: "memory",
        healthy: healthy,
        usage_percent: memory_usage_percent,
        used_mb: used_memory,
        total_mb: total_memory,
        message: healthy ? "Memory usage normal" : "High memory usage detected"
      }
    else
      {
        name: "memory",
        healthy: true,
        message: "Memory check not available on this system"
      }
    end
  rescue => e
    {
      name: "memory",
      healthy: false,
      error: e.message,
      message: "Memory check failed"
    }
  end

  def disk_space_check
    # Check disk space for critical directories
    app_disk = disk_usage("/rails")
    tmp_disk = disk_usage("/tmp")

    healthy = app_disk[:usage_percent] < 85 && tmp_disk[:usage_percent] < 85

    {
      name: "disk_space",
      healthy: healthy,
      app_directory: app_disk,
      tmp_directory: tmp_disk,
      message: healthy ? "Disk space sufficient" : "Low disk space detected"
    }
  rescue => e
    {
      name: "disk_space",
      healthy: false,
      error: e.message,
      message: "Disk space check failed"
    }
  end

  def disk_usage(path)
    output = `df #{path} 2>/dev/null`.split("\n")[1]&.split
    if output
      {
        total_gb: (output[1].to_i / 1024.0 / 1024.0).round(2),
        used_gb: (output[2].to_i / 1024.0 / 1024.0).round(2),
        available_gb: (output[3].to_i / 1024.0 / 1024.0).round(2),
        usage_percent: output[4].to_i
      }
    else
      { usage_percent: 0, message: "Unable to check disk usage" }
    end
  end

  def uptime_seconds
    File.read("/proc/uptime").split[0].to_f.round(0)
  rescue
    nil
  end
end
