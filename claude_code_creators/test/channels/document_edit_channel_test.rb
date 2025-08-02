# frozen_string_literal: true

require "test_helper"

class DocumentEditChannelTest < ActionCable::Channel::TestCase
  setup do
    @document = documents(:one)
    @user = users(:one)
    @other_user = users(:two)
    
    # Set up authentication
    stub_connection current_user: @user
  end

  # Subscription Tests
  test "subscribes to document edit channel with valid document" do
    subscribe document_id: @document.id

    assert subscription.confirmed?
    assert_has_stream_for @document
  end

  test "rejects subscription for non-existent document" do
    subscribe document_id: 99999

    assert subscription.rejected?
  end

  test "rejects subscription for unauthorized document" do
    unauthorized_doc = Document.create!(
      title: "Private Document",
      user: @other_user,
      description: "Private content"
    )

    subscribe document_id: unauthorized_doc.id

    assert subscription.rejected?
  end

  test "automatically joins collaboration session on subscription" do
    subscribe document_id: @document.id

    # Check that user was added to document presence
    presence_key = "document_#{@document.id}_presence"
    presence_data = Rails.cache.read(presence_key) || {}
    
    assert presence_data.key?(@user.id) || presence_data.key?(@user.id.to_s)
  end

  # Real-time Editing Tests
  test "applies insert operation and broadcasts to others" do
    subscribe document_id: @document.id

    operation = {
      type: "insert",
      position: 10,
      content: "Hello World",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    # Mock OperationalTransformService
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .with(@document, operation)
                              .returns({
                                status: "success",
                                transformed_operation: operation,
                                new_content: "Updated content with Hello World"
                              })

    perform :edit_operation, operation

    # Should broadcast operation to other users
    assert_broadcast_on(@document, {
      type: "operation_applied",
      operation: operation,
      user_id: @user.id,
      timestamp: operation[:timestamp]
    })
  end

  test "applies delete operation correctly" do
    subscribe document_id: @document.id

    operation = {
      type: "delete",
      position: 5,
      length: 10,
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .with(@document, operation)
                              .returns({
                                status: "success",
                                transformed_operation: operation
                              })

    perform :edit_operation, operation

    assert_broadcast_on(@document, {
      type: "operation_applied",
      operation: operation,
      user_id: @user.id
    })
  end

  test "applies replace operation correctly" do
    subscribe document_id: @document.id

    operation = {
      type: "replace",
      position: 5,
      length: 5,
      content: "REPLACED",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .returns({ status: "success", transformed_operation: operation })

    perform :edit_operation, operation

    assert_broadcast_on(@document, hash_including(type: "operation_applied"))
  end

  # Operational Transform Integration Tests
  test "handles concurrent operations with transformation" do
    subscribe document_id: @document.id

    # First operation
    op1 = {
      type: "insert",
      position: 5,
      content: "ABC",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    # Second operation that needs transformation
    op2 = {
      type: "insert",
      position: 7,
      content: "XYZ",
      user_id: @other_user.id,
      timestamp: Time.current.to_f + 0.1
    }

    # Mock transformation
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .twice
                              .returns(
                                { status: "success", transformed_operation: op1 },
                                { 
                                  status: "transformed", 
                                  transformed_operation: op2.merge(position: 10),
                                  original_operation: op2
                                }
                              )

    perform :edit_operation, op1
    perform :edit_operation, op2

    # Both operations should be broadcast
    assert_broadcasts_on(@document, 2)
  end

  test "handles conflicting operations with resolution" do
    subscribe document_id: @document.id

    conflicting_operation = {
      type: "delete",
      position: 5,
      length: 10,
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    # Mock conflict resolution
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .returns({
                                status: "conflict_resolved",
                                transformed_operation: conflicting_operation,
                                resolution_strategy: "timestamp_priority",
                                conflicts: ["overlapping_delete"]
                              })

    perform :edit_operation, conflicting_operation

    assert_broadcast_on(@document, {
      type: "operation_applied",
      operation: conflicting_operation,
      conflicts: ["overlapping_delete"],
      resolution_strategy: "timestamp_priority"
    })
  end

  # Cursor Synchronization Tests
  test "broadcasts cursor position updates" do
    subscribe document_id: @document.id

    cursor_data = {
      position: { line: 10, column: 25 },
      selection: { start: 100, end: 150 }
    }

    perform :cursor_moved, cursor_data

    assert_broadcast_on(@document, {
      type: "cursor_moved",
      user_id: @user.id,
      user_name: @user.name,
      position: cursor_data[:position],
      selection: cursor_data[:selection],
      timestamp: anything
    })
  end

  test "handles cursor position during concurrent edits" do
    subscribe document_id: @document.id

    # Operation that affects cursor position
    operation = {
      type: "insert",
      position: 5,
      content: "INSERTED",
      user_id: @other_user.id,
      timestamp: Time.current.to_f
    }

    cursor_position = 10

    # Mock cursor transformation
    OperationalTransformService.any_instance.expects(:transform_cursor_position)
                              .with(cursor_position, operation)
                              .returns(18) # 10 + "INSERTED".length

    perform :transform_cursor, { 
      operation: operation, 
      cursor_position: cursor_position 
    }

    assert_broadcast_on(@document, {
      type: "cursor_transformed",
      user_id: @user.id,
      old_position: cursor_position,
      new_position: 18,
      operation: operation
    })
  end

  # Selection Synchronization Tests
  test "broadcasts text selection changes" do
    subscribe document_id: @document.id

    selection_data = {
      start: 50,
      end: 100,
      text: "selected text content"
    }

    perform :selection_changed, selection_data

    assert_broadcast_on(@document, {
      type: "selection_changed",
      user_id: @user.id,
      user_name: @user.name,
      selection: selection_data,
      timestamp: anything
    })
  end

  # Document State Synchronization Tests
  test "requests document state synchronization" do
    subscribe document_id: @document.id

    # Mock document content retrieval
    expected_content = "Current document content"
    @document.expects(:content).returns(expected_content)

    perform :request_sync

    # Should send current document state back to requesting user
    assert_transmissions 1
    transmission = transmissions.last
    assert_equal "document_sync", transmission["type"]
    assert_equal expected_content, transmission["content"]
    assert_present transmission["version"]
    assert_present transmission["timestamp"]
  end

  test "handles sync request with client state hash" do
    subscribe document_id: @document.id

    client_state_hash = "abc123def456"
    server_content = "Current server content"
    server_state_hash = Digest::MD5.hexdigest(server_content)

    @document.expects(:content).returns(server_content)

    perform :request_sync, { client_state_hash: client_state_hash }

    transmission = transmissions.last
    
    if client_state_hash == server_state_hash
      assert_equal "sync_confirmed", transmission["type"]
    else
      assert_equal "document_sync", transmission["type"]
      assert_equal server_content, transmission["content"]
    end
  end

  # User Presence Integration Tests
  test "updates user activity on edit operations" do
    subscribe document_id: @document.id

    operation = {
      type: "insert",
      position: 10,
      content: "test",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    # Mock service calls
    OperationalTransformService.any_instance.stubs(:apply_and_broadcast_operation)
                              .returns({ status: "success", transformed_operation: operation })

    perform :edit_operation, operation

    # Should update user's last activity
    presence_key = "document_#{@document.id}_presence"
    presence_data = Rails.cache.read(presence_key) || {}
    user_data = presence_data[@user.id] || presence_data[@user.id.to_s]
    
    assert user_data.present?
    # Activity should be recent (within last few seconds)
    last_seen = Time.parse(user_data[:last_seen] || user_data["last_seen"])
    assert last_seen > 5.seconds.ago
  end

  # Error Handling Tests
  test "handles invalid operation gracefully" do
    subscribe document_id: @document.id

    invalid_operation = {
      type: "invalid_type",
      position: "not_a_number",
      content: nil
    }

    # Mock service to raise error
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .raises(OperationalTransformService::InvalidOperationError.new("Invalid operation"))

    perform :edit_operation, invalid_operation

    # Should transmit error back to user
    assert_transmissions 1
    transmission = transmissions.last
    assert_equal "operation_error", transmission["type"]
    assert_equal "Invalid operation", transmission["error"]
  end

  test "handles service unavailable gracefully" do
    subscribe document_id: @document.id

    operation = {
      type: "insert",
      position: 10,
      content: "test",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    # Mock service unavailable
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .raises(StandardError.new("Service temporarily unavailable"))

    perform :edit_operation, operation

    transmission = transmissions.last
    assert_equal "service_error", transmission["type"]
    assert_match(/temporarily unavailable/, transmission["error"])
  end

  # Performance Tests
  test "handles rapid operation sequence efficiently" do
    subscribe document_id: @document.id

    operations = []
    10.times do |i|
      operations << {
        type: "insert",
        position: i,
        content: i.to_s,
        user_id: @user.id,
        timestamp: Time.current.to_f + (i * 0.01)
      }
    end

    # Mock successful processing
    OperationalTransformService.any_instance.stubs(:apply_and_broadcast_operation)
                              .returns({ status: "success", transformed_operation: anything })

    start_time = Time.current
    operations.each { |op| perform :edit_operation, op }
    processing_time = Time.current - start_time

    assert processing_time < 1.0, "Processing 10 operations took too long: #{processing_time}s"
    assert_broadcasts_on(@document, 10)
  end

  # Batch Operations Tests
  test "handles batch operations correctly" do
    subscribe document_id: @document.id

    batch_operations = [
      {
        type: "insert",
        position: 0,
        content: "Start: ",
        user_id: @user.id,
        timestamp: Time.current.to_f
      },
      {
        type: "insert",
        position: 50,
        content: " :End",
        user_id: @user.id,
        timestamp: Time.current.to_f + 0.1
      }
    ]

    # Mock batch processing
    OperationalTransformService.any_instance.expects(:apply_operations_batch)
                              .with(@document, batch_operations)
                              .returns({
                                status: "batch_success",
                                applied_operations: batch_operations,
                                final_content: "processed content"
                              })

    perform :batch_operations, { operations: batch_operations }

    assert_broadcast_on(@document, {
      type: "batch_operations_applied",
      operations: batch_operations,
      user_id: @user.id
    })
  end

  # Document Version Control Integration Tests
  test "triggers version creation on significant changes" do
    subscribe document_id: @document.id

    significant_operation = {
      type: "replace",
      position: 0,
      length: 1000, # Large replacement
      content: "Completely new content that replaces most of the document",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    # Mock version creation
    @document.expects(:create_version!)
             .with(
               created_by_user: @user,
               version_notes: "Auto-version: significant edit",
               is_auto_version: true
             )

    OperationalTransformService.any_instance.stubs(:apply_and_broadcast_operation)
                              .returns({ 
                                status: "success", 
                                transformed_operation: significant_operation,
                                version_created: true
                              })

    perform :edit_operation, significant_operation

    assert_broadcast_on(@document, hash_including(
      type: "operation_applied",
      version_created: true
    ))
  end

  # Cleanup and Unsubscription Tests
  test "removes user from presence on unsubscription" do
    subscribe document_id: @document.id

    # Verify user is in presence
    presence_key = "document_#{@document.id}_presence"
    presence_data = Rails.cache.read(presence_key) || {}
    assert presence_data.key?(@user.id) || presence_data.key?(@user.id.to_s)

    # Unsubscribe
    unsubscribe

    # Verify user removed from presence
    updated_presence = Rails.cache.read(presence_key) || {}
    assert_not updated_presence.key?(@user.id)
    assert_not updated_presence.key?(@user.id.to_s)
  end

  test "broadcasts user left message on unsubscription" do
    subscribe document_id: @document.id

    # Should broadcast when user leaves
    assert_broadcast_on(@document, {
      type: "user_left",
      user_id: @user.id,
      timestamp: anything
    }) do
      unsubscribe
    end
  end

  # Integration with Other Channels Tests
  test "coordinates with PresenceChannel for user awareness" do
    subscribe document_id: @document.id

    # Mock PresenceChannel broadcast
    PresenceChannel.expects(:broadcast_to).with(@document, hash_including(
      type: "user_editing",
      user_id: @user.id
    ))

    operation = {
      type: "insert",
      position: 10,
      content: "test",
      user_id: @user.id,
      timestamp: Time.current.to_f
    }

    OperationalTransformService.any_instance.stubs(:apply_and_broadcast_operation)
                              .returns({ status: "success", transformed_operation: operation })

    perform :edit_operation, operation
  end

  private

  def assert_broadcasts_on(stream, count)
    assert_equal count, broadcasts(stream).size
  end

  def assert_transmissions(count)
    assert_equal count, transmissions.size
  end
end