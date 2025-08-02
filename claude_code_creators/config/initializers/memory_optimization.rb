# Memory optimization and garbage collection tuning for production
if Rails.env.production?
  # Ruby GC tuning for better performance
  GC::Profiler.clear
  
  # Optimize Ruby GC settings for web application workload
  ENV["RUBY_GC_HEAP_INIT_SLOTS"] ||= "600000"
  ENV["RUBY_GC_HEAP_FREE_SLOTS"] ||= "600000"
  ENV["RUBY_GC_HEAP_GROWTH_FACTOR"] ||= "1.25"
  ENV["RUBY_GC_HEAP_GROWTH_MAX_SLOTS"] ||= "300000"
  ENV["RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR"] ||= "2.0"
  ENV["RUBY_GC_MALLOC_LIMIT"] ||= "67108864"
  ENV["RUBY_GC_MALLOC_LIMIT_MAX"] ||= "134217728"
  ENV["RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR"] ||= "1.4"
  ENV["RUBY_GC_OLDMALLOC_LIMIT"] ||= "67108864"
  ENV["RUBY_GC_OLDMALLOC_LIMIT_MAX"] ||= "134217728"
  ENV["RUBY_GC_OLDMALLOC_LIMIT_GROWTH_FACTOR"] ||= "1.2"

  # Monitor memory usage and GC performance
  class MemoryMonitor
    MEMORY_THRESHOLD_MB = 1024  # Alert if memory usage exceeds 1GB
    GC_TIME_THRESHOLD_MS = 100  # Alert if GC takes longer than 100ms
    
    class << self
      def start_monitoring
        return unless Rails.env.production?
        
        # Set up periodic memory monitoring
        Thread.new do
          loop do
            begin
              monitor_memory_usage
              monitor_gc_performance
              sleep(60) # Check every minute
            rescue => e
              Rails.logger.error "Memory monitoring error: #{e.message}"
              sleep(300) # Wait 5 minutes before retrying
            end
          end
        end
      end
      
      def monitor_memory_usage
        memory_mb = current_memory_usage_mb
        
        if memory_mb > MEMORY_THRESHOLD_MB
          Rails.logger.warn "[MEMORY_ALERT] High memory usage: #{memory_mb}MB"
          
          # Log to performance tracking
          if defined?(PerformanceLog)
            PerformanceLog.create!(
              operation: "memory_usage_high",
              duration_ms: memory_mb,
              occurred_at: Time.current,
              environment: Rails.env,
              metadata: {
                memory_mb: memory_mb,
                threshold_mb: MEMORY_THRESHOLD_MB,
                gc_stats: GC.stat
              }
            )
          end
          
          # Force garbage collection if memory is critically high
          if memory_mb > MEMORY_THRESHOLD_MB * 1.5
            Rails.logger.warn "[MEMORY_CRITICAL] Forcing garbage collection"
            GC.start
          end
        end
      end
      
      def monitor_gc_performance
        gc_stats = GC.stat
        
        # Calculate GC efficiency metrics
        gc_efficiency = {
          total_collections: gc_stats[:count],
          major_collections: gc_stats[:major_gc_count],
          minor_collections: gc_stats[:minor_gc_count],
          heap_allocated_pages: gc_stats[:heap_allocated_pages],
          heap_live_slots: gc_stats[:heap_live_slots],
          heap_free_slots: gc_stats[:heap_free_slots],
          heap_final_slots: gc_stats[:heap_final_slots],
          total_allocated_objects: gc_stats[:total_allocated_objects],
          total_freed_objects: gc_stats[:total_freed_objects]
        }
        
        # Log GC performance metrics periodically
        if gc_stats[:count] % 100 == 0  # Every 100 GC cycles
          Rails.logger.info "[GC_METRICS] #{gc_efficiency.to_json}"
        end
        
        # Monitor for GC pressure
        if gc_stats[:heap_free_slots] < gc_stats[:heap_live_slots] * 0.1
          Rails.logger.warn "[GC_PRESSURE] Low free slots ratio: #{gc_stats[:heap_free_slots]}/#{gc_stats[:heap_live_slots]}"
        end
      end
      
      def current_memory_usage_mb
        # Get RSS memory usage
        pid = Process.pid
        memory_kb = `ps -o rss= -p #{pid}`.strip.to_i
        (memory_kb / 1024.0).round(2)
      rescue
        0
      end
      
      def memory_stats
        {
          current_usage_mb: current_memory_usage_mb,
          gc_stats: GC.stat,
          object_counts: ObjectSpace.count_objects,
          memory_profile: memory_profile
        }
      end
      
      def memory_profile
        return {} unless defined?(ObjectSpace)
        
        # Count objects by class
        counts = Hash.new(0)
        ObjectSpace.each_object do |obj|
          counts[obj.class] += 1
        end
        
        # Return top 10 object types by count
        counts.sort_by { |_, count| -count }.first(10).to_h
      rescue
        {}
      end
      
      def memory_cleanup
        # Force cleanup of common memory consumers
        cleanup_tasks = [
          -> { ActiveRecord::Base.clear_query_caches_for_current_thread },
          -> { Rails.cache.cleanup if Rails.cache.respond_to?(:cleanup) },
          -> { ActionView::Template.clear_cache if defined?(ActionView::Template) },
          -> { I18n.reload! if defined?(I18n) },
          -> { GC.start }
        ]
        
        cleanup_tasks.each do |task|
          begin
            task.call
          rescue => e
            Rails.logger.error "Memory cleanup task failed: #{e.message}"
          end
        end
        
        Rails.logger.info "[MEMORY_CLEANUP] Completed cleanup cycle"
      end
    end
  end
  
  # Memory-efficient string handling
  module StringOptimizations
    def self.freeze_strings!
      # Enable frozen string literals for better memory efficiency
      if RUBY_VERSION >= "2.3"
        String.class_eval do
          def self.new(*args)
            str = super(*args)
            str.freeze if str.ascii_only? && str.length < 100
            str
          end
        end
      end
    end
  end
  
  # Object pool for frequently created objects
  class ObjectPool
    def initialize(klass, initial_size: 10, max_size: 100)
      @klass = klass
      @pool = []
      @max_size = max_size
      @mutex = Mutex.new
      
      initial_size.times { @pool << create_object }
    end
    
    def borrow
      @mutex.synchronize do
        @pool.pop || create_object
      end
    end
    
    def return(obj)
      return unless obj.is_a?(@klass)
      
      @mutex.synchronize do
        if @pool.size < @max_size
          reset_object(obj)
          @pool.push(obj)
        end
      end
    end
    
    private
    
    def create_object
      @klass.new
    end
    
    def reset_object(obj)
      # Override in subclasses to reset object state
      obj.instance_variables.each do |var|
        obj.remove_instance_variable(var)
      end
    end
  end
  
  # Initialize memory monitoring on application startup
  Rails.application.config.after_initialize do
    MemoryMonitor.start_monitoring
    StringOptimizations.freeze_strings!
    
    Rails.logger.info "[MEMORY_OPTIMIZATION] Memory monitoring and optimizations initialized"
  end
  
  # Middleware to monitor request memory usage
  class MemoryProfilerMiddleware
    def initialize(app)
      @app = app
    end
    
    def call(env)
      return @app.call(env) unless should_profile?(env)
      
      start_memory = MemoryMonitor.current_memory_usage_mb
      gc_stat_before = GC.stat
      start_time = Time.current
      
      response = @app.call(env)
      
      end_memory = MemoryMonitor.current_memory_usage_mb
      gc_stat_after = GC.stat
      duration = ((Time.current - start_time) * 1000).round(2)
      
      memory_diff = end_memory - start_memory
      gc_count_diff = gc_stat_after[:count] - gc_stat_before[:count]
      
      if memory_diff > 10 || gc_count_diff > 0  # Log if significant memory change
        Rails.logger.info "[REQUEST_MEMORY] Path: #{env['PATH_INFO']}, " \
                         "Memory: #{start_memory}MB -> #{end_memory}MB (#{memory_diff > 0 ? '+' : ''}#{memory_diff}MB), " \
                         "GC: #{gc_count_diff} cycles, Duration: #{duration}ms"
      end
      
      response
    rescue => e
      Rails.logger.error "Memory profiler error: #{e.message}"
      response
    end
    
    private
    
    def should_profile?(env)
      # Only profile certain paths to avoid overhead
      path = env['PATH_INFO']
      path.start_with?('/documents', '/context_items', '/collaboration') ||
        env['HTTP_X_MEMORY_PROFILE'] == 'true'
    end
  end
  
  # Add memory profiler middleware
  Rails.application.config.middleware.insert_before(
    ActionDispatch::DebugExceptions,
    MemoryProfilerMiddleware
  )
end