class PrometheusMetricsService
  def format_metrics
    metrics = MetricsCollectionService.new.collect_all
    prometheus_output = []

    # Add metadata
    prometheus_output << "# HELP claude_code_creators_info Application information"
    prometheus_output << "# TYPE claude_code_creators_info gauge"
    prometheus_output << "claude_code_creators_info{version=\"#{Rails.application.config.version || 'unknown'}\",rails_version=\"#{Rails.version}\",ruby_version=\"#{RUBY_VERSION}\"} 1"
    prometheus_output << ""

    # Application metrics
    if metrics[:application]
      add_application_metrics(prometheus_output, metrics[:application])
    end

    # Database metrics
    if metrics[:database] && !metrics[:database][:error]
      add_database_metrics(prometheus_output, metrics[:database])
    end

    # Redis metrics
    if metrics[:redis] && !metrics[:redis][:error]
      add_redis_metrics(prometheus_output, metrics[:redis])
    end

    # System metrics
    if metrics[:system] && !metrics[:system][:error]
      add_system_metrics(prometheus_output, metrics[:system])
    end

    # Business metrics
    if metrics[:business] && !metrics[:business][:error]
      add_business_metrics(prometheus_output, metrics[:business])
    end

    prometheus_output.join("\n")
  end

  private

  def add_application_metrics(output, app_metrics)
    output << "# HELP claude_uptime_seconds Application uptime in seconds"
    output << "# TYPE claude_uptime_seconds counter"
    output << "claude_uptime_seconds #{app_metrics[:uptime_seconds]}"
    output << ""

    output << "# HELP claude_active_connections Current number of active database connections"
    output << "# TYPE claude_active_connections gauge"
    output << "claude_active_connections #{app_metrics[:active_connections]}"
    output << ""

    output << "# HELP claude_thread_count Current number of Ruby threads"
    output << "# TYPE claude_thread_count gauge"
    output << "claude_thread_count #{app_metrics[:thread_count]}"
    output << ""

    output << "# HELP claude_memory_usage_mb Process memory usage in megabytes"
    output << "# TYPE claude_memory_usage_mb gauge"
    output << "claude_memory_usage_mb #{app_metrics[:memory_usage]}"
    output << ""
  end

  def add_database_metrics(output, db_metrics)
    output << "# HELP claude_db_pool_size Database connection pool size"
    output << "# TYPE claude_db_pool_size gauge"
    output << "claude_db_pool_size #{db_metrics[:pool_size]}"
    output << ""

    output << "# HELP claude_db_active_connections Active database connections"
    output << "# TYPE claude_db_active_connections gauge"
    output << "claude_db_active_connections #{db_metrics[:active_connections]}"
    output << ""

    output << "# HELP claude_db_available_connections Available database connections"
    output << "# TYPE claude_db_available_connections gauge"
    output << "claude_db_available_connections #{db_metrics[:available_connections]}"
    output << ""

    output << "# HELP claude_db_size_mb Database size in megabytes"
    output << "# TYPE claude_db_size_mb gauge"
    output << "claude_db_size_mb #{db_metrics[:database_size_mb]}"
    output << ""

    output << "# HELP claude_db_queries_total Total number of database queries in last minute"
    output << "# TYPE claude_db_queries_total counter"
    output << "claude_db_queries_total #{db_metrics[:query_count_1m]}"
    output << ""

    output << "# HELP claude_db_avg_query_time_ms Average query time in milliseconds"
    output << "# TYPE claude_db_avg_query_time_ms gauge"
    output << "claude_db_avg_query_time_ms #{db_metrics[:avg_query_time_ms]}"
    output << ""
  end

  def add_redis_metrics(output, redis_metrics)
    output << "# HELP claude_redis_connected_clients Number of connected Redis clients"
    output << "# TYPE claude_redis_connected_clients gauge"
    output << "claude_redis_connected_clients #{redis_metrics[:connected_clients]}"
    output << ""

    output << "# HELP claude_redis_used_memory_mb Redis memory usage in megabytes"
    output << "# TYPE claude_redis_used_memory_mb gauge"
    output << "claude_redis_used_memory_mb #{redis_metrics[:used_memory_mb]}"
    output << ""

    output << "# HELP claude_redis_commands_total Total Redis commands processed"
    output << "# TYPE claude_redis_commands_total counter"
    output << "claude_redis_commands_total #{redis_metrics[:total_commands_processed]}"
    output << ""

    output << "# HELP claude_redis_keyspace_hits_total Redis keyspace hits"
    output << "# TYPE claude_redis_keyspace_hits_total counter"
    output << "claude_redis_keyspace_hits_total #{redis_metrics[:keyspace_hits]}"
    output << ""

    output << "# HELP claude_redis_keyspace_misses_total Redis keyspace misses"
    output << "# TYPE claude_redis_keyspace_misses_total counter"
    output << "claude_redis_keyspace_misses_total #{redis_metrics[:keyspace_misses]}"
    output << ""

    output << "# HELP claude_redis_hit_rate_percent Redis cache hit rate percentage"
    output << "# TYPE claude_redis_hit_rate_percent gauge"
    output << "claude_redis_hit_rate_percent #{redis_metrics[:hit_rate]}"
    output << ""
  end

  def add_system_metrics(output, system_metrics)
    if system_metrics[:load_average]
      output << "# HELP claude_load_average_1m System load average (1 minute)"
      output << "# TYPE claude_load_average_1m gauge"
      output << "claude_load_average_1m #{system_metrics[:load_average][0]}"
      output << ""

      output << "# HELP claude_load_average_5m System load average (5 minutes)"
      output << "# TYPE claude_load_average_5m gauge"
      output << "claude_load_average_5m #{system_metrics[:load_average][1]}"
      output << ""
    end

    if system_metrics[:memory]
      memory = system_metrics[:memory]
      output << "# HELP claude_system_memory_total_mb Total system memory in megabytes"
      output << "# TYPE claude_system_memory_total_mb gauge"
      output << "claude_system_memory_total_mb #{memory[:total_mb]}"
      output << ""

      output << "# HELP claude_system_memory_used_mb Used system memory in megabytes"
      output << "# TYPE claude_system_memory_used_mb gauge"
      output << "claude_system_memory_used_mb #{memory[:used_mb]}"
      output << ""

      output << "# HELP claude_system_memory_usage_percent System memory usage percentage"
      output << "# TYPE claude_system_memory_usage_percent gauge"
      output << "claude_system_memory_usage_percent #{memory[:usage_percent]}"
      output << ""
    end

    if system_metrics[:disk]
      disk = system_metrics[:disk]
      if disk[:root]
        output << "# HELP claude_disk_usage_percent Disk usage percentage"
        output << "# TYPE claude_disk_usage_percent gauge"
        output << "claude_disk_usage_percent{mount=\"root\"} #{disk[:root][:usage_percent]}"
        if disk[:tmp]
          output << "claude_disk_usage_percent{mount=\"tmp\"} #{disk[:tmp][:usage_percent]}"
        end
        output << ""
      end
    end
  end

  def add_business_metrics(output, business_metrics)
    output << "# HELP claude_users_total Total number of users"
    output << "# TYPE claude_users_total gauge"
    output << "claude_users_total #{business_metrics[:total_users]}"
    output << ""

    output << "# HELP claude_active_users_1h Active users in last hour"
    output << "# TYPE claude_active_users_1h gauge"
    output << "claude_active_users_1h #{business_metrics[:active_users_1h]}"
    output << ""

    output << "# HELP claude_active_users_24h Active users in last 24 hours"
    output << "# TYPE claude_active_users_24h gauge"
    output << "claude_active_users_24h #{business_metrics[:active_users_24h]}"
    output << ""

    output << "# HELP claude_documents_total Total number of documents"
    output << "# TYPE claude_documents_total gauge"
    output << "claude_documents_total #{business_metrics[:total_documents]}"
    output << ""

    output << "# HELP claude_contexts_total Total number of Claude contexts"
    output << "# TYPE claude_contexts_total gauge"
    output << "claude_contexts_total #{business_metrics[:total_contexts]}"
    output << ""

    output << "# HELP claude_background_jobs Background jobs by status"
    output << "# TYPE claude_background_jobs gauge"
    output << "claude_background_jobs{status=\"queued\"} #{business_metrics[:background_jobs_queued]}"
    output << "claude_background_jobs{status=\"running\"} #{business_metrics[:background_jobs_running]}"
    output << "claude_background_jobs{status=\"failed\"} #{business_metrics[:background_jobs_failed]}"
    output << ""
  end
end
