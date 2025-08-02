class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Performance optimizations for production
  class << self
    # Efficient bulk operations
    def bulk_insert(records_array, batch_size: 1000)
      return [] if records_array.empty?
      
      records_array.each_slice(batch_size) do |batch|
        insert_all(batch, validate: false, returning: false)
      end
    end

    def bulk_update(updates_hash, conditions = {})
      return 0 if updates_hash.empty?
      
      where(conditions).update_all(updates_hash)
    end

    # Optimized pagination with cursor-based pagination for large datasets
    def cursor_paginate(cursor: nil, limit: 100, order_by: :id, direction: :asc)
      query = all
      
      if cursor.present?
        operator = direction == :asc ? ">" : "<"
        query = query.where("#{order_by} #{operator} ?", cursor)
      end
      
      query.order(order_by => direction).limit(limit)
    end

    # Memory-efficient iteration over large datasets
    def find_each_optimized(batch_size: 1000)
      find_in_batches(batch_size: batch_size) do |batch|
        batch.each { |record| yield(record) }
        GC.start if batch_size > 500  # Force GC for large batches
      end
    end

    # Database connection health check
    def connection_healthy?
      connection.execute("SELECT 1").present?
    rescue ActiveRecord::StatementInvalid
      false
    end

    # Query performance monitoring
    def with_query_monitoring(operation_name)
      start_time = Time.current
      result = yield
      duration_ms = ((Time.current - start_time) * 1000).round(2)
      
      if duration_ms > 100  # Log slow queries
        Rails.logger.warn "[SLOW_QUERY] #{operation_name}: #{duration_ms}ms"
        
        # Log to performance tracking if available
        if defined?(PerformanceLog)
          PerformanceLog.create!(
            operation: "query_#{operation_name}",
            duration_ms: duration_ms,
            occurred_at: start_time,
            environment: Rails.env,
            metadata: { model: name, slow_query: true }
          )
        end
      end
      
      result
    end
  end

  # Instance methods for performance
  def touch_optimized(*attributes)
    # Batch touch operations to reduce database calls
    current_time = Time.current
    updates = { updated_at: current_time }
    
    attributes.each do |attr|
      updates["#{attr}_at"] = current_time if self.class.column_names.include?("#{attr}_at")
    end
    
    self.class.where(id: id).update_all(updates)
  end

  # Efficient attribute updates without callbacks when needed
  def update_columns_optimized(attributes)
    self.class.where(id: id).update_all(attributes)
    attributes.each { |attr, value| write_attribute(attr, value) }
    clear_attribute_changes(attributes.keys)
  end

  # Memory-efficient JSON serialization
  def to_json_optimized(options = {})
    only_attrs = options[:only] || self.class.column_names
    attributes.slice(*only_attrs.map(&:to_s)).to_json
  end

  private

  def clear_attribute_changes(attributes)
    attributes.each { |attr| clear_attribute_change(attr) }
  end
end
