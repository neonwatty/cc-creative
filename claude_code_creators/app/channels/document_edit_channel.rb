# frozen_string_literal: true

class DocumentEditChannel < ApplicationCable::Channel
  def subscribed
    @document = find_document
    return reject unless @document && authorized_for_document?(@document)

    # Performance optimization: batch operations
    @user_id = current_user.id
    @document_id = @document.id

    stream_for @document

    # Batch Redis operations for performance
    if Redis.current
      Redis.current.pipelined do |redis|
        # Add user to document editing session
        add_user_to_editing_session_batched(@document, redis)

        # Update presence data
        update_editing_presence_batched(@document, "editing", redis)
      end
    else
      # Fallback to individual operations without Redis
      add_user_to_editing_session(@document)
      update_editing_presence(@document, "editing")
    end

    # Broadcast user joined editing (async to reduce latency)
    ActionCable.server.broadcast(
      "document_edit_#{@document_id}",
      {
        type: "user_joined_editing",
        user: serialize_user_minimal(current_user),
        timestamp: Time.current.to_f  # Use float for better performance
      }
    )

    logger.info "User #{@user_id} subscribed to DocumentEditChannel for document #{@document_id}"
  end

  def unsubscribed
    return unless @document

    # Remove user from editing session
    remove_user_from_editing_session(@document)

    # Broadcast user left editing
    broadcast_editing_event("user_left_editing", {
      user_id: current_user.id,
      timestamp: Time.current.iso8601
    })

    # Update presence to indicate no longer editing
    update_editing_presence(@document, "viewing")

    logger.info "User #{current_user.id} unsubscribed from DocumentEditChannel for document #{@document.id}"
  end

  # Real-time Editing Operations with optimizations
  def edit_operation(data = {})
    return unless @document && authorized_for_document?(@document)

    # Performance: early validation before expensive operations
    return transmit_error("Invalid operation data") unless data.is_a?(Hash)

    begin
      operation = prepare_operation(data)
      validate_operation!(operation)

      # Performance optimization: use cached service instance
      service = operational_transform_service

      # Process operation with performance monitoring
      result = measure_operation_performance("edit_operation") do
        service.apply_and_broadcast_operation(@document, operation)
      end

      case result[:status]
      when "success"
        # Update user activity
        update_editing_activity(@document)

        # Broadcast successful operation to other users
        broadcast_editing_event("operation_applied", {
          operation: result[:transformed_operation],
          operation_id: result[:transformed_operation][:operation_id],
          user_id: current_user.id,
          user_name: current_user.name,
          timestamp: operation[:timestamp]
        }, except: current_user)

        # Send confirmation to sender
        transmit({
          type: "operation_confirmed",
          operation_id: result[:transformed_operation][:operation_id],
          status: "applied"
        })

      when "conflict_resolved"
        # Update user activity
        update_editing_activity(@document)

        # Broadcast conflict resolution to other users
        broadcast_editing_event("operation_applied", {
          operation: result[:transformed_operation],
          operation_id: result[:transformed_operation][:operation_id],
          user_id: current_user.id,
          user_name: current_user.name,
          conflicts: result[:conflicts],
          resolution_strategy: result[:resolution_strategy],
          timestamp: operation[:timestamp]
        }, except: current_user)

        # Send detailed conflict resolution to sender
        transmit({
          type: "operation_confirmed",
          operation_id: result[:transformed_operation][:operation_id],
          status: "conflict_resolved",
          conflicts: result[:conflicts],
          resolution_strategy: result[:resolution_strategy],
          message: "Operation applied after resolving conflicts"
        })

      else
        # Send error to sender
        transmit({
          type: "operation_error",
          error: result[:error],
          operation: operation
        })
      end

      # Check if document version should be created
      if result[:version_created]
        broadcast_editing_event("version_created", {
          version_number: @document.current_version_number,
          created_by: current_user.id,
          auto_created: true
        })
      end

    rescue OperationalTransformService::InvalidOperationError => e
      transmit({
        type: "operation_error",
        error: "Invalid operation: #{e.message}",
        operation: data
      })
    rescue StandardError => e
      logger.error "Error processing edit operation: #{e.message}"
      logger.error e.backtrace.join("\n")

      transmit({
        type: "service_error",
        error: "Service temporarily unavailable: #{e.message}"
      })
    end
  end

  # Optimized Batch Operations
  def batch_operations(data = {})
    return unless @document && authorized_for_document?(@document)

    operations = data["operations"] || []
    return transmit_error("No operations provided") if operations.empty?
    return transmit_error("Too many operations") if operations.size > 50  # Limit batch size

    begin
      # Performance: validate batch size before processing
      total_content_size = operations.sum { |op| (op["content"] || "").length }
      return transmit_error("Batch content too large") if total_content_size > 10_000

      # Prepare all operations with early exit on errors
      prepared_operations = []
      operations.each_with_index do |op, index|
        prepared_op = prepare_operation(op)
        validate_operation!(prepared_op)
        prepared_operations << prepared_op
      rescue => e
        return transmit_error("Operation #{index} invalid: #{e.message}")
      end

      # Process batch with performance monitoring
      service = operational_transform_service
      result = measure_operation_performance("batch_operations") do
        service.apply_operations_batch(@document, prepared_operations)
      end

      case result[:status]
      when "batch_success"
        update_editing_activity(@document)

        # Broadcast batch to other users
        broadcast_editing_event("batch_operations_applied", {
          operations: result[:applied_operations],
          user_id: current_user.id,
          user_name: current_user.name,
          timestamp: Time.current.to_f
        }, except: current_user)

        # Confirm to sender
        transmit({
          type: "batch_confirmed",
          applied_operations: result[:applied_operations],
          final_content: result[:final_content]
        })

      else
        transmit({
          type: "batch_error",
          error: result[:error],
          failed_operation_index: result[:failed_at_operation]
        })
      end

    rescue StandardError => e
      logger.error "Error processing batch operations: #{e.message}"
      transmit({
        type: "batch_error",
        error: e.message
      })
    end
  end

  # Cursor and Selection Synchronization
  def cursor_moved(data = {})
    return unless @document && authorized_for_document?(@document)

    position = data["position"] || {}
    selection = data["selection"] || {}

    # Store cursor position for persistence
    store_cursor_position(@document, position)

    # Broadcast to other users
    broadcast_editing_event("cursor_moved", {
      user_id: current_user.id,
      user_name: current_user.name,
      position: position,
      selection: selection,
      timestamp: Time.current.iso8601
    }, except: current_user)
  end

  def selection_changed(data = {})
    return unless @document && authorized_for_document?(@document)

    selection = data["selection"] || {}

    # Broadcast selection to other users
    broadcast_editing_event("selection_changed", {
      user_id: current_user.id,
      user_name: current_user.name,
      selection: selection,
      timestamp: Time.current.iso8601
    }, except: current_user)
  end

  # Cursor Transformation for Concurrent Edits
  def transform_cursor(data = {})
    return unless @document && authorized_for_document?(@document)

    operation = data["operation"]
    cursor_position = data["cursor_position"]

    return unless operation && cursor_position

    begin
      service = OperationalTransformService.new
      new_position = service.transform_cursor_position(cursor_position, operation)

      # Broadcast transformed cursor position
      broadcast_editing_event("cursor_transformed", {
        user_id: current_user.id,
        old_position: cursor_position,
        new_position: new_position,
        operation: operation,
        timestamp: Time.current.iso8601
      }, except: current_user)

      # Send updated position to sender
      transmit({
        type: "cursor_position_updated",
        new_position: new_position,
        operation: operation
      })

    rescue StandardError => e
      logger.error "Error transforming cursor position: #{e.message}"
      transmit({
        type: "cursor_transform_error",
        error: e.message
      })
    end
  end

  # Document State Synchronization
  def request_sync(data = {})
    return unless @document && authorized_for_document?(@document)

    begin
      client_state_hash = data["client_state_hash"]

      # Get current document content and generate hash
      current_content = get_document_content(@document)
      server_state_hash = generate_content_hash(current_content)

      if client_state_hash == server_state_hash
        # Client is in sync
        transmit({
          type: "sync_confirmed",
          state_hash: server_state_hash,
          timestamp: Time.current.iso8601
        })
      else
        # Client needs update
        transmit({
          type: "document_sync",
          content: current_content,
          state_hash: server_state_hash,
          version: @document.current_version_number,
          timestamp: Time.current.iso8601,
          active_operations: get_pending_operations(@document.id)
        })
      end

    rescue StandardError => e
      logger.error "Error processing sync request: #{e.message}"
      transmit({
        type: "sync_error",
        error: e.message
      })
    end
  end

  # Conflict Resolution UI
  def resolve_conflict(data = {})
    return unless @document && authorized_for_document?(@document)

    conflict_id = data["conflict_id"]
    resolution = data["resolution"]

    unless conflict_id && resolution
      transmit({ type: "error", error: "Conflict ID and resolution required" })
      return
    end

    begin
      # Process conflict resolution
      service = OperationalTransformService.new
      result = service.resolve_conflict_manually(@document.id, {
        conflict_id: conflict_id,
        resolution_strategy: resolution["strategy"],
        resolved_content: resolution["content"],
        resolved_by: current_user.id
      })

      if result[:success]
        # Broadcast resolution to all users
        broadcast_editing_event("conflict_resolved", {
          conflict_id: conflict_id,
          resolved_by: current_user.id,
          resolution_strategy: resolution["strategy"],
          final_content: result[:final_content],
          timestamp: Time.current.iso8601
        })

        transmit({
          type: "conflict_resolution_confirmed",
          conflict_id: conflict_id,
          final_content: result[:final_content]
        })
      else
        transmit({
          type: "conflict_resolution_error",
          error: result[:error]
        })
      end

    rescue StandardError => e
      logger.error "Error resolving conflict: #{e.message}"
      transmit({
        type: "conflict_resolution_error",
        error: e.message
      })
    end
  end

  # Document Version Integration
  def create_version(data = {})
    return unless @document && authorized_for_document?(@document)

    version_data = data["version_data"] || {}

    begin
      version = @document.create_version!(
        created_by_user: current_user,
        version_name: version_data["name"],
        version_notes: version_data["notes"] || "Manual version created during collaboration",
        is_auto_version: false
      )

      # Broadcast version creation
      broadcast_editing_event("version_created", {
        version_number: version.version_number,
        version_name: version.version_name,
        created_by: current_user.id,
        created_by_name: current_user.name,
        timestamp: Time.current.iso8601
      })

      transmit({
        type: "version_created",
        version: {
          number: version.version_number,
          name: version.version_name,
          notes: version.version_notes
        }
      })

    rescue StandardError => e
      logger.error "Error creating version: #{e.message}"
      transmit({
        type: "version_creation_error",
        error: e.message
      })
    end
  end

  private

  def find_document
    document_id = params[:document_id]
    return nil unless document_id

    @document ||= Document.find_by(id: document_id)
  end

  def authorized_for_document?(document)
    # Use Pundit policy or similar authorization
    document.user == current_user || current_user.admin?
  rescue StandardError
    false
  end

  def prepare_operation(data)
    {
      type: data["type"],
      position: data["position"].to_i,
      length: data["length"]&.to_i,
      content: data["content"],
      user_id: current_user.id,
      timestamp: data["timestamp"]&.to_f || Time.current.to_f
    }
  end

  def validate_operation!(operation)
    raise OperationalTransformService::InvalidOperationError, "Invalid operation type" unless %w[insert delete replace].include?(operation[:type])
    raise OperationalTransformService::InvalidOperationError, "Position must be non-negative" unless operation[:position] >= 0

    case operation[:type]
    when "delete", "replace"
      raise OperationalTransformService::InvalidOperationError, "Length required for #{operation[:type]}" unless operation[:length] && operation[:length] > 0
    when "insert", "replace"
      raise OperationalTransformService::InvalidOperationError, "Content required for #{operation[:type]}" unless operation[:content]
    end
  end

  # Performance helper methods
  def operational_transform_service
    @operational_transform_service ||= OperationalTransformService.new
  end

  def measure_operation_performance(operation_name)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

    # Log slow operations
    if duration_ms > 50  # Log operations slower than 50ms
      Rails.logger.warn "[SLOW_CABLE_OP] #{operation_name}: #{duration_ms}ms for document #{@document_id}"
    end

    # Track performance metrics
    if defined?(PerformanceLog) && duration_ms > 10
      PerformanceLog.create!(
        operation: "cable_#{operation_name}",
        duration_ms: duration_ms,
        occurred_at: Time.current,
        environment: Rails.env,
        metadata: {
          document_id: @document_id,
          user_id: @user_id,
          channel: "DocumentEditChannel"
        }
      )
    end

    result
  end

  def transmit_error(message)
    transmit({
      type: "error",
      error: message,
      timestamp: Time.current.to_f
    })
  end

  def serialize_user_minimal(user)
    {
      id: user.id,
      name: user.name
    }
  end

  # Optimized User Session Management
  def add_user_to_editing_session_batched(document, redis = nil)
    editing_key = "document_#{document.id}_editing_users"
    user_data = {
      id: current_user.id,
      name: current_user.name,
      joined_at: Time.current.to_f,
      last_activity: Time.current.to_f
    }

    if redis
      redis.hset(editing_key, current_user.id, user_data.to_json)
      redis.expire(editing_key, 3600)  # 1 hour
    else
      users = Rails.cache.read(editing_key) || {}
      users[current_user.id] = user_data
      Rails.cache.write(editing_key, users, expires_in: 1.hour)
    end
  end

  def add_user_to_editing_session(document)
    add_user_to_editing_session_batched(document)
  end

  def remove_user_from_editing_session(document)
    editing_key = "document_#{document.id}_editing_users"
    users = Rails.cache.read(editing_key) || {}
    users.delete(current_user.id)
    Rails.cache.write(editing_key, users, expires_in: 1.hour)
  end

  def update_editing_activity(document)
    editing_key = "document_#{document.id}_editing_users"
    users = Rails.cache.read(editing_key) || {}
    if users[current_user.id]
      users[current_user.id][:last_activity] = Time.current.iso8601
      Rails.cache.write(editing_key, users, expires_in: 1.hour)
    end

    # Also update presence channel
    update_editing_presence(document, "editing")
  end

  def update_editing_presence_batched(document, activity, redis = nil)
    presence_key = "document_#{document.id}_presence_#{current_user.id}"
    presence_data = {
      user_id: current_user.id,
      user_name: current_user.name,
      activity: activity,
      timestamp: Time.current.to_f
    }

    if redis
      redis.setex(presence_key, 600, presence_data.to_json)  # 10 minutes
    else
      Rails.cache.write(presence_key, presence_data, expires_in: 10.minutes)
    end
  end

  def update_editing_presence(document, activity)
    update_editing_presence_batched(document, activity)

    # Broadcast presence update asynchronously
    ActionCable.server.broadcast(
      "presence_#{document.id}",
      {
        type: "user_editing",
        user_id: current_user.id,
        user_name: current_user.name,
        activity: activity,
        timestamp: Time.current.to_f
      }
    )
  end

  # Cursor Management
  def store_cursor_position(document, position)
    cursor_key = "document_#{document.id}_cursor_#{current_user.id}"
    cursor_data = {
      user_id: current_user.id,
      position: position,
      updated_at: Time.current.iso8601
    }
    Rails.cache.write(cursor_key, cursor_data, expires_in: 10.minutes)
  end

  # Document Content Helpers
  def get_document_content(document)
    # Get content from document or latest version
    document.content || ""
  end

  def generate_content_hash(content)
    Digest::MD5.hexdigest(content || "")
  end

  def get_pending_operations(document_id)
    OperationalTransform.for_document(document_id)
                       .pending
                       .order(:timestamp)
                       .limit(50)
                       .map(&:to_operation_hash)
  end

  # Broadcasting Helpers
  def broadcast_editing_event(event_type, data = {}, options = {})
    excluded_users = Array(options[:except])

    DocumentEditChannel.broadcast_to(@document, {
      type: event_type,
      document_id: @document.id,
      timestamp: Time.current.iso8601,
      **data
    })

    # Note: ActionCable doesn't have built-in user exclusion,
    # so filtering needs to be handled on the client side
  end

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email_address,
      role: user.role
    }
  end
end
