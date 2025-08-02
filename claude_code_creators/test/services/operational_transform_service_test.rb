# frozen_string_literal: true

require "test_helper"

class OperationalTransformServiceTest < ActiveSupport::TestCase
  setup do
    @service = OperationalTransformService.new
    @document = documents(:one)
    @user = users(:one)
    @other_user = users(:two)
  end

  # Basic Operation Tests
  test "applies insert operation correctly" do
    initial_content = "Hello world"
    operation = {
      type: "insert",
      position: 5,
      content: " beautiful",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    result = @service.apply_operation(initial_content, operation)
    assert_equal "Hello beautiful world", result
  end

  test "applies delete operation correctly" do
    initial_content = "Hello beautiful world"
    operation = {
      type: "delete",
      position: 5,
      length: 10, # " beautiful"
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    result = @service.apply_operation(initial_content, operation)
    assert_equal "Hello world", result
  end

  test "applies replace operation correctly" do
    initial_content = "Hello world"
    operation = {
      type: "replace",
      position: 6,
      length: 5,
      content: "universe",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    result = @service.apply_operation(initial_content, operation)
    assert_equal "Hello universe", result
  end

  # Operation Transformation Tests
  test "transforms concurrent insert operations correctly" do
    # Two users insert at different positions
    op1 = {
      type: "insert",
      position: 5,
      content: " beautiful",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    op2 = {
      type: "insert",
      position: 11,
      content: "!",
      user_id: @other_user.id,
      timestamp: Time.current.to_f + 0.1
    }

    transformed_op2 = @service.transform_operation(op1, op2)

    # op2 should be adjusted because op1 inserted before it
    assert_equal 21, transformed_op2[:position] # 11 + " beautiful".length
    assert_equal "!", transformed_op2[:content]
    assert_equal "insert", transformed_op2[:type]
  end

  test "transforms concurrent insert at same position with timestamp priority" do
    base_time = Time.current.to_f

    op1 = {
      type: "insert",
      position: 5,
      content: "A",
      user_id: @user.id,
      timestamp: base_time
    }

    op2 = {
      type: "insert",
      position: 5,
      content: "B",
      user_id: @other_user.id,
      timestamp: base_time + 0.1
    }

    transformed_op2 = @service.transform_operation(op1, op2)

    # Later operation should be shifted right
    assert_equal 6, transformed_op2[:position]
    assert_equal "B", transformed_op2[:content]
  end

  test "transforms insert against delete operation" do
    op1 = {
      type: "delete",
      position: 5,
      length: 5,
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    op2 = {
      type: "insert",
      position: 8,
      content: "X",
      user_id: @other_user.id,
      timestamp: Time.current.to_f + 0.1
    }

    transformed_op2 = @service.transform_operation(op1, op2)

    # Insert position should be adjusted for the deletion
    assert_equal 5, transformed_op2[:position] # 8 - 5 + 2 (within deleted range, clamp to start)
    assert_equal "X", transformed_op2[:content]
  end

  test "transforms delete against insert operation" do
    op1 = {
      type: "insert",
      position: 5,
      content: "XXXX",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    op2 = {
      type: "delete",
      position: 8,
      length: 3,
      user_id: @other_user.id,
      timestamp: Time.current.to_f + 0.1
    }

    transformed_op2 = @service.transform_operation(op1, op2)

    # Delete position should be adjusted for the insertion
    assert_equal 12, transformed_op2[:position] # 8 + 4
    assert_equal 3, transformed_op2[:length]
  end

  # Cursor Position Synchronization Tests
  test "transforms cursor position for insert operation" do
    cursor_position = 10
    operation = {
      type: "insert",
      position: 5,
      content: "XXXX",
      user_id: @other_user.id,
      timestamp: Time.current.to_f
    }

    new_position = @service.transform_cursor_position(cursor_position, operation)
    assert_equal 14, new_position # 10 + 4
  end

  test "transforms cursor position for delete operation" do
    cursor_position = 15
    operation = {
      type: "delete",
      position: 5,
      length: 5,
      user_id: @other_user.id,
      timestamp: Time.current.to_f
    }

    new_position = @service.transform_cursor_position(cursor_position, operation)
    assert_equal 10, new_position # 15 - 5
  end

  test "transforms cursor position when cursor is in deleted range" do
    cursor_position = 7
    operation = {
      type: "delete",
      position: 5,
      length: 5,
      user_id: @other_user.id,
      timestamp: Time.current.to_f
    }

    new_position = @service.transform_cursor_position(cursor_position, operation)
    assert_equal 5, new_position # Clamp to start of deleted range
  end

  # Operation Queue Management Tests
  test "queues operations for processing" do
    operation = {
      type: "insert",
      position: 5,
      content: "test",
      user_id: @user.id,
      document_id: @document.id,
      timestamp: Time.current.to_f
    }

    @service.queue_operation(@document.id, operation)

    queued_ops = @service.get_queued_operations(@document.id)
    assert_equal 1, queued_ops.length
    assert_equal operation[:content], queued_ops.first[:content]
  end

  test "processes operation queue in timestamp order" do
    base_time = Time.current.to_f

    op1 = {
      type: "insert",
      position: 5,
      content: "A",
      user_id: @user.id,
      document_id: @document.id,
      timestamp: base_time + 0.2
    }

    op2 = {
      type: "insert",
      position: 5,
      content: "B",
      user_id: @other_user.id,
      document_id: @document.id,
      timestamp: base_time + 0.1
    }

    op3 = {
      type: "insert",
      position: 5,
      content: "C",
      user_id: @user.id,
      document_id: @document.id,
      timestamp: base_time
    }

    @service.queue_operation(@document.id, op1)
    @service.queue_operation(@document.id, op2)
    @service.queue_operation(@document.id, op3)

    sorted_ops = @service.get_sorted_operations(@document.id)
    assert_equal "C", sorted_ops[0][:content]
    assert_equal "B", sorted_ops[1][:content]
    assert_equal "A", sorted_ops[2][:content]
  end

  # State Consistency Tests
  test "verifies document state consistency after operations" do
    initial_content = "Hello world"
    operations = [
      {
        type: "insert",
        position: 5,
        content: " beautiful",
        user_id: @user.id,
        timestamp: Time.current.to_f
      },
      {
        type: "insert",
        position: 21,
        content: "!",
        user_id: @other_user.id,
        timestamp: Time.current.to_f + 0.1
      }
    ]

    final_content = @service.apply_operations_sequence(initial_content, operations)
    state_consistent = @service.verify_state_consistency(@document.id, final_content)

    assert_equal "Hello beautiful world!", final_content
    assert state_consistent
  end

  test "detects state inconsistency" do
    # Simulate inconsistent state
    @service.instance_variable_set(:@expected_state, { @document.id => "expected content" })
    actual_content = "different content"

    state_consistent = @service.verify_state_consistency(@document.id, actual_content)
    assert_not state_consistent
  end

  # Conflict Resolution Tests
  test "resolves conflicting operations using timestamp priority" do
    base_time = Time.current.to_f

    op1 = {
      type: "delete",
      position: 5,
      length: 5,
      user_id: @user.id,
      timestamp: base_time
    }

    op2 = {
      type: "insert",
      position: 7,
      content: "X",
      user_id: @other_user.id,
      timestamp: base_time + 0.1
    }

    resolution = @service.resolve_conflict(op1, op2)

    assert_equal "timestamp_priority", resolution[:strategy]
    assert_equal op1, resolution[:winning_operation]
    assert resolution[:transformed_operations].any?
  end

  test "resolves conflicting operations using user priority" do
    # Set user priority: admin > user
    @user.update!(role: "admin")
    @other_user.update!(role: "user")

    op1 = {
      type: "delete",
      position: 5,
      length: 5,
      user_id: @other_user.id,
      timestamp: Time.current.to_f
    }

    op2 = {
      type: "insert",
      position: 7,
      content: "X",
      user_id: @user.id,
      timestamp: Time.current.to_f + 0.1
    }

    resolution = @service.resolve_conflict(op1, op2, strategy: :user_priority)

    assert_equal "user_priority", resolution[:strategy]
    assert_equal op2, resolution[:winning_operation]
  end

  # Performance Tests
  test "handles large operation sequences efficiently" do
    initial_content = "Base content"
    operations = []

    # Generate 100 operations
    100.times do |i|
      operations << {
        type: "insert",
        position: i % 20,
        content: i.to_s,
        user_id: [@user.id, @other_user.id].sample,
        timestamp: Time.current.to_f + (i * 0.01)
      }
    end

    start_time = Time.current
    final_content = @service.apply_operations_sequence(initial_content, operations)
    end_time = Time.current

    processing_time = end_time - start_time

    assert processing_time < 1.0, "Processing 100 operations took too long: #{processing_time}s"
    assert final_content.present?
  end

  # Edge Cases
  test "handles empty content operations" do
    operation = {
      type: "insert",
      position: 0,
      content: "",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    result = @service.apply_operation("test", operation)
    assert_equal "test", result
  end

  test "handles invalid position gracefully" do
    operation = {
      type: "insert",
      position: 100,
      content: "X",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    result = @service.apply_operation("test", operation)
    assert_equal "testX", result # Should append to end
  end

  test "handles negative position gracefully" do
    operation = {
      type: "insert",
      position: -1,
      content: "X",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    result = @service.apply_operation("test", operation)
    assert_equal "Xtest", result # Should prepend to beginning
  end

  test "validates operation structure" do
    invalid_operation = {
      type: "invalid_type",
      position: 5,
      user_id: @user.id
    }

    assert_raises(OperationalTransformService::InvalidOperationError) do
      @service.apply_operation("test", invalid_operation)
    end
  end

  # Integration with Document Model
  test "integrates with document versioning" do
    operations = [
      {
        type: "insert",
        position: 0,
        content: "Hello world",
        user_id: @user.id,
        timestamp: Time.current.to_f
      }
    ]

    @service.apply_operations_to_document(@document, operations)

    @document.reload
    assert @document.current_version_number > 0
  end

  test "broadcasts operations via ActionCable" do
    operation = {
      type: "insert",
      position: 5,
      content: "test",
      user_id: @user.id,
      document_id: @document.id,
      timestamp: Time.current.to_f
    }

    # Mock ActionCable broadcast
    DocumentEditChannel.expects(:broadcast_to).with(@document, has_entries(
      type: "operation_applied",
      operation: operation
    )).once

    @service.apply_and_broadcast_operation(@document, operation)
  end
end