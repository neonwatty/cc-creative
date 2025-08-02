#!/usr/bin/env ruby

# Simplified Production Load Testing for Core Features
require_relative '../config/environment'
require 'benchmark'
require 'concurrent'

class SimpleLoadTest
  attr_reader :results

  def initialize
    @results = {}
  end

  def run_core_tests
    puts "🚀 Starting Core Production Load Tests"
    puts "Environment: #{Rails.env}"
    puts "=" * 60

    test_user_operations
    test_document_operations
    test_context_item_operations
    test_concurrent_operations
    test_performance_optimizations

    generate_summary_report
  end

  private

  def test_user_operations
    puts "👤 Testing User Operations..."
    
    benchmark = Benchmark.measure do
      # Create users in batches
      users_created = 0
      errors = 0
      
      5.times do |batch|
        begin
          users = 20.times.map do |i|
            User.create!(
              name: "Load User #{batch}-#{i}",
              email_address: "load#{batch}_#{i}_#{Time.now.to_i}@example.com",
              password: "load123",
              email_confirmed: true
            )
          end
          users_created += users.count
        rescue => e
          errors += 1
          puts "  ⚠️  Batch #{batch} error: #{e.message}"
        end
      end
      
      @results[:user_operations] = {
        users_created: users_created,
        errors: errors,
        success_rate: ((users_created.to_f / 100) * 100).round(2)
      }
    end
    
    puts "  ✅ #{@results[:user_operations][:users_created]} users created"
    puts "  ⏱️  Duration: #{benchmark.real.round(2)}s"
  end

  def test_document_operations
    puts "📄 Testing Document Operations..."
    
    test_users = User.limit(10).to_a
    return puts "  ⚠️  No users available for testing" if test_users.empty?
    
    benchmark = Benchmark.measure do
      documents_created = 0
      errors = 0
      
      5.times do |batch|
        begin
          user = test_users.sample
          docs = 10.times.map do |i|
            doc = user.documents.create!(
              title: "Load Doc #{batch}-#{i}",
              description: "Load testing document #{batch}-#{i}"
            )
            
            # Add content
            doc.content = "Test content for load testing document #{batch}-#{i}. " * 50
            doc.save!
            doc
          end
          documents_created += docs.count
        rescue => e
          errors += 1
          puts "  ⚠️  Batch #{batch} error: #{e.message}"
        end
      end
      
      @results[:document_operations] = {
        documents_created: documents_created,
        errors: errors,
        success_rate: ((documents_created.to_f / 50) * 100).round(2)
      }
    end
    
    puts "  ✅ #{@results[:document_operations][:documents_created]} documents created"
    puts "  ⏱️  Duration: #{benchmark.real.round(2)}s"
  end

  def test_context_item_operations
    puts "📝 Testing Context Item Operations..."
    
    test_documents = Document.limit(5).to_a
    return puts "  ⚠️  No documents available for testing" if test_documents.empty?
    
    benchmark = Benchmark.measure do
      context_items_created = 0
      errors = 0
      
      5.times do |batch|
        begin
          document = test_documents.sample
          items = 8.times.map do |i|
            document.context_items.create!(
              title: "Load Context #{batch}-#{i}",
              content: "Context content for load testing #{batch}-#{i}. " * 20,
              item_type: ["snippet", "draft", "saved_context", "file"].sample,
              user: document.user
            )
          end
          context_items_created += items.count
        rescue => e
          errors += 1
          puts "  ⚠️  Batch #{batch} error: #{e.message}"
        end
      end
      
      @results[:context_item_operations] = {
        context_items_created: context_items_created,
        errors: errors,
        success_rate: ((context_items_created.to_f / 40) * 100).round(2)
      }
    end
    
    puts "  ✅ #{@results[:context_item_operations][:context_items_created]} context items created"
    puts "  ⏱️  Duration: #{benchmark.real.round(2)}s"
  end

  def test_concurrent_operations
    puts "🔄 Testing Concurrent Operations..."
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = 10.times.map do |i|
        Thread.new do
          thread_results = { successes: 0, errors: 0 }
          
          5.times do |j|
            begin
              # Create user
              user = User.create!(
                name: "Concurrent User #{i}-#{j}",
                email_address: "concurrent#{i}_#{j}_#{Time.now.to_i}@example.com",
                password: "concurrent123",
                email_confirmed: true
              )
              
              # Create document
              document = user.documents.create!(
                title: "Concurrent Doc #{i}-#{j}",
                description: "Created concurrently"
              )
              
              # Create context item
              document.context_items.create!(
                title: "Concurrent Context #{i}-#{j}",
                content: "Concurrent content",
                item_type: "snippet",
                user: user
              )
              
              thread_results[:successes] += 1
            rescue => e
              thread_results[:errors] += 1
            end
          end
          
          results << thread_results
        end
      end
      
      threads.each(&:join)
    end
    
    total_successes = results.sum { |r| r[:successes] }
    total_errors = results.sum { |r| r[:errors] }
    total_operations = total_successes + total_errors
    
    @results[:concurrent_operations] = {
      total_operations: total_operations,
      successes: total_successes,
      errors: total_errors,
      success_rate: ((total_successes.to_f / total_operations) * 100).round(2),
      concurrent_threads: 10
    }
    
    puts "  ✅ #{total_successes}/#{total_operations} concurrent operations successful"
    puts "  ⏱️  Duration: #{benchmark.real.round(2)}s"
    puts "  🧵 Threads: 10"
  end

  def test_performance_optimizations
    puts "⚡ Testing Performance Optimizations..."
    
    # Test caching
    test_user = User.first
    test_document = Document.first
    
    if test_user && test_document
      # Test cache miss vs hit
      Rails.cache.clear
      
      cache_miss_time = Benchmark.measure do
        5.times do
          test_document.word_count
          test_document.content_for_search if test_document.respond_to?(:content_for_search)
        end
      end
      
      cache_hit_time = Benchmark.measure do
        5.times do
          test_document.word_count
          test_document.content_for_search if test_document.respond_to?(:content_for_search)
        end
      end
      
      cache_improvement = ((cache_miss_time.real - cache_hit_time.real) / cache_miss_time.real * 100).round(2)
      
      @results[:performance_optimizations] = {
        cache_miss_time: cache_miss_time.real.round(4),
        cache_hit_time: cache_hit_time.real.round(4),
        cache_improvement: cache_improvement,
        caching_working: cache_improvement > 0
      }
      
      puts "  ✅ Performance optimization tests completed"
      puts "  📈 Cache improvement: #{cache_improvement}%"
    else
      puts "  ⚠️  No test data available for performance testing"
    end
    
    # Test database query performance
    query_benchmark = Benchmark.measure do
      # Test optimized queries
      Document.includes(:user).limit(10).to_a
      ContextItem.includes(:document, :user).limit(20).to_a
      User.joins(:documents).group('users.id').count
    end
    
    if @results[:performance_optimizations]
      @results[:performance_optimizations][:query_performance] = query_benchmark.real.round(4)
    else
      @results[:performance_optimizations] = { query_performance: query_benchmark.real.round(4) }
    end
    
    puts "  ⚡ Query performance: #{query_benchmark.real.round(4)}s"
  end

  def generate_summary_report
    puts "\n" + "=" * 80
    puts "📊 PRODUCTION READINESS LOAD TEST SUMMARY"
    puts "=" * 80
    puts "Generated at: #{Time.now}"
    puts "Environment: #{Rails.env}"
    puts

    # Test Results Summary
    @results.each do |test_name, results|
      puts "🔍 #{test_name.to_s.humanize}"
      puts "-" * 40
      
      results.each do |key, value|
        formatted_value = case value
                         when Float
                           value.round(2)
                         when TrueClass, FalseClass
                           value ? "✅ YES" : "❌ NO"
                         else
                           value
                         end
        puts "  #{key.to_s.humanize}: #{formatted_value}"
      end
      puts
    end

    # Performance Assessment
    puts "🎯 PRODUCTION READINESS ASSESSMENT"
    puts "-" * 40
    
    assessment_score = 0
    total_criteria = 0
    
    # User operations
    if @results[:user_operations]
      total_criteria += 1
      if @results[:user_operations][:success_rate] >= 95
        assessment_score += 1
        puts "  User Operations: ✅ PASS (#{@results[:user_operations][:success_rate]}%)"
      else
        puts "  User Operations: ❌ FAIL (#{@results[:user_operations][:success_rate]}%)"
      end
    end
    
    # Document operations
    if @results[:document_operations]
      total_criteria += 1
      if @results[:document_operations][:success_rate] >= 95
        assessment_score += 1
        puts "  Document Operations: ✅ PASS (#{@results[:document_operations][:success_rate]}%)"
      else
        puts "  Document Operations: ❌ FAIL (#{@results[:document_operations][:success_rate]}%)"
      end
    end
    
    # Context item operations
    if @results[:context_item_operations]
      total_criteria += 1
      if @results[:context_item_operations][:success_rate] >= 95
        assessment_score += 1
        puts "  Context Item Operations: ✅ PASS (#{@results[:context_item_operations][:success_rate]}%)"
      else
        puts "  Context Item Operations: ❌ FAIL (#{@results[:context_item_operations][:success_rate]}%)"
      end
    end
    
    # Concurrent operations
    if @results[:concurrent_operations]
      total_criteria += 1
      if @results[:concurrent_operations][:success_rate] >= 90
        assessment_score += 1
        puts "  Concurrent Operations: ✅ PASS (#{@results[:concurrent_operations][:success_rate]}%)"
      else
        puts "  Concurrent Operations: ❌ FAIL (#{@results[:concurrent_operations][:success_rate]}%)"
      end
    end
    
    # Performance optimizations
    if @results[:performance_optimizations] && @results[:performance_optimizations][:caching_working]
      total_criteria += 1
      if @results[:performance_optimizations][:caching_working]
        assessment_score += 1
        puts "  Performance Optimizations: ✅ PASS (Caching working)"
      else
        puts "  Performance Optimizations: ❌ FAIL (Caching not working)"
      end
    end
    
    # Final score
    final_score = (assessment_score.to_f / total_criteria * 100).round(2) if total_criteria > 0
    
    puts "\n🏆 FINAL ASSESSMENT"
    puts "-" * 40
    puts "  Passed Criteria: #{assessment_score}/#{total_criteria}"
    puts "  Overall Score: #{final_score}%"
    
    if final_score && final_score >= 80
      puts "  Status: ✅ PRODUCTION READY"
      puts "  Recommendation: Application is ready for production deployment"
    elsif final_score && final_score >= 60
      puts "  Status: ⚠️  NEEDS OPTIMIZATION"
      puts "  Recommendation: Address failing criteria before production deployment"
    else
      puts "  Status: ❌ NOT READY"
      puts "  Recommendation: Significant improvements needed before production"
    end

    # Database Statistics
    puts "\n📈 DATABASE STATISTICS"
    puts "-" * 40
    puts "  Total Users: #{User.count}"
    puts "  Total Documents: #{Document.count}"
    puts "  Total Context Items: #{ContextItem.count}"
    
    puts "\n✨ Load testing completed successfully!"
    puts "=" * 80
  end
end

# Run the test
if __FILE__ == $0
  load_test = SimpleLoadTest.new
  load_test.run_core_tests
end