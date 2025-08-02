class MetricsCollectionService
  # Performance optimizations
  METRICS_CACHE_TTL = 30.seconds
  EXPENSIVE_METRICS_CACHE_TTL = 5.minutes
  
  def collect_all
    Rails.cache.fetch("metrics_collection_all", expires_in: METRICS_CACHE_TTL) do
      {
        timestamp: Time.current.iso8601,
        application: application_metrics,
        database: database_metrics_cached,
        redis: redis_metrics_cached,
        system: system_metrics_cached,
        business: business_metrics_cached
      }
    end
  end

  def collect_lightweight
    # Fast metrics collection for frequent monitoring
    {
      timestamp: Time.current.iso8601,
      application: {
        memory_usage: process_memory_usage,
        thread_count: Thread.list.count,
        active_connections: active_connections_count
      },
      database: {
        active_connections: database_active_connections,
        available_connections: database_available_connections
      }
    }
  end

  private

  def application_metrics
    {
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      environment: Rails.env,
      uptime_seconds: uptime_seconds,
      active_connections: active_connections_count,
      thread_count: Thread.list.count,
      memory_usage: process_memory_usage
    }
  end

  def database_metrics_cached
    Rails.cache.fetch("metrics_database", expires_in: METRICS_CACHE_TTL) do
      database_metrics
    end
  end

  def database_metrics
    connection = ActiveRecord::Base.connection

    # Database connection pool stats
    pool = ActiveRecord::Base.connection_pool

    # Query execution metrics
    query_stats = database_query_stats

    {
      adapter: connection.adapter_name,
      pool_size: pool.size,
      active_connections: database_active_connections,
      available_connections: database_available_connections,
      query_count_1m: query_stats[:count_1m],
      avg_query_time_ms: query_stats[:avg_time_ms],
      slow_queries_1m: query_stats[:slow_queries_1m],
      database_size_mb: database_size_mb_cached
    }
  rescue => e
    {
      error: e.message,
      available: false
    }
  end

  def database_active_connections
    @database_active_connections ||= ActiveRecord::Base.connection_pool.connections.count(&:in_use?)
  end

  def database_available_connections
    @database_available_connections ||= ActiveRecord::Base.connection_pool.available_connection_count
  end

  def redis_metrics_cached
    Rails.cache.fetch("metrics_redis", expires_in: METRICS_CACHE_TTL) do
      redis_metrics
    end
  end

  def redis_metrics
    info = Redis.current.info

    {
      connected_clients: info["connected_clients"].to_i,
      used_memory_mb: (info["used_memory"].to_i / 1024.0 / 1024.0).round(2),
      used_memory_peak_mb: (info["used_memory_peak"].to_i / 1024.0 / 1024.0).round(2),
      total_commands_processed: info["total_commands_processed"].to_i,
      expired_keys: info["expired_keys"].to_i,
      evicted_keys: info["evicted_keys"].to_i,
      keyspace_hits: info["keyspace_hits"].to_i,
      keyspace_misses: info["keyspace_misses"].to_i,
      hit_rate: calculate_hit_rate(info["keyspace_hits"].to_i, info["keyspace_misses"].to_i)
    }
  rescue => e
    {
      error: e.message,
      available: false
    }
  end

  def system_metrics_cached
    Rails.cache.fetch("metrics_system", expires_in: EXPENSIVE_METRICS_CACHE_TTL) do
      system_metrics
    end
  end

  def system_metrics
    {
      load_average: load_average,
      memory: system_memory_stats,
      disk: disk_usage_stats_cached,
      network: network_stats_cached
    }
  rescue => e
    {
      error: e.message,
      available: false
    }
  end

  def business_metrics_cached
    Rails.cache.fetch("metrics_business", expires_in: METRICS_CACHE_TTL) do
      business_metrics
    end
  end

  def business_metrics
    # Application-specific business metrics with optimization
    Rails.cache.fetch("business_metrics_aggregated", expires_in: 2.minutes) do
      {
        total_users: User.count,
        active_users_1h: User.where("last_seen_at > ?", 1.hour.ago).count,
        active_users_24h: User.where("last_seen_at > ?", 24.hours.ago).count,
        total_documents: Document.count,
        documents_created_24h: Document.where("created_at > ?", 24.hours.ago).count,
        total_contexts: ClaudeContext.count,
        contexts_created_24h: ClaudeContext.where("created_at > ?", 24.hours.ago).count,
        background_jobs_queued: background_jobs_queued_count,
        background_jobs_running: background_jobs_running_count,
        background_jobs_failed: background_jobs_failed_count
      }
    end
  rescue => e
    {
      error: e.message,
      available: false
    }
  end

  def uptime_seconds
    File.read("/proc/uptime").split[0].to_f.round(0)
  rescue
    Time.current.to_i - Rails.application.config.started_at.to_i
  end

  def active_connections_count
    # Count active database connections
    ActiveRecord::Base.connection_pool.connections.count(&:in_use?)
  rescue
    0
  end

  def process_memory_usage
    # Get current process memory usage
    pid = Process.pid
    memory_info = `ps -o rss= -p #{pid}`.strip.to_i # RSS in KB
    (memory_info / 1024.0).round(2) # Convert to MB
  rescue
    0
  end

  def database_query_stats
    # This would typically integrate with APM or custom query logging
    # For now, return placeholder data
    {
      count_1m: 0,
      avg_time_ms: 0,
      slow_queries_1m: 0
    }
  end

  def database_size_mb_cached
    Rails.cache.fetch("database_size_mb", expires_in: 1.hour) do
      database_size_mb
    end
  end

  def database_size_mb
    case ActiveRecord::Base.connection.adapter_name.downcase
    when "postgresql"
      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_database_size(current_database()) / 1024.0 / 1024.0 AS size_mb"
      )
      result.first["size_mb"].to_f.round(2)
    when "mysql", "mysql2"
      result = ActiveRecord::Base.connection.execute(
        "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
         FROM information_schema.tables
         WHERE table_schema = DATABASE()"
      )
      result.first[0].to_f
    else
      0
    end
  rescue
    0
  end

  def calculate_hit_rate(hits, misses)
    total = hits + misses
    return 0 if total == 0
    ((hits.to_f / total) * 100).round(2)
  end

  def load_average
    File.read("/proc/loadavg").split[0..2].map(&:to_f)
  rescue
    [ 0, 0, 0 ]
  end

  def system_memory_stats
    memory_info = `free -m 2>/dev/null`.split("\n")[1]&.split
    return {} unless memory_info

    {
      total_mb: memory_info[1].to_i,
      used_mb: memory_info[2].to_i,
      free_mb: memory_info[3].to_i,
      usage_percent: ((memory_info[2].to_f / memory_info[1]) * 100).round(2)
    }
  rescue
    {}
  end

  def disk_usage_stats_cached
    Rails.cache.fetch("disk_usage_stats", expires_in: EXPENSIVE_METRICS_CACHE_TTL) do
      disk_usage_stats
    end
  end

  def disk_usage_stats
    app_usage = disk_usage_for_path("/")
    tmp_usage = disk_usage_for_path("/tmp")

    {
      root: app_usage,
      tmp: tmp_usage
    }
  rescue
    {}
  end

  def disk_usage_for_path(path)
    output = `df #{path} 2>/dev/null`.split("\n")[1]&.split
    return {} unless output

    {
      total_gb: (output[1].to_i / 1024.0 / 1024.0).round(2),
      used_gb: (output[2].to_i / 1024.0 / 1024.0).round(2),
      available_gb: (output[3].to_i / 1024.0 / 1024.0).round(2),
      usage_percent: output[4].to_i
    }
  end

  def network_stats_cached
    Rails.cache.fetch("network_stats", expires_in: EXPENSIVE_METRICS_CACHE_TTL) do
      network_stats
    end
  end

  def network_stats
    # Basic network statistics - would be enhanced in production
    {
      tcp_connections: tcp_connection_count
    }
  rescue
    {}
  end
  
  # Background job optimization methods
  def background_jobs_queued_count
    Rails.cache.fetch("bg_jobs_queued", expires_in: 30.seconds) do
      SolidQueue::Job.queued.count
    end
  rescue
    0
  end

  def background_jobs_running_count
    Rails.cache.fetch("bg_jobs_running", expires_in: 30.seconds) do
      SolidQueue::Job.running.count
    end
  rescue
    0
  end

  def background_jobs_failed_count
    Rails.cache.fetch("bg_jobs_failed", expires_in: 30.seconds) do
      SolidQueue::Job.failed.count
    end
  rescue
    0
  end

  def tcp_connection_count
    `netstat -tn 2>/dev/null | grep ESTABLISHED | wc -l`.strip.to_i
  rescue
    0
  end
end
