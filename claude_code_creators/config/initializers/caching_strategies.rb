# Comprehensive caching strategies for performance optimization
Rails.application.configure do
  # Enhanced cache configuration for production
  if Rails.env.production?
    # Multi-layer caching strategy
    config.cache_store = :redis_cache_store, {
      url: ENV["REDIS_URL"] || "redis://localhost:6379/1",
      namespace: "claude_code_creators_cache",
      pool_size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
      pool_timeout: 5,
      reconnect_attempts: 3,
      error_handler: -> (method:, returning:, exception:) {
        Rails.logger.error "Redis cache error: #{exception.message}"
        # Fallback to memory store on Redis failure
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
      }
    }
    
    # Enable SQL query caching
    config.active_record.cache_query_log_tags = true
    
    # Fragment caching enabled
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
  end
end

# Application-wide caching module
module ApplicationCaching
  extend ActiveSupport::Concern
  
  # Cache TTL constants
  CACHE_DURATIONS = {
    very_short: 30.seconds,   # Real-time data
    short: 2.minutes,         # User sessions, presence
    medium: 15.minutes,       # User profiles, settings
    long: 1.hour,             # System stats, configurations
    very_long: 1.day,         # Static content, metadata
    permanent: 1.week         # Rarely changing data
  }.freeze
  
  module ClassMethods
    # Enhanced caching with automatic key generation
    def cached_method(method_name, ttl: :medium, key_generator: nil)
      original_method = "#{method_name}_without_cache"
      alias_method original_method, method_name
      
      define_method method_name do |*args|
        cache_key = if key_generator
          instance_exec(*args, &key_generator)
        else
          "#{self.class.name.underscore}/#{method_name}/#{cache_key_for_args(*args)}"
        end
        
        Rails.cache.fetch(cache_key, expires_in: CACHE_DURATIONS[ttl]) do
          send(original_method, *args)
        end
      end
    end
    
    # Batch cache operations for better performance
    def fetch_multi_cached(keys, ttl: :medium, &block)
      cache_keys = keys.map { |key| "#{name.underscore}/#{key}" }
      
      Rails.cache.fetch_multi(*cache_keys, expires_in: CACHE_DURATIONS[ttl]) do |cache_key|
        original_key = cache_key.split('/').last
        block.call(original_key) if block_given?
      end
    end
  end
  
  included do
    extend ClassMethods
  end
  
  private
  
  def cache_key_for_args(*args)
    return 'no_args' if args.empty?
    
    key_parts = args.map do |arg|
      case arg
      when ActiveRecord::Base
        "#{arg.class.name.underscore}_#{arg.id}_#{arg.updated_at.to_i}"
      when Hash
        arg.sort.to_h.to_json
      when Array
        arg.map { |item| cache_key_for_args(item) }.join('_')
      else
        arg.to_s
      end
    end
    
    Digest::MD5.hexdigest(key_parts.join('_'))
  end
end

# User-specific caching strategies
module UserCaching
  extend ActiveSupport::Concern
  
  included do
    include ApplicationCaching
    
    # Cache user documents
    cached_method :documents_summary, ttl: :medium, key_generator: -> {
      "user_#{id}_documents_#{updated_at.to_i}_#{documents.maximum(:updated_at)&.to_i}"
    }
    
    # Cache user permissions
    cached_method :effective_permissions, ttl: :long, key_generator: -> {
      "user_#{id}_permissions_#{updated_at.to_i}_#{role}"
    }
  end
  
  def invalidate_user_caches
    cache_patterns = [
      "user_#{id}_documents_*",
      "user_#{id}_permissions_*",
      "user_#{id}_context_items_*",
      "user_#{id}_plugin_*"
    ]
    
    cache_patterns.each do |pattern|
      Rails.cache.delete_matched(pattern)
    end
  end
end

# Document-specific caching strategies
module DocumentCaching
  extend ActiveSupport::Concern
  
  included do
    include ApplicationCaching
    
    # Cache document content processing
    cached_method :content_statistics, ttl: :medium, key_generator: -> {
      "document_#{id}_stats_#{updated_at.to_i}_#{content&.updated_at&.to_i}"
    }
    
    # Cache document collaboration info
    cached_method :collaboration_summary, ttl: :short, key_generator: -> {
      active_sessions_updated = collaboration_sessions.active.maximum(:updated_at)&.to_i
      "document_#{id}_collab_#{active_sessions_updated}"
    }
  end
  
  def invalidate_document_caches
    cache_patterns = [
      "document_#{id}_*",
      "documents_user_#{user_id}_*"
    ]
    
    cache_patterns.each do |pattern|
      Rails.cache.delete_matched(pattern)
    end
  end
end

