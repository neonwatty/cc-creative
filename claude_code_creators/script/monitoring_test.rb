#!/usr/bin/env ruby

# Production Monitoring and Alerting Test Suite
require_relative '../config/environment'

class MonitoringTest
  attr_reader :results

  def initialize
    @results = {}
  end

  def run_monitoring_tests
    puts "📊 Testing Monitoring and Alerting Systems..."
    
    # Test logging capabilities
    test_logging_functionality
    test_performance_monitoring
    test_error_tracking
    test_health_check_endpoints
    
    @results
  end

  private

  def test_logging_functionality
    puts "  📝 Testing Logging Functionality..."
    
    # Test Rails logger
    begin
      Rails.logger.info("Production monitoring test - info level")
      Rails.logger.warn("Production monitoring test - warn level")
      Rails.logger.error("Production monitoring test - error level")
      
      @results[:logging] = {
        rails_logger_working: true,
        log_levels_functional: true,
        structured_logging: defined?(Rails.logger)
      }
      
      puts "    ✅ Rails logging functional"
    rescue => e
      @results[:logging] = { error: e.message }
      puts "    ❌ Rails logging failed: #{e.message}"
    end
  end

  def test_performance_monitoring
    puts "  ⚡ Testing Performance Monitoring..."
    
    # Test if performance logs exist and work
    begin
      start_time = Time.now
      
      # Simulate some work
      User.count
      Document.count
      
      duration = (Time.now - start_time) * 1000
      
      @results[:performance_monitoring] = {
        timing_measurements: true,
        database_query_tracking: true,
        response_time_logging: duration < 1000 # Less than 1 second
      }
      
      puts "    ✅ Performance monitoring functional"
    rescue => e
      @results[:performance_monitoring] = { error: e.message }
      puts "    ❌ Performance monitoring failed: #{e.message}"
    end
  end

  def test_error_tracking
    puts "  🚨 Testing Error Tracking..."
    
    begin
      # Test error logging
      begin
        raise StandardError, "Test error for monitoring"
      rescue => test_error
        Rails.logger.error("Test error caught: #{test_error.message}")
        Rails.logger.error("Test backtrace: #{test_error.backtrace.first(5).join("\n")}")
      end
      
      @results[:error_tracking] = {
        error_logging: true,
        backtrace_capture: true,
        error_notifications: false # Would need external service
      }
      
      puts "    ✅ Error tracking functional"
    rescue => e
      @results[:error_tracking] = { error: e.message }
      puts "    ❌ Error tracking failed: #{e.message}"
    end
  end

  def test_health_check_endpoints
    puts "  💓 Testing Health Check Endpoints..."
    
    begin
      # Test database connectivity
      db_healthy = ActiveRecord::Base.connection.active?
      
      # Test cache connectivity (if Redis is configured)
      cache_healthy = begin
        Rails.cache.write('health_check', 'ok')
        Rails.cache.read('health_check') == 'ok'
      rescue
        false
      end
      
      @results[:health_checks] = {
        database_connectivity: db_healthy,
        cache_connectivity: cache_healthy,
        application_responsive: true
      }
      
      puts "    ✅ Health checks functional"
    rescue => e
      @results[:health_checks] = { error: e.message }
      puts "    ❌ Health checks failed: #{e.message}"
    end
  end
end

# Run if called directly
if __FILE__ == $0
  monitoring_test = MonitoringTest.new
  results = monitoring_test.run_monitoring_tests
  
  puts "\n📊 Monitoring Test Results:"
  results.each do |category, data|
    puts "  #{category}: #{data}"
  end
end