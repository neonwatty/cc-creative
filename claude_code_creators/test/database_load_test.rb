#!/usr/bin/env ruby

# Database and Model-Level Load Testing Suite
# Tests database performance, caching, and concurrent operations

require_relative '../config/environment'
require 'benchmark'
require 'concurrent'

class DatabaseLoadTest
  attr_reader :results

  def initialize
    @results = {}
    Rails.cache.clear # Start with clean cache
    cleanup_test_data # Clean up any existing test data
  end

  def run_all_tests
    puts "🚀 Starting Database Load Testing Suite"
    puts "Environment: #{Rails.env}"
    puts "=" * 60

    # Core database performance tests
    test_user_creation_load
    test_document_creation_load
    test_context_item_operations_load
    test_search_performance_load
    test_concurrent_read_operations
    test_concurrent_write_operations
    test_database_transaction_load
    test_association_loading_performance
    test_caching_effectiveness
    test_memory_usage_patterns
    test_connection_pool_behavior
    test_index_performance

    generate_load_test_report
    cleanup_test_data
  end

  private

  def cleanup_test_data
    # Clean up test data to avoid interference
    User.where("email_address LIKE ?", "%loadtest%").destroy_all
    Document.where("title LIKE ?", "%Load Test%").destroy_all
    Rails.cache.clear
  end

  def test_user_creation_load
    puts "👤 Testing User Creation Load..."
    
    concurrent_threads = 20
    users_per_thread = 25
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_threads).map do |i|
        Thread.new do
          thread_results = []
          users_per_thread.times do |j|
            start_time = Time.now
            
            begin
              user = User.create!(
                name: "Load Test User #{i}-#{j}",
                email_address: "loadtest#{i}_#{j}@example.com",
                password: "loadtest123",
                role: 'user',
                email_confirmed: true
              )
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: user.persisted?,
                response_time: response_time,
                user_id: user.id
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_operations = concurrent_threads * users_per_thread
    successful_operations = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:user_creation_load] = {
      total_operations: total_operations,
      successful_operations: successful_operations,
      success_rate: (successful_operations.to_f / total_operations * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      operations_per_second: (total_operations / benchmark.real).round(2)
    }
    
    puts "  ✅ #{successful_operations}/#{total_operations} users created successfully"
    puts "  ⏱️  Average creation time: #{avg_response_time.round(2)}ms"
    puts "  🚀 Operations per second: #{(total_operations / benchmark.real).round(2)}"
  end

  def test_document_creation_load
    puts "📄 Testing Document Creation Load..."
    
    # Create test users first
    test_users = 10.times.map do |i|
      User.create!(
        name: "Doc Load User #{i}",
        email_address: "docload#{i}@example.com",
        password: "docload123",
        email_confirmed: true
      )
    end
    
    concurrent_threads = 15
    documents_per_thread = 20
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_threads).map do |i|
        Thread.new do
          thread_results = []
          user = test_users.sample
          
          documents_per_thread.times do |j|
            start_time = Time.now
            
            begin
              document = user.documents.create!(
                title: "Load Test Document #{i}-#{j}",
                description: "Created during database load testing",
                tags: ["load-test", "performance", "database"]
              )
              
              # Add content using ActionText
              document.content = "This is test content for load testing document #{i}-#{j}. " * 100
              document.save!
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: document.persisted?,
                response_time: response_time,
                document_id: document.id
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_operations = concurrent_threads * documents_per_thread
    successful_operations = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:document_creation_load] = {
      total_operations: total_operations,
      successful_operations: successful_operations,
      success_rate: (successful_operations.to_f / total_operations * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      operations_per_second: (total_operations / benchmark.real).round(2)
    }
    
    puts "  ✅ #{successful_operations}/#{total_operations} documents created successfully"
    puts "  ⏱️  Average creation time: #{avg_response_time.round(2)}ms"
    puts "  🚀 Operations per second: #{(total_operations / benchmark.real).round(2)}"
  end

  def test_context_item_operations_load
    puts "📝 Testing Context Item Operations Load..."
    
    # Get existing documents
    test_documents = Document.where("title LIKE ?", "%Load Test Document%").limit(10)
    
    if test_documents.empty?
      puts "  ⚠️  No test documents found, skipping context item tests"
      return
    end
    
    concurrent_threads = 20
    items_per_thread = 15
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_threads).map do |i|
        Thread.new do
          thread_results = []
          document = test_documents.sample
          user = document.user
          
          items_per_thread.times do |j|
            start_time = Time.now
            
            begin
              context_item = document.context_items.create!(
                title: "Load Test Context #{i}-#{j}",
                content: "Context content for load testing thread #{i}, item #{j}. " * 20,
                item_type: ["snippet", "draft", "saved_context", "file"].sample,
                user: user
              )
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: context_item.persisted?,
                response_time: response_time,
                context_item_id: context_item.id
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_operations = concurrent_threads * items_per_thread
    successful_operations = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:context_item_operations_load] = {
      total_operations: total_operations,
      successful_operations: successful_operations,
      success_rate: (successful_operations.to_f / total_operations * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      operations_per_second: (total_operations / benchmark.real).round(2)
    }
    
    puts "  ✅ #{successful_operations}/#{total_operations} context items created successfully"
    puts "  ⏱️  Average creation time: #{avg_response_time.round(2)}ms"
    puts "  🚀 Operations per second: #{(total_operations / benchmark.real).round(2)}"
  end

  def test_search_performance_load
    puts "🔍 Testing Search Performance Load..."
    
    search_queries = [
      "load test", "performance", "database", "content", "document",
      "context", "user", "testing", "benchmark", "concurrent"
    ]
    
    concurrent_threads = 25
    searches_per_thread = 20
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_threads).map do |i|
        Thread.new do
          thread_results = []
          
          searches_per_thread.times do |j|
            start_time = Time.now
            query = search_queries.sample
            
            begin
              # Test document search
              documents = Document.joins(:rich_text_content)
                                .where("action_text_rich_texts.body LIKE ? OR documents.title LIKE ?", 
                                       "%#{query}%", "%#{query}%")
                                .limit(10)
              
              # Test context item search
              context_items = ContextItem.search(query).limit(10)
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: true,
                response_time: response_time,
                query: query,
                documents_found: documents.count,
                context_items_found: context_items.count
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message,
                query: query
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_searches = concurrent_threads * searches_per_thread
    successful_searches = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:search_performance_load] = {
      total_searches: total_searches,
      successful_searches: successful_searches,
      success_rate: (successful_searches.to_f / total_searches * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      searches_per_second: (total_searches / benchmark.real).round(2)
    }
    
    puts "  ✅ #{successful_searches}/#{total_searches} searches completed successfully"
    puts "  ⏱️  Average search time: #{avg_response_time.round(2)}ms"
    puts "  🚀 Searches per second: #{(total_searches / benchmark.real).round(2)}"
  end

  def test_concurrent_read_operations
    puts "📖 Testing Concurrent Read Operations..."
    
    concurrent_readers = 30
    reads_per_reader = 50
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_readers).map do |i|
        Thread.new do
          thread_results = []
          
          reads_per_reader.times do |j|
            start_time = Time.now
            
            begin
              # Mix of different read operations
              case j % 4
              when 0
                # Read documents with associations
                docs = Document.includes(:user, :context_items).limit(5).to_a
                success = !docs.empty?
                
              when 1
                # Read context items with associations
                items = ContextItem.includes(:document, :user).limit(10).to_a
                success = true
                
              when 2
                # Read users with documents count
                users = User.joins(:documents).group('users.id').limit(5).to_a
                success = true
                
              when 3
                # Complex query with aggregations
                stats = Document.group(:user_id).count
                success = !stats.empty?
              end
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: success,
                response_time: response_time,
                operation_type: j % 4
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message,
                operation_type: j % 4
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_reads = concurrent_readers * reads_per_reader
    successful_reads = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:concurrent_read_operations] = {
      total_reads: total_reads,
      successful_reads: successful_reads,
      success_rate: (successful_reads.to_f / total_reads * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      reads_per_second: (total_reads / benchmark.real).round(2),
      concurrent_readers: concurrent_readers
    }
    
    puts "  ✅ #{successful_reads}/#{total_reads} read operations successful"
    puts "  ⏱️  Average read time: #{avg_response_time.round(2)}ms"
    puts "  👥 Concurrent readers: #{concurrent_readers}"
  end

  def test_concurrent_write_operations
    puts "✍️  Testing Concurrent Write Operations..."
    
    concurrent_writers = 15
    writes_per_writer = 20
    
    results = Concurrent::Array.new
    
    # Create test users for writers
    test_users = 15.times.map do |i|
      User.create!(
        name: "Writer User #{i}",
        email_address: "writer#{i}@example.com",
        password: "writer123",
        email_confirmed: true
      )
    end
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_writers).map do |i|
        Thread.new do
          thread_results = []
          user = test_users[i - 1]
          
          writes_per_writer.times do |j|
            start_time = Time.now
            
            begin
              # Mix of different write operations
              case j % 3
              when 0
                # Create document
                document = user.documents.create!(
                  title: "Writer Doc #{i}-#{j}",
                  description: "Created by writer #{i}",
                  tags: ["writer-test"]
                )
                success = document.persisted?
                
              when 1
                # Update existing document
                doc = user.documents.last
                if doc
                  doc.update!(description: "Updated by writer #{i} at #{Time.now}")
                  success = true
                else
                  success = true # No doc to update is ok
                end
                
              when 2
                # Create context item
                doc = user.documents.last || user.documents.create!(title: "Default", description: "Default")
                context = doc.context_items.create!(
                  title: "Writer Context #{i}-#{j}",
                  content: "Content from writer #{i}",
                  item_type: "snippet",
                  user: user
                )
                success = context.persisted?
              end
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: success,
                response_time: response_time,
                operation_type: j % 3,
                writer_id: i
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message,
                operation_type: j % 3,
                writer_id: i
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_writes = concurrent_writers * writes_per_writer
    successful_writes = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:concurrent_write_operations] = {
      total_writes: total_writes,
      successful_writes: successful_writes,
      success_rate: (successful_writes.to_f / total_writes * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      writes_per_second: (total_writes / benchmark.real).round(2),
      concurrent_writers: concurrent_writers
    }
    
    puts "  ✅ #{successful_writes}/#{total_writes} write operations successful"
    puts "  ⏱️  Average write time: #{avg_response_time.round(2)}ms"
    puts "  👥 Concurrent writers: #{concurrent_writers}"
  end

  def test_database_transaction_load
    puts "🔄 Testing Database Transaction Load..."
    
    concurrent_transactions = 20
    operations_per_transaction = 5
    
    results = Concurrent::Array.new
    
    # Create test user for transactions
    transaction_user = User.create!(
      name: "Transaction User",
      email_address: "transaction@example.com",
      password: "transaction123",
      email_confirmed: true
    )
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_transactions).map do |i|
        Thread.new do
          thread_results = []
          
          start_time = Time.now
          
          begin
            ActiveRecord::Base.transaction do
              # Create multiple related records in a transaction
              document = transaction_user.documents.create!(
                title: "Transaction Doc #{i}",
                description: "Created in transaction #{i}"
              )
              
              operations_per_transaction.times do |j|
                document.context_items.create!(
                  title: "Transaction Context #{i}-#{j}",
                  content: "Content in transaction",
                  item_type: "snippet",
                  user: transaction_user
                )
              end
              
              # Simulate some business logic
              document.update!(description: "Updated in transaction #{i}")
            end
            
            response_time = (Time.now - start_time) * 1000
            
            thread_results << {
              success: true,
              response_time: response_time,
              transaction_id: i
            }
          rescue => e
            thread_results << {
              success: false,
              response_time: (Time.now - start_time) * 1000,
              error: e.message,
              transaction_id: i
            }
          end
          
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    successful_transactions = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:database_transaction_load] = {
      total_transactions: concurrent_transactions,
      successful_transactions: successful_transactions,
      success_rate: (successful_transactions.to_f / concurrent_transactions * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      transactions_per_second: (concurrent_transactions / benchmark.real).round(2)
    }
    
    puts "  ✅ #{successful_transactions}/#{concurrent_transactions} transactions successful"
    puts "  ⏱️  Average transaction time: #{avg_response_time.round(2)}ms"
  end

  def test_association_loading_performance
    puts "🔗 Testing Association Loading Performance..."
    
    # Test N+1 prevention and eager loading
    concurrent_readers = 20
    queries_per_reader = 25
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_readers).map do |i|
        Thread.new do
          thread_results = []
          
          queries_per_reader.times do |j|
            start_time = Time.now
            
            begin
              case j % 4
              when 0
                # Test eager loading documents with users and context items
                docs = Document.includes(:user, :context_items).limit(5)
                docs.each { |doc| doc.user.name; doc.context_items.count }
                
              when 1
                # Test eager loading context items with documents and users
                items = ContextItem.includes(:document, :user).limit(10)
                items.each { |item| item.document.title; item.user.name }
                
              when 2
                # Test joins to avoid N+1
                users_with_docs = User.joins(:documents).select('users.*, COUNT(documents.id) as doc_count')
                                      .group('users.id').limit(5)
                users_with_docs.each { |user| user.doc_count }
                
              when 3
                # Test complex associations
                docs_with_context_count = Document.left_joins(:context_items)
                                                 .select('documents.*, COUNT(context_items.id) as context_count')
                                                 .group('documents.id').limit(5)
                docs_with_context_count.each { |doc| doc.context_count }
              end
              
              response_time = (Time.now - start_time) * 1000
              
              thread_results << {
                success: true,
                response_time: response_time,
                query_type: j % 4
              }
            rescue => e
              thread_results << {
                success: false,
                response_time: (Time.now - start_time) * 1000,
                error: e.message,
                query_type: j % 4
              }
            end
          end
          results.concat(thread_results)
        end
      end
      
      threads.each(&:join)
    end
    
    total_queries = concurrent_readers * queries_per_reader
    successful_queries = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:association_loading_performance] = {
      total_queries: total_queries,
      successful_queries: successful_queries,
      success_rate: (successful_queries.to_f / total_queries * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      queries_per_second: (total_queries / benchmark.real).round(2)
    }
    
    puts "  ✅ #{successful_queries}/#{total_queries} association queries successful"
    puts "  ⏱️  Average query time: #{avg_response_time.round(2)}ms"
  end

  def test_caching_effectiveness
    puts "🗄️  Testing Caching Effectiveness..."
    
    # Create test data for caching
    cache_user = User.create!(
      name: "Cache Test User",
      email_address: "cache@example.com",
      password: "cache123",
      email_confirmed: true
    )
    
    cache_document = cache_user.documents.create!(
      title: "Cache Test Document",
      description: "For cache testing"
    )
    
    cache_document.content = "Content for cache testing " * 200
    cache_document.save!
    
    # Test cache miss performance (first access)
    cache_miss_times = []
    10.times do
      Rails.cache.delete("document_#{cache_document.id}_word_count")
      Rails.cache.delete("document_#{cache_document.id}_search_content")
      
      start_time = Time.now
      cache_document.word_count
      cache_document.content_for_search
      cache_user.documents_summary
      cache_miss_times << (Time.now - start_time) * 1000
    end
    
    # Test cache hit performance (subsequent access)
    cache_hit_times = []
    10.times do
      start_time = Time.now
      cache_document.word_count
      cache_document.content_for_search
      cache_user.documents_summary
      cache_hit_times << (Time.now - start_time) * 1000
    end
    
    avg_miss_time = cache_miss_times.sum / cache_miss_times.size
    avg_hit_time = cache_hit_times.sum / cache_hit_times.size
    performance_improvement = ((avg_miss_time - avg_hit_time) / avg_miss_time * 100).round(2)
    
    @results[:caching_effectiveness] = {
      cache_miss_avg_time: avg_miss_time.round(2),
      cache_hit_avg_time: avg_hit_time.round(2),
      performance_improvement: performance_improvement,
      cache_working: performance_improvement > 10
    }
    
    puts "  ✅ Cache effectiveness test completed"
    puts "  ⏱️  Cache miss avg: #{avg_miss_time.round(2)}ms"
    puts "  ⚡ Cache hit avg: #{avg_hit_time.round(2)}ms"
    puts "  📈 Performance improvement: #{performance_improvement}%"
  end

  def test_memory_usage_patterns
    puts "🧠 Testing Memory Usage Patterns..."
    
    initial_memory = get_memory_usage
    
    # Create memory-intensive operations
    benchmark = Benchmark.measure do
      memory_user = User.create!(
        name: "Memory Test User",
        email_address: "memory@example.com",
        password: "memory123",
        email_confirmed: true
      )
      
      # Create large documents
      large_documents = 100.times.map do |i|
        doc = memory_user.documents.create!(
          title: "Large Document #{i}",
          description: "Memory testing document #{i}"
        )
        doc.content = "Large content for memory testing. " * 500
        doc.save!
        doc
      end
      
      # Perform memory-intensive operations
      large_documents.each do |doc|
        doc.word_count
        doc.content_for_search
        doc.reading_time
      end
      
      # Force garbage collection
      GC.start
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    @results[:memory_usage_patterns] = {
      initial_memory_mb: (initial_memory / 1024.0 / 1024.0).round(2),
      final_memory_mb: (final_memory / 1024.0 / 1024.0).round(2),
      memory_increase_mb: (memory_increase / 1024.0 / 1024.0).round(2),
      test_duration: benchmark.real.round(2),
      memory_efficient: memory_increase < 200 * 1024 * 1024 # Less than 200MB increase
    }
    
    puts "  ✅ Memory usage test completed"
    puts "  🧠 Memory increase: #{(memory_increase / 1024.0 / 1024.0).round(2)} MB"
    puts "  ⏱️  Test duration: #{benchmark.real.round(2)}s"
  end

  def test_connection_pool_behavior
    puts "🏊 Testing Connection Pool Behavior..."
    
    max_connections = ActiveRecord::Base.connection_pool.size
    concurrent_operations = max_connections * 2 # Exceed pool size
    
    results = Concurrent::Array.new
    
    benchmark = Benchmark.measure do
      threads = (1..concurrent_operations).map do |i|
        Thread.new do
          start_time = Time.now
          
          begin
            ActiveRecord::Base.connection_pool.with_connection do
              # Perform database operation
              User.count
              Document.count
              ContextItem.count
              
              # Hold connection briefly
              sleep(0.1)
            end
            
            response_time = (Time.now - start_time) * 1000
            
            results << {
              success: true,
              response_time: response_time,
              thread_id: i
            }
          rescue => e
            results << {
              success: false,
              response_time: (Time.now - start_time) * 1000,
              error: e.message,
              thread_id: i
            }
          end
        end
      end
      
      threads.each(&:join)
    end
    
    successful_operations = results.count { |r| r[:success] }
    avg_response_time = results.map { |r| r[:response_time] }.sum / results.size
    
    @results[:connection_pool_behavior] = {
      max_connections: max_connections,
      concurrent_operations: concurrent_operations,
      successful_operations: successful_operations,
      success_rate: (successful_operations.to_f / concurrent_operations * 100).round(2),
      avg_response_time: avg_response_time.round(2),
      total_duration: benchmark.real.round(2),
      pool_handling_effective: successful_operations >= concurrent_operations * 0.95
    }
    
    puts "  ✅ #{successful_operations}/#{concurrent_operations} operations successful"
    puts "  🏊 Connection pool size: #{max_connections}"
    puts "  ⏱️  Average response time: #{avg_response_time.round(2)}ms"
  end

  def test_index_performance
    puts "📊 Testing Index Performance..."
    
    # Test performance of indexed vs non-indexed queries
    indexed_queries = []
    non_indexed_queries = []
    
    # Test indexed queries (should be fast)
    10.times do
      start_time = Time.now
      User.where(email_address: "cache@example.com").first
      indexed_queries << (Time.now - start_time) * 1000
    end
    
    10.times do
      start_time = Time.now
      Document.where(user_id: 1).limit(5).to_a
      indexed_queries << (Time.now - start_time) * 1000
    end
    
    # Test potentially slower queries (searching in text fields)
    10.times do
      start_time = Time.now
      Document.where("title LIKE ?", "%Test%").limit(5).to_a
      non_indexed_queries << (Time.now - start_time) * 1000
    end
    
    10.times do
      start_time = Time.now
      ContextItem.where("content LIKE ?", "%testing%").limit(10).to_a
      non_indexed_queries << (Time.now - start_time) * 1000
    end
    
    avg_indexed_time = indexed_queries.sum / indexed_queries.size
    avg_non_indexed_time = non_indexed_queries.sum / non_indexed_queries.size
    
    @results[:index_performance] = {
      avg_indexed_query_time: avg_indexed_time.round(2),
      avg_non_indexed_query_time: avg_non_indexed_time.round(2),
      performance_ratio: (avg_non_indexed_time / avg_indexed_time).round(2),
      indexes_effective: avg_indexed_time < avg_non_indexed_time
    }
    
    puts "  ✅ Index performance test completed"
    puts "  ⚡ Avg indexed query time: #{avg_indexed_time.round(2)}ms"
    puts "  🐌 Avg non-indexed query time: #{avg_non_indexed_time.round(2)}ms"
    puts "  📊 Performance ratio: #{(avg_non_indexed_time / avg_indexed_time).round(2)}x"
  end

  def get_memory_usage
    # Simple memory usage check (returns in bytes)
    if RUBY_PLATFORM =~ /darwin/
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    else
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    end
  rescue
    0
  end

  def generate_load_test_report
    puts "\n" + "=" * 80
    puts "📊 DATABASE LOAD TEST REPORT"
    puts "=" * 80
    puts "Generated at: #{Time.now}"
    puts "Environment: #{Rails.env}"
    puts "Database: #{ActiveRecord::Base.connection_config[:adapter]}"
    puts

    @results.each do |test_name, results|
      puts "🔍 #{test_name.to_s.humanize}"
      puts "-" * 50
      
      results.each do |key, value|
        formatted_value = case value
                         when Float
                           value.round(2)
                         when TrueClass, FalseClass
                           value ? "✅ PASS" : "❌ FAIL"
                         else
                           value
                         end
        puts "  #{key.to_s.humanize}: #{formatted_value}"
      end
      puts
    end

    # Overall performance assessment
    puts "🎯 PERFORMANCE BENCHMARKS"
    puts "-" * 50
    
    benchmark_results = []
    
    # User creation performance
    if @results[:user_creation_load]
      user_ops = @results[:user_creation_load][:operations_per_second]
      benchmark_results << {
        name: "User Creation OPS",
        value: user_ops,
        target: 100,
        status: user_ops >= 100 ? "PASS" : "FAIL"
      }
    end
    
    # Document creation performance
    if @results[:document_creation_load]
      doc_ops = @results[:document_creation_load][:operations_per_second]
      benchmark_results << {
        name: "Document Creation OPS",
        value: doc_ops,
        target: 50,
        status: doc_ops >= 50 ? "PASS" : "FAIL"
      }
    end
    
    # Search performance
    if @results[:search_performance_load]
      search_ops = @results[:search_performance_load][:searches_per_second]
      benchmark_results << {
        name: "Search Performance SPS",
        value: search_ops,
        target: 100,
        status: search_ops >= 100 ? "PASS" : "FAIL"
      }
    end
    
    # Cache effectiveness
    if @results[:caching_effectiveness]
      cache_improvement = @results[:caching_effectiveness][:performance_improvement]
      benchmark_results << {
        name: "Cache Performance Improvement",
        value: "#{cache_improvement}%",
        target: "50%",
        status: cache_improvement >= 50 ? "PASS" : "FAIL"
      }
    end
    
    # Memory efficiency
    if @results[:memory_usage_patterns]
      memory_efficient = @results[:memory_usage_patterns][:memory_efficient]
      benchmark_results << {
        name: "Memory Efficiency",
        value: memory_efficient ? "Efficient" : "High Usage",
        target: "Efficient",
        status: memory_efficient ? "PASS" : "FAIL"
      }
    end
    
    benchmark_results.each do |benchmark|
      puts "  #{benchmark[:name]}: #{benchmark[:value]} (Target: #{benchmark[:target]})"
      puts "    #{benchmark[:status] == 'PASS' ? '✅ PASS' : '❌ FAIL'}"
    end
    
    # Summary
    passed_benchmarks = benchmark_results.count { |b| b[:status] == "PASS" }
    total_benchmarks = benchmark_results.count
    overall_score = (passed_benchmarks.to_f / total_benchmarks * 100).round(2) if total_benchmarks > 0
    
    puts "\n🏆 OVERALL SCORE"
    puts "-" * 50
    puts "  Passed Benchmarks: #{passed_benchmarks}/#{total_benchmarks}"
    puts "  Overall Score: #{overall_score}%"
    puts "  Status: #{overall_score && overall_score >= 70 ? '✅ PRODUCTION READY' : '⚠️  NEEDS OPTIMIZATION'}"

    puts "\n✨ Database load testing completed successfully!"
    puts "=" * 80
  end
end

# Main execution
if __FILE__ == $0
  puts "🚀 Starting Database Load Testing..."
  puts "This will test database performance, caching, and concurrent operations"
  puts

  load_test = DatabaseLoadTest.new
  load_test.run_all_tests
end