# System-wide caching for frequently accessed data
class SystemCache
  class << self
    def user_activity_summary(timeframe = 1.hour)
      Rails.cache.fetch("system_user_activity_#{timeframe.to_i}", expires_in: 5.minutes) do
        {
          active_users: User.where("last_seen_at > ?", timeframe.ago).count,
          total_users: User.count,
          new_users_today: User.where("created_at > ?", 1.day.ago).count,
          documents_created_today: Document.where("created_at > ?", 1.day.ago).count
        }
      end
    end
    
    def system_health_metrics
      Rails.cache.fetch("system_health_metrics", expires_in: 2.minutes) do
        {
          database_healthy: ApplicationRecord.connection_healthy?,
          redis_healthy: redis_healthy?,
          memory_usage: system_memory_usage,
          active_connections: active_database_connections,
          background_jobs: background_job_stats
        }
      end
    end
    
    def popular_documents(limit = 10)
      Rails.cache.fetch("popular_documents_#{limit}", expires_in: 1.hour) do
        Document.joins(:context_items)
                .group('documents.id')
                .order('COUNT(context_items.id) DESC')
                .limit(limit)
                .includes(:user)
                .select('documents.*, COUNT(context_items.id) as context_count')
      end
    end
    
    def recent_activity_feed(limit = 20)
      Rails.cache.fetch("recent_activity_feed_#{limit}", expires_in: 10.minutes) do
        activities = []
        
        # Recent documents
        activities.concat(
          Document.recent.limit(5).includes(:user).map do |doc|
            {
              type: 'document_created',
              object: doc,
              user: doc.user,
              timestamp: doc.created_at
            }
          end
        )
        
        # Recent context items
        activities.concat(
          ContextItem.recent.limit(10).includes(:document, :user).map do |item|
            {
              type: 'context_item_created',
              object: item,
              user: item.user,
              document: item.document,
              timestamp: item.created_at
            }
          end
        )
        
        # Sort by timestamp and limit
        activities.sort_by { |a| -a[:timestamp].to_i }.first(limit)
      end
    end
    
    private
    
    def redis_healthy?
      Redis.current.ping == "PONG"
    rescue
      false
    end
    
    def system_memory_usage
      return 0 unless File.exist?('/proc/meminfo')
      
      meminfo = File.read('/proc/meminfo')
      total_kb = meminfo[/MemTotal:\s+(\d+)/, 1].to_i
      available_kb = meminfo[/MemAvailable:\s+(\d+)/, 1].to_i
      
      return 0 if total_kb == 0
      
      used_percent = ((total_kb - available_kb).to_f / total_kb * 100).round(1)
      used_percent
    rescue
      0
    end
    
    def active_database_connections
      ActiveRecord::Base.connection_pool.connections.count(&:in_use?)
    rescue
      0
    end
    
    def background_job_stats
      {
        queued: SolidQueue::Job.queued.count,
        running: SolidQueue::Job.running.count,
        failed: SolidQueue::Job.failed.count
      }
    rescue
      { queued: 0, running: 0, failed: 0 }
    end
  end
end

# Cache warming service for preloading frequently accessed data
class CacheWarmingService
  class << self
    def warm_essential_caches
      Rails.logger.info "[CACHE_WARMING] Starting essential cache warming"
      
      warming_jobs = [
        -> { SystemCache.user_activity_summary },
        -> { SystemCache.system_health_metrics },
        -> { SystemCache.popular_documents },
        -> { SystemCache.recent_activity_feed },
        -> { warm_user_caches },
        -> { warm_document_caches }
      ]
      
      warming_jobs.each do |job|
        begin
          job.call
        rescue => e
          Rails.logger.error "[CACHE_WARMING] Failed to warm cache: #{e.message}"
        end
      end
      
      Rails.logger.info "[CACHE_WARMING] Essential cache warming completed"
    end
    
    def warm_user_caches
      # Warm caches for active users
      User.where("last_seen_at > ?", 1.hour.ago).find_each(batch_size: 50) do |user|
        user.documents_summary rescue nil
        user.effective_permissions rescue nil
      end
    end
    
    def warm_document_caches
      # Warm caches for recently accessed documents
      Document.where("updated_at > ?", 1.hour.ago).find_each(batch_size: 50) do |document|
        document.content_statistics rescue nil
        document.collaboration_summary rescue nil
      end
    end
    
    def schedule_cache_warming
      # Schedule cache warming to run every 30 minutes
      return unless Rails.env.production?
      
      Thread.new do
        loop do
          begin
            warm_essential_caches
            sleep(30.minutes)
          rescue => e
            Rails.logger.error "[CACHE_WARMING] Scheduled warming failed: #{e.message}"
            sleep(5.minutes) # Retry in 5 minutes on error
          end
        end
      end
    end
  end
end

# Initialize cache warming in production
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Start cache warming in background
    CacheWarmingService.schedule_cache_warming
    
    Rails.logger.info "[CACHE_STRATEGIES] Caching strategies initialized"
  end
end

# Add caching modules to models
Rails.application.config.to_prepare do
  User.include UserCaching if defined?(User)
  Document.include DocumentCaching if defined?(Document)
end