# frozen_string_literal: true

class OperationalTransformService
  class InvalidOperationError < StandardError; end
  class ConflictResolutionError < StandardError; end

  VALID_OPERATION_TYPES = %w[insert delete replace].freeze
  VALID_CONFLICT_STRATEGIES = %w[timestamp_priority user_priority last_writer_wins].freeze

  def initialize
    @operation_queues = {}
    @expected_state = {}
    @user_priorities = { "admin" => 3, "editor" => 2, "user" => 1 }.freeze
  end

  # Core Operation Application
  def apply_operation(content, operation)
    validate_operation!(operation)

    case operation[:type]
    when "insert"
      apply_insert_operation(content, operation)
    when "delete"
      apply_delete_operation(content, operation)
    when "replace"
      apply_replace_operation(content, operation)
    else
      raise InvalidOperationError, "Unknown operation type: #{operation[:type]}"
    end
  end

  # Operation Transformation
  def transform_operation(base_operation, target_operation)
    validate_operation!(base_operation)
    validate_operation!(target_operation)

    case [ base_operation[:type], target_operation[:type] ]
    when [ "insert", "insert" ]
      transform_insert_insert(base_operation, target_operation)
    when [ "insert", "delete" ]
      transform_insert_delete(base_operation, target_operation)
    when [ "delete", "insert" ]
      transform_delete_insert(base_operation, target_operation)
    when [ "delete", "delete" ]
      transform_delete_delete(base_operation, target_operation)
    when [ "insert", "replace" ], [ "replace", "insert" ]
      transform_insert_replace(base_operation, target_operation)
    when [ "delete", "replace" ], [ "replace", "delete" ]
      transform_delete_replace(base_operation, target_operation)
    when [ "replace", "replace" ]
      transform_replace_replace(base_operation, target_operation)
    else
      target_operation.dup
    end
  end

  # Cursor Position Transformation
  def transform_cursor_position(cursor_position, operation)
    case operation[:type]
    when "insert"
      if cursor_position >= operation[:position]
        cursor_position + operation[:content].length
      else
        cursor_position
      end
    when "delete"
      delete_start = operation[:position]
      delete_end = delete_start + operation[:length]

      if cursor_position <= delete_start
        cursor_position
      elsif cursor_position >= delete_end
        cursor_position - operation[:length]
      else
        # Cursor is within deleted range, clamp to start
        delete_start
      end
    when "replace"
      replace_start = operation[:position]
      replace_end = replace_start + operation[:length]
      content_length_diff = operation[:content].length - operation[:length]

      if cursor_position <= replace_start
        cursor_position
      elsif cursor_position >= replace_end
        cursor_position + content_length_diff
      else
        # Cursor is within replaced range, position at end of replacement
        replace_start + operation[:content].length
      end
    else
      cursor_position
    end
  end

  # Operation Queue Management
  def queue_operation(document_id, operation)
    @operation_queues[document_id] ||= []
    operation[:operation_id] = generate_operation_id
    @operation_queues[document_id] << operation
  end

  def get_queued_operations(document_id)
    @operation_queues[document_id] || []
  end

  def get_sorted_operations(document_id)
    operations = get_queued_operations(document_id)
    operations.sort_by { |op| op[:timestamp] }
  end

  # Batch Operation Processing
  def apply_operations_sequence(content, operations)
    sorted_operations = operations.sort_by { |op| op[:timestamp] }

    sorted_operations.reduce(content) do |current_content, operation|
      apply_operation(current_content, operation)
    end
  end

  def apply_operations_batch(document, operations)
    return { status: "error", error: "No operations provided" } if operations.empty?

    begin
      # Sort operations by timestamp
      sorted_operations = operations.sort_by { |op| op[:timestamp] }

      # Transform operations if needed
      transformed_operations = []
      sorted_operations.each_with_index do |operation, index|
        transformed_op = operation.dup

        # Transform against all previous operations in the batch
        transformed_operations.each do |prev_op|
          transformed_op = transform_operation(prev_op, transformed_op)
        end

        transformed_operations << transformed_op
      end

      # Apply all operations to document content
      current_content = document.content || ""
      final_content = apply_operations_sequence(current_content, transformed_operations)

      # Update document
      document.update!(content: final_content)

      # Store operations in database
      transformed_operations.each do |op|
        store_operation_record(document.id, op)
      end

      {
        status: "batch_success",
        applied_operations: transformed_operations,
        final_content: final_content
      }
    rescue StandardError => e
      {
        status: "batch_error",
        error: e.message,
        failed_at_operation: operations.find_index { |op| op == operation }
      }
    end
  end

  # State Consistency Verification
  def verify_state_consistency(document_id, actual_content)
    expected_content = @expected_state[document_id]
    return true unless expected_content

    expected_content == actual_content
  end

  # Conflict Resolution
  def resolve_conflict(operation_1, operation_2, strategy: :timestamp_priority)
    case strategy
    when :timestamp_priority
      resolve_by_timestamp(operation_1, operation_2)
    when :user_priority
      resolve_by_user_priority(operation_1, operation_2)
    when :last_writer_wins
      resolve_by_last_writer(operation_1, operation_2)
    else
      raise ConflictResolutionError, "Unknown conflict resolution strategy: #{strategy}"
    end
  end

  # Document Integration
  def apply_operations_to_document(document, operations)
    return unless document && operations.any?

    current_content = document.content || ""
    final_content = apply_operations_sequence(current_content, operations)

    # Update document content
    document.update!(content: final_content)

    # Create new version if significant changes
    if should_create_version?(document, operations)
      document.create_version!(
        created_by_user_id: operations.first[:user_id],
        version_notes: "Auto-version: operational transform operations",
        is_auto_version: true
      )
    end

    # Store operation records
    operations.each do |operation|
      store_operation_record(document.id, operation)
    end
  end

  def apply_and_broadcast_operation(document, operation)
    begin
      # Validate operation
      validate_operation!(operation)

      # Check for conflicts with recent operations
      recent_operations = get_recent_operations(document.id, since: 5.seconds.ago)
      conflicts = detect_conflicts(operation, recent_operations)

      result_data = { status: "success", transformed_operation: operation }

      if conflicts.any?
        # Resolve conflicts
        resolved_operation = resolve_operation_conflicts(operation, conflicts)
        result_data.merge!(
          status: "conflict_resolved",
          transformed_operation: resolved_operation,
          conflicts: conflicts.map { |c| describe_conflict(c) },
          resolution_strategy: "timestamp_priority"
        )
        operation = resolved_operation
      end

      # Apply operation to document
      current_content = document.content || ""
      new_content = apply_operation(current_content, operation)
      document.update!(content: new_content)

      # Store operation record
      operation_record = store_operation_record(document.id, operation)

      # Broadcast to ActionCable
      DocumentEditChannel.broadcast_to(document, {
        type: "operation_applied",
        operation: operation,
        operation_id: operation_record.operation_id,
        user_id: operation[:user_id],
        timestamp: operation[:timestamp],
        conflicts: result_data[:conflicts],
        resolution_strategy: result_data[:resolution_strategy]
      }.compact)

      result_data
    rescue StandardError => e
      {
        status: "error",
        error: e.message,
        operation: operation
      }
    end
  end

  private

  # Operation Application Helpers
  def apply_insert_operation(content, operation)
    position = clamp_position(operation[:position], content.length + 1)
    content.insert(position, operation[:content] || "")
  end

  def apply_delete_operation(content, operation)
    position = clamp_position(operation[:position], content.length)
    length = [ operation[:length] || 0, content.length - position ].min

    return content if length <= 0

    content.slice(0, position) + content.slice(position + length, content.length)
  end

  def apply_replace_operation(content, operation)
    position = clamp_position(operation[:position], content.length)
    length = [ operation[:length] || 0, content.length - position ].min
    replacement = operation[:content] || ""

    content.slice(0, position) + replacement + content.slice(position + length, content.length)
  end

  # Operation Transformation Helpers
  def transform_insert_insert(base_op, target_op)
    if target_op[:position] > base_op[:position] ||
       (target_op[:position] == base_op[:position] && target_op[:timestamp] > base_op[:timestamp])
      target_op.merge(position: target_op[:position] + base_op[:content].length)
    else
      target_op.dup
    end
  end

  def transform_insert_delete(base_op, target_op)
    if target_op[:position] >= base_op[:position]
      target_op.merge(position: target_op[:position] + base_op[:content].length)
    else
      target_op.dup
    end
  end

  def transform_delete_insert(base_op, target_op)
    delete_end = base_op[:position] + base_op[:length]

    if target_op[:position] > delete_end
      target_op.merge(position: target_op[:position] - base_op[:length])
    elsif target_op[:position] >= base_op[:position]
      # Insert position is within or at the start of deleted range
      target_op.merge(position: base_op[:position])
    else
      target_op.dup
    end
  end

  def transform_delete_delete(base_op, target_op)
    base_end = base_op[:position] + base_op[:length]
    target_end = target_op[:position] + target_op[:length]

    if target_op[:position] >= base_end
      # Target delete is after base delete
      target_op.merge(position: target_op[:position] - base_op[:length])
    elsif target_end <= base_op[:position]
      # Target delete is before base delete
      target_op.dup
    else
      # Overlapping deletes - complex case
      resolve_overlapping_deletes(base_op, target_op)
    end
  end

  def transform_insert_replace(base_op, target_op)
    if base_op[:type] == "insert"
      insert_op, replace_op = base_op, target_op
    else
      insert_op, replace_op = target_op, base_op
    end

    replace_end = replace_op[:position] + replace_op[:length]

    if insert_op[:position] <= replace_op[:position]
      replace_op.merge(position: replace_op[:position] + insert_op[:content].length)
    elsif insert_op[:position] < replace_end
      # Insert is within replace range - adjust replace content
      relative_pos = insert_op[:position] - replace_op[:position]
      new_content = replace_op[:content].dup
      new_content.insert(relative_pos, insert_op[:content])
      replace_op.merge(content: new_content)
    else
      replace_op.dup
    end
  end

  def transform_delete_replace(base_op, target_op)
    # Complex transformation - simplified implementation
    if base_op[:type] == "delete"
      delete_op, replace_op = base_op, target_op
    else
      delete_op, replace_op = target_op, base_op
    end

    # Apply basic position transformation
    transform_delete_insert(delete_op, replace_op.merge(type: "insert"))
  end

  def transform_replace_replace(base_op, target_op)
    # Handle overlapping replaces based on timestamp priority
    if target_op[:timestamp] > base_op[:timestamp]
      # Target operation wins, adjust position if needed
      base_end = base_op[:position] + base_op[:length]
      if target_op[:position] >= base_end
        length_diff = base_op[:content].length - base_op[:length]
        target_op.merge(position: target_op[:position] + length_diff)
      else
        target_op.dup
      end
    else
      # Base operation wins, target becomes no-op or is discarded
      target_op.merge(type: "noop")
    end
  end

  # Conflict Resolution Helpers
  def resolve_by_timestamp(op1, op2)
    winning_op = op1[:timestamp] <= op2[:timestamp] ? op1 : op2
    losing_op = op1[:timestamp] <= op2[:timestamp] ? op2 : op1

    {
      strategy: "timestamp_priority",
      winning_operation: winning_op,
      transformed_operations: [ transform_operation(winning_op, losing_op) ]
    }
  end

  def resolve_by_user_priority(op1, op2)
    user1_priority = get_user_priority(op1[:user_id])
    user2_priority = get_user_priority(op2[:user_id])

    winning_op = user1_priority >= user2_priority ? op1 : op2
    losing_op = user1_priority >= user2_priority ? op2 : op1

    {
      strategy: "user_priority",
      winning_operation: winning_op,
      transformed_operations: [ transform_operation(winning_op, losing_op) ]
    }
  end

  def resolve_by_last_writer(op1, op2)
    {
      strategy: "last_writer_wins",
      winning_operation: op2,
      transformed_operations: [ op2 ]
    }
  end

  def resolve_overlapping_deletes(base_op, target_op)
    # Simplified: merge the delete ranges
    start_pos = [ base_op[:position], target_op[:position] ].min
    base_end = base_op[:position] + base_op[:length]
    target_end = target_op[:position] + target_op[:length]
    end_pos = [ base_end, target_end ].max

    target_op.merge(
      position: start_pos,
      length: end_pos - start_pos
    )
  end

  # Conflict Detection
  def detect_conflicts(operation, recent_operations)
    conflicts = []

    recent_operations.each do |recent_op|
      if operations_conflict?(operation, recent_op)
        conflicts << recent_op
      end
    end

    conflicts
  end

  def operations_conflict?(op1, op2)
    return false if op1[:user_id] == op2[:user_id]

    case [ op1[:type], op2[:type] ]
    when [ "delete", "delete" ], [ "replace", "replace" ]
      ranges_overlap?(op1, op2)
    when [ "insert", "insert" ]
      op1[:position] == op2[:position]
    else
      false
    end
  end

  def ranges_overlap?(op1, op2)
    op1_end = op1[:position] + (op1[:length] || 0)
    op2_end = op2[:position] + (op2[:length] || 0)

    !(op1_end <= op2[:position] || op2_end <= op1[:position])
  end

  def resolve_operation_conflicts(operation, conflicts)
    conflicts.reduce(operation) do |current_op, conflict|
      resolution = resolve_conflict(conflict, current_op)
      resolution[:transformed_operations].first
    end
  end

  def describe_conflict(conflict_operation)
    {
      type: "#{conflict_operation[:type]}_conflict",
      position: conflict_operation[:position],
      user_id: conflict_operation[:user_id],
      timestamp: conflict_operation[:timestamp]
    }
  end

  # Database Operations
  def store_operation_record(document_id, operation)
    OperationalTransform.create!(
      document_id: document_id,
      user_id: operation[:user_id],
      operation_type: operation[:type],
      position: operation[:position],
      length: operation[:length],
      content: operation[:content],
      timestamp: operation[:timestamp],
      operation_id: operation[:operation_id] || generate_operation_id,
      applied_at: Time.current,
      status: "applied"
    )
  end

  def get_recent_operations(document_id, since:)
    OperationalTransform.where(document_id: document_id)
                       .where("applied_at > ?", since)
                       .order(:timestamp)
                       .map(&:to_operation_hash)
  end

  # Manual Conflict Resolution
  def resolve_conflict_manually(document_id, resolution_data)
    begin
      conflict_id = resolution_data[:conflict_id]
      strategy = resolution_data[:resolution_strategy]
      content = resolution_data[:resolved_content]
      resolved_by = resolution_data[:resolved_by]

      # Validate strategy
      unless VALID_CONFLICT_STRATEGIES.include?(strategy)
        return { success: false, error: "Invalid resolution strategy: #{strategy}" }
      end

      # For manual resolution, we accept the provided content
      document = Document.find(document_id)

      # Update document content with resolved content
      document.update!(content: content)

      # Clear any pending operations for this conflict
      OperationalTransform.where(document_id: document_id, operation_id: conflict_id).destroy_all

      # Log the manual resolution
      Rails.logger.info "[CONFLICT_RESOLUTION] Manual resolution for conflict #{conflict_id} by user #{resolved_by}"

      {
        success: true,
        final_content: content,
        resolution_strategy: strategy,
        resolved_by: resolved_by,
        resolved_at: Time.current
      }
    rescue ActiveRecord::RecordNotFound => e
      { success: false, error: "Document not found: #{e.message}" }
    rescue StandardError => e
      Rails.logger.error "[CONFLICT_RESOLUTION] Error in manual resolution: #{e.message}"
      { success: false, error: "Resolution failed: #{e.message}" }
    end
  end

  # Utility Methods
  def validate_operation!(operation)
    raise InvalidOperationError, "Operation must be a hash" unless operation.is_a?(Hash)
    raise InvalidOperationError, "Operation type is required" unless operation[:type].present?
    raise InvalidOperationError, "Invalid operation type" unless VALID_OPERATION_TYPES.include?(operation[:type])
    raise InvalidOperationError, "Position is required" unless operation[:position].is_a?(Integer)
    raise InvalidOperationError, "User ID is required" unless operation[:user_id].present?
    raise InvalidOperationError, "Timestamp is required" unless operation[:timestamp].present?

    case operation[:type]
    when "delete", "replace"
      raise InvalidOperationError, "Length is required for #{operation[:type]} operations" unless operation[:length].is_a?(Integer)
    when "insert", "replace"
      raise InvalidOperationError, "Content is required for #{operation[:type]} operations" unless operation[:content].present?
    end
  end

  def clamp_position(position, max_position)
    [ [ position, 0 ].max, max_position ].min
  end

  def generate_operation_id
    "op_#{SecureRandom.uuid}"
  end

  def get_user_priority(user_id)
    user = User.find_by(id: user_id)
    return 1 unless user

    @user_priorities[user.role] || 1
  end

  def should_create_version?(document, operations)
    # Create version for significant changes (>50% of content or >1000 characters changed)
    return false if operations.empty?

    total_changes = operations.sum do |op|
      case op[:type]
      when "insert", "replace"
        op[:content]&.length || 0
      when "delete"
        op[:length] || 0
      else
        0
      end
    end

    content_length = document.content&.length || 0
    change_percentage = content_length > 0 ? (total_changes.to_f / content_length) * 100 : 100

    change_percentage > 50 || total_changes > 1000
  end
end

# Extension for OperationalTransform model
class OperationalTransform < ApplicationRecord
  belongs_to :document
  belongs_to :user

  validates :operation_type, inclusion: { in: OperationalTransformService::VALID_OPERATION_TYPES }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :timestamp, presence: true
  validates :operation_id, presence: true, uniqueness: true

  scope :for_document, ->(doc_id) { where(document_id: doc_id) }
  scope :recent, ->(since = 1.hour.ago) { where("applied_at > ?", since) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  def to_operation_hash
    {
      type: operation_type,
      position: position,
      length: length,
      content: content,
      user_id: user_id,
      timestamp: timestamp.to_f,
      operation_id: operation_id,
      applied_at: applied_at
    }
  end
end
