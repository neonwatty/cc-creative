# frozen_string_literal: true

require "test_helper"

class CollaborationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document = documents(:one)
    @user = users(:one)
    @other_user = users(:two)
    @admin_user = users(:one)
    @admin_user.update!(role: "admin")

    # Set up user session
    post sessions_path, params: { email_address: @user.email_address, password: "Secret123!" }
  end

  # Session Management Tests
  test "should start collaboration session for authorized user" do
    post collaboration_start_path(@document),
         params: {
           session_settings: {
             max_users: 5,
             editing_mode: "collaborative",
             conflict_resolution: "timestamp_priority"
           }
         }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal "session_started", json_response["status"]
    assert_present json_response["session_id"]
    assert_equal @document.id, json_response["document_id"]
    assert_equal @user.id, json_response["user_id"]
    assert_present json_response["websocket_url"]
  end

  test "should not start collaboration session for unauthorized user" do
    # Create a document owned by another user
    private_doc = Document.create!(
      title: "Private Document",
      user: @other_user,
      description: "Private content"
    )

    post collaboration_start_path(private_doc),
         params: { session_settings: { max_users: 5 } }

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "unauthorized", json_response["error"]
  end

  test "should join existing collaboration session" do
    # Start session as first user
    post collaboration_start_path(@document)
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    # Switch to other user
    post sessions_path, params: { email_address: @other_user.email_address, password: "Secret123!" }

    # Make @other_user authorized for the document
    @document.update!(user: @user) # Ensure document ownership allows collaboration

    post collaboration_join_path(@document),
         params: { session_id: session_id }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal "session_joined", json_response["status"]
    assert_equal session_id, json_response["session_id"]
    assert_equal @other_user.id, json_response["user_id"]
  end

  test "should not join session if at maximum capacity" do
    # Start session with max_users: 1
    post collaboration_start_path(@document),
         params: { session_settings: { max_users: 1 } }

    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    # Try to join as another user
    post sessions_path, params: { email_address: @other_user.email_address, password: "Secret123!" }

    post collaboration_join_path(@document),
         params: { session_id: session_id }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "session_full", json_response["error"]
  end

  test "should leave collaboration session" do
    # Start and join session
    post collaboration_start_path(@document)
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    delete collaboration_leave_path(@document),
           params: { session_id: session_id }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "session_left", json_response["status"]
  end

  # Document Locking Tests
  test "should acquire document lock for editing" do
    post collaboration_lock_path(@document),
         params: {
           lock_type: "write",
           section: { start: 0, end: 100 },
           timeout: 300
         }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal "lock_acquired", json_response["status"]
    assert_present json_response["lock_id"]
    assert_equal "write", json_response["lock_type"]
    assert_equal @user.id, json_response["locked_by"]
  end

  test "should not acquire conflicting lock" do
    # First user acquires write lock
    post collaboration_lock_path(@document),
         params: { lock_type: "write", section: { start: 0, end: 100 } }

    first_response = JSON.parse(response.body)
    assert_equal "lock_acquired", first_response["status"]

    # Switch to second user
    post sessions_path, params: { email_address: @other_user.email_address, password: "Secret123!" }

    # Try to acquire overlapping lock
    post collaboration_lock_path(@document),
         params: { lock_type: "write", section: { start: 50, end: 150 } }

    assert_response :conflict
    json_response = JSON.parse(response.body)
    assert_equal "lock_conflict", json_response["error"]
    assert_present json_response["conflicting_lock"]
  end

  test "should release document lock" do
    # Acquire lock
    post collaboration_lock_path(@document),
         params: { lock_type: "write", section: { start: 0, end: 100 } }

    lock_data = JSON.parse(response.body)
    lock_id = lock_data["lock_id"]

    # Release lock
    delete collaboration_unlock_path(@document),
           params: { lock_id: lock_id }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "lock_released", json_response["status"]
  end

  test "should auto-release expired locks" do
    # Acquire lock with short timeout
    post collaboration_lock_path(@document),
         params: {
           lock_type: "write",
           section: { start: 0, end: 100 },
           timeout: 1
         }

    lock_data = JSON.parse(response.body)
    lock_id = lock_data["lock_id"]

    # Wait for expiration
    sleep(2)

    # Try to check lock status
    get collaboration_lock_status_path(@document, lock_id)

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "lock_expired", json_response["error"]
  end

  # Permission and Access Control Tests
  test "should check user permissions for collaboration" do
    get collaboration_permissions_path(@document)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response["can_collaborate"]
    assert json_response["can_read"]
    assert json_response["can_write"]
    assert_equal @user.role, json_response["user_role"]
  end

  test "should handle different permission levels" do
    # Test with limited permissions user
    limited_user = User.create!(
      name: "Limited User",
      email_address: "limited@example.com",
      password: "Secret123!",
      role: "viewer"
    )

    post sessions_path, params: { email_address: limited_user.email_address, password: "Secret123!" }

    get collaboration_permissions_path(@document)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_not json_response["can_write"]
    assert json_response["can_read"]
  end

  # Presence Broadcasting Tests
  test "should broadcast user presence updates" do
    # Mock ActionCable broadcast
    PresenceChannel.expects(:broadcast_to).with(@document, has_entries(
      type: "user_status_changed",
      user_id: @user.id,
      status: "active"
    )).once

    post collaboration_presence_path(@document),
         params: {
           status: "active",
           activity: "editing"
         }

    assert_response :success
  end

  test "should handle typing indicators" do
    PresenceChannel.expects(:broadcast_to).with(@document, has_entries(
      type: "user_typing",
      user_id: @user.id
    )).once

    post collaboration_typing_path(@document),
         params: { typing: true }

    assert_response :success
  end

  # Error Recovery Tests
  test "should handle network disconnection recovery" do
    # Start session
    post collaboration_start_path(@document)
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    # Simulate disconnection and reconnection
    post collaboration_reconnect_path(@document),
         params: {
           session_id: session_id,
           last_known_state: {
             cursor_position: 100,
             content_hash: "abc123"
           }
         }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal "reconnected", json_response["status"]
    assert_present json_response["sync_data"]
    assert_present json_response["missed_operations"]
  end

  test "should handle invalid session recovery" do
    post collaboration_reconnect_path(@document),
         params: {
           session_id: "invalid-session-id",
           last_known_state: {}
         }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "session_not_found", json_response["error"]
  end

  # Real-time Operation Processing Tests
  test "should process operational transform operations" do
    operation = {
      type: "insert",
      position: 10,
      content: "Hello",
      timestamp: Time.current.to_f,
      user_id: @user.id
    }

    # Mock OperationalTransformService
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .with(@document, operation)
                              .returns({ status: "success", transformed_operation: operation })

    post collaboration_operation_path(@document),
         params: { operation: operation }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "operation_applied", json_response["status"]
  end

  test "should handle conflicting operations" do
    operation = {
      type: "delete",
      position: 10,
      length: 5,
      timestamp: Time.current.to_f,
      user_id: @user.id
    }

    # Mock conflict resolution
    OperationalTransformService.any_instance.expects(:apply_and_broadcast_operation)
                              .with(@document, operation)
                              .returns({
                                status: "conflict_resolved",
                                transformed_operation: operation,
                                conflicts: [ "position_adjusted" ]
                              })

    post collaboration_operation_path(@document),
         params: { operation: operation }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "conflict_resolved", json_response["status"]
    assert_present json_response["conflicts"]
  end

  # Session Status and Monitoring Tests
  test "should get collaboration session status" do
    # Start session
    post collaboration_start_path(@document)
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    get collaboration_status_path(@document),
        params: { session_id: session_id }

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal "active", json_response["session_status"]
    assert_present json_response["active_users"]
    assert_present json_response["active_locks"]
    assert_present json_response["operation_count"]
  end

  test "should get list of active collaborators" do
    get collaboration_users_path(@document)

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response["users"].is_a?(Array)
    # Should include current user
    user_ids = json_response["users"].map { |u| u["id"] }
    assert_includes user_ids, @user.id
  end

  # Performance and Rate Limiting Tests
  test "should rate limit rapid operations" do
    # Send many operations rapidly
    10.times do |i|
      post collaboration_operation_path(@document),
           params: {
             operation: {
               type: "insert",
               position: i,
               content: i.to_s,
               timestamp: Time.current.to_f,
               user_id: @user.id
             }
           }
    end

    # Last request should be rate limited
    assert_response :too_many_requests
  end

  test "should handle concurrent session requests" do
    # Simulate multiple simultaneous session starts
    threads = []
    results = []

    5.times do
      threads << Thread.new do
        # Each thread makes a session start request
        post collaboration_start_path(@document)
        results << response.status
      end
    end

    threads.each(&:join)

    # Only one should succeed (200), others should get conflict (409) or redirect to existing
    success_count = results.count(200)
    assert_equal 1, success_count, "Only one session start should succeed"
  end

  # Administrative Controls Tests
  test "admin should force terminate collaboration session" do
    post sessions_path, params: { email_address: @admin_user.email_address, password: "Secret123!" }

    # Start session
    post collaboration_start_path(@document)
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    delete collaboration_terminate_path(@document),
           params: { session_id: session_id, reason: "maintenance" }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "session_terminated", json_response["status"]
  end

  test "non-admin should not force terminate session" do
    # Start session
    post collaboration_start_path(@document)
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]

    delete collaboration_terminate_path(@document),
           params: { session_id: session_id, reason: "unauthorized_attempt" }

    assert_response :forbidden
  end

  # Edge Cases and Error Handling
  test "should handle malformed operation data" do
    invalid_operation = {
      type: "invalid_type",
      position: "not_a_number",
      content: nil
    }

    post collaboration_operation_path(@document),
         params: { operation: invalid_operation }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "invalid_operation", json_response["error"]
  end

  test "should handle document not found" do
    post collaboration_start_path(id: 99999)

    assert_response :not_found
  end

  test "should handle missing required parameters" do
    post collaboration_start_path(@document),
         params: {}

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["errors"].present?
  end

  private

  def collaboration_start_path(document)
    "/api/v1/documents/#{document.id}/collaboration/start"
  end

  def collaboration_join_path(document)
    "/api/v1/documents/#{document.id}/collaboration/join"
  end

  def collaboration_leave_path(document)
    "/api/v1/documents/#{document.id}/collaboration/leave"
  end

  def collaboration_lock_path(document)
    "/api/v1/documents/#{document.id}/collaboration/lock"
  end

  def collaboration_unlock_path(document)
    "/api/v1/documents/#{document.id}/collaboration/unlock"
  end

  def collaboration_lock_status_path(document, lock_id)
    "/api/v1/documents/#{document.id}/collaboration/locks/#{lock_id}"
  end

  def collaboration_permissions_path(document)
    "/api/v1/documents/#{document.id}/collaboration/permissions"
  end

  def collaboration_presence_path(document)
    "/api/v1/documents/#{document.id}/collaboration/presence"
  end

  def collaboration_typing_path(document)
    "/api/v1/documents/#{document.id}/collaboration/typing"
  end

  def collaboration_reconnect_path(document)
    "/api/v1/documents/#{document.id}/collaboration/reconnect"
  end

  def collaboration_operation_path(document)
    "/api/v1/documents/#{document.id}/collaboration/operation"
  end

  def collaboration_status_path(document)
    "/api/v1/documents/#{document.id}/collaboration/status"
  end

  def collaboration_users_path(document)
    "/api/v1/documents/#{document.id}/collaboration/users"
  end

  def collaboration_terminate_path(document)
    "/api/v1/documents/#{document.id}/collaboration/terminate"
  end
end
