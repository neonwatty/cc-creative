# frozen_string_literal: true

require "test_helper"

class NotificationChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:one)
    
    # Set up authentication
    stub_connection current_user: @user
  end

  # Subscription Tests
  test "subscribes to user notifications successfully" do
    subscribe user_id: @user.id

    assert subscription.confirmed?
    assert_has_stream_for @user
  end

  test "subscribes to document notifications successfully" do
    subscribe document_id: @document.id

    assert subscription.confirmed?
    assert_has_stream_for @document
  end

  test "subscribes to global notifications for authenticated user" do
    subscribe notification_type: "global"

    assert subscription.confirmed?
    assert_has_stream "global_notifications"
  end

  test "rejects subscription for unauthorized user notifications" do
    subscribe user_id: @other_user.id

    assert subscription.rejected?
  end

  test "rejects subscription for unauthorized document notifications" do
    unauthorized_doc = Document.create!(
      title: "Private Document",
      user: @other_user,
      description: "Private content"
    )

    subscribe document_id: unauthorized_doc.id

    assert subscription.rejected?
  end

  test "rejects subscription without proper authentication" do
    stub_connection current_user: nil

    subscribe user_id: @user.id

    assert subscription.rejected?
  end

  # System Notification Tests
  test "receives system maintenance notifications" do
    subscribe notification_type: "global"

    notification = {
      type: "system_maintenance",
      title: "Scheduled Maintenance",
      message: "System will be down for maintenance from 2:00 AM to 4:00 AM EST",
      severity: "warning",
      timestamp: Time.current.iso8601,
      scheduled_time: 2.hours.from_now.iso8601,
      duration: "2 hours"
    }

    NotificationChannel.broadcast_to("global_notifications", notification)

    assert_broadcast_on("global_notifications", notification)
  end

  test "receives system error notifications" do
    subscribe notification_type: "global"

    notification = {
      type: "system_error",
      title: "Service Disruption",
      message: "Collaboration service is temporarily unavailable",
      severity: "error",
      timestamp: Time.current.iso8601,
      error_code: "COLLAB_503",
      retry_after: 5.minutes.from_now.iso8601
    }

    NotificationChannel.broadcast_to("global_notifications", notification)

    assert_broadcast_on("global_notifications", notification)
  end

  test "receives feature announcement notifications" do
    subscribe notification_type: "global"

    notification = {
      type: "feature_announcement",
      title: "New Collaboration Features Available",
      message: "Try out our new real-time editing and presence indicators",
      severity: "info",
      timestamp: Time.current.iso8601,
      action_url: "/features/collaboration",
      action_text: "Learn More"
    }

    NotificationChannel.broadcast_to("global_notifications", notification)

    assert_broadcast_on("global_notifications", notification)
  end

  # User-Specific Notification Tests
  test "receives collaboration invitation notifications" do
    subscribe user_id: @user.id

    notification = {
      type: "collaboration_invitation",
      title: "Collaboration Invitation",
      message: "#{@other_user.name} invited you to collaborate on '#{@document.title}'",
      severity: "info",
      timestamp: Time.current.iso8601,
      from_user: {
        id: @other_user.id,
        name: @other_user.name,
        email: @other_user.email_address
      },
      document: {
        id: @document.id,
        title: @document.title
      },
      actions: [
        { type: "accept", text: "Accept", url: "/collaborate/#{@document.id}/accept" },
        { type: "decline", text: "Decline", url: "/collaborate/#{@document.id}/decline" }
      ]
    }

    NotificationChannel.broadcast_to(@user, notification)

    assert_broadcast_on(@user, notification)
  end

  test "receives mention notifications" do
    subscribe user_id: @user.id

    notification = {
      type: "user_mention",
      title: "You were mentioned",
      message: "#{@other_user.name} mentioned you in a comment on '#{@document.title}'",
      severity: "info",
      timestamp: Time.current.iso8601,
      mentioned_by: {
        id: @other_user.id,
        name: @other_user.name
      },
      document: {
        id: @document.id,
        title: @document.title
      },
      comment_context: "Hey @#{@user.name}, what do you think about this section?",
      action_url: "/documents/#{@document.id}#comment-123"
    }

    NotificationChannel.broadcast_to(@user, notification)

    assert_broadcast_on(@user, notification)
  end

  test "receives document sharing notifications" do
    subscribe user_id: @user.id

    notification = {
      type: "document_shared",
      title: "Document Shared With You",
      message: "#{@other_user.name} shared '#{@document.title}' with you",
      severity: "info",
      timestamp: Time.current.iso8601,
      shared_by: {
        id: @other_user.id,
        name: @other_user.name
      },
      document: {
        id: @document.id,
        title: @document.title
      },
      permissions: ["read", "comment"],
      action_url: "/documents/#{@document.id}"
    }

    NotificationChannel.broadcast_to(@user, notification)

    assert_broadcast_on(@user, notification)
  end

  # Document-Specific Notification Tests
  test "receives document collaboration notifications" do
    subscribe document_id: @document.id

    notification = {
      type: "user_joined_collaboration",
      title: "User Joined",
      message: "#{@other_user.name} joined the collaboration session",
      severity: "info",
      timestamp: Time.current.iso8601,
      user: {
        id: @other_user.id,
        name: @other_user.name,
        avatar_url: nil
      },
      session_info: {
        active_users: 2,
        session_started: 1.hour.ago.iso8601
      }
    }

    NotificationChannel.broadcast_to(@document, notification)

    assert_broadcast_on(@document, notification)
  end

  test "receives document version notifications" do
    subscribe document_id: @document.id

    notification = {
      type: "document_version_created",
      title: "New Version Created",
      message: "#{@other_user.name} created version 1.2 of this document",
      severity: "info",
      timestamp: Time.current.iso8601,
      created_by: {
        id: @other_user.id,
        name: @other_user.name
      },
      version: {
        number: "1.2",
        name: "Feature Implementation",
        notes: "Added new collaboration features"
      },
      action_url: "/documents/#{@document.id}/versions/1.2"
    }

    NotificationChannel.broadcast_to(@document, notification)

    assert_broadcast_on(@document, notification)
  end

  test "receives document conflict notifications" do
    subscribe document_id: @document.id

    notification = {
      type: "edit_conflict_resolved",
      title: "Edit Conflict Resolved",
      message: "Concurrent edits were automatically merged using timestamp priority",
      severity: "warning",
      timestamp: Time.current.iso8601,
      conflict_details: {
        resolution_strategy: "timestamp_priority",
        conflicting_users: [@user.id, @other_user.id],
        affected_sections: [
          { start: 100, end: 150, type: "overlapping_edit" }
        ]
      },
      review_recommended: true,
      action_url: "/documents/#{@document.id}/review-changes"
    }

    NotificationChannel.broadcast_to(@document, notification)

    assert_broadcast_on(@document, notification)
  end

  # Notification Action Handling Tests
  test "marks notification as read" do
    subscribe user_id: @user.id

    notification_id = "notif_#{SecureRandom.uuid}"

    perform :mark_as_read, { notification_id: notification_id }

    # Should store read status
    read_status = Rails.cache.read("notification_read_#{@user.id}_#{notification_id}")
    assert read_status
  end

  test "dismisses notification" do
    subscribe user_id: @user.id

    notification_id = "notif_#{SecureRandom.uuid}"

    perform :dismiss_notification, { notification_id: notification_id }

    # Should store dismissed status
    dismissed_status = Rails.cache.read("notification_dismissed_#{@user.id}_#{notification_id}")
    assert dismissed_status
  end

  test "updates notification preferences" do
    subscribe user_id: @user.id

    preferences = {
      collaboration_invitations: true,
      mentions: true,
      document_sharing: false,
      system_announcements: true,
      email_digest: "daily"
    }

    perform :update_preferences, { preferences: preferences }

    # Should store user preferences
    stored_prefs = Rails.cache.read("notification_preferences_#{@user.id}")
    assert_equal preferences.stringify_keys, stored_prefs
  end

  # Notification Filtering Tests
  test "filters notifications by severity" do
    subscribe user_id: @user.id, severity_filter: ["error", "warning"]

    # Send info notification (should be filtered out)
    info_notification = {
      type: "feature_announcement",
      severity: "info",
      message: "This should be filtered"
    }

    # Send error notification (should pass through)
    error_notification = {
      type: "system_error",
      severity: "error",
      message: "This should be received"
    }

    perform :send_filtered_notification, info_notification
    perform :send_filtered_notification, error_notification

    # Only error notification should be transmitted
    assert_transmissions 1
    assert_equal "This should be received", transmissions.last["message"]
  end

  test "filters notifications by type" do
    subscribe user_id: @user.id, type_filter: ["collaboration_invitation", "user_mention"]

    # Send allowed notification type
    allowed_notification = {
      type: "collaboration_invitation",
      message: "This should be received"
    }

    # Send disallowed notification type
    disallowed_notification = {
      type: "system_announcement",
      message: "This should be filtered"
    }

    perform :send_filtered_notification, allowed_notification
    perform :send_filtered_notification, disallowed_notification

    assert_transmissions 1
    assert_equal "This should be received", transmissions.last["message"]
  end

  # Real-time Status Tests
  test "broadcasts real-time collaboration status" do
    subscribe document_id: @document.id

    status_update = {
      type: "collaboration_status",
      active_users: [
        { id: @user.id, name: @user.name, status: "editing" },
        { id: @other_user.id, name: @other_user.name, status: "viewing" }
      ],
      document_locked: false,
      last_edit: Time.current.iso8601,
      timestamp: Time.current.iso8601
    }

    perform :broadcast_status, status_update

    assert_broadcast_on(@document, status_update)
  end

  test "broadcasts typing indicators" do
    subscribe document_id: @document.id

    typing_update = {
      type: "typing_indicator",
      user: {
        id: @other_user.id,
        name: @other_user.name
      },
      typing: true,
      position: { line: 10, column: 25 },
      timestamp: Time.current.iso8601
    }

    perform :broadcast_typing, typing_update

    assert_broadcast_on(@document, typing_update)
  end

  # Notification Persistence Tests
  test "persists important notifications" do
    subscribe user_id: @user.id

    important_notification = {
      type: "collaboration_invitation",
      title: "Important Invitation",
      message: "Critical collaboration request",
      severity: "warning",
      persistent: true,
      expires_at: 1.week.from_now.iso8601
    }

    perform :send_persistent_notification, important_notification

    # Should be stored for later retrieval
    stored_notifications = Rails.cache.read("persistent_notifications_#{@user.id}") || []
    assert stored_notifications.any? { |n| n["title"] == "Important Invitation" }
  end

  test "retrieves unread notifications" do
    subscribe user_id: @user.id

    perform :get_unread_notifications

    assert_transmissions 1
    response = transmissions.last
    assert_equal "unread_notifications", response["type"]
    assert response["notifications"].is_a?(Array)
    assert_present response["count"]
  end

  # Error Handling Tests
  test "handles invalid notification data gracefully" do
    subscribe user_id: @user.id

    invalid_notification = {
      type: nil,
      message: "",
      severity: "invalid_severity"
    }

    perform :send_notification, invalid_notification

    # Should transmit error response
    assert_transmissions 1
    response = transmissions.last
    assert_equal "notification_error", response["type"]
    assert_present response["error"]
  end

  test "handles subscription errors gracefully" do
    # Test with invalid user_id
    subscribe user_id: 99999

    assert subscription.rejected?
  end

  # Performance Tests
  test "handles high volume of notifications efficiently" do
    subscribe user_id: @user.id

    start_time = Time.current

    # Send 50 notifications rapidly
    50.times do |i|
      notification = {
        type: "test_notification",
        message: "Test message #{i}",
        severity: "info",
        timestamp: Time.current.iso8601
      }
      
      perform :send_notification, notification
    end

    processing_time = Time.current - start_time

    assert processing_time < 2.0, "Processing 50 notifications took too long: #{processing_time}s"
    assert_transmissions 50
  end

  # Batch Notification Tests
  test "handles batch notifications" do
    subscribe user_id: @user.id

    batch_notifications = [
      {
        type: "collaboration_update",
        message: "User A joined",
        timestamp: Time.current.iso8601
      },
      {
        type: "collaboration_update", 
        message: "User B left",
        timestamp: (Time.current + 1.second).iso8601
      },
      {
        type: "document_saved",
        message: "Document auto-saved",
        timestamp: (Time.current + 2.seconds).iso8601
      }
    ]

    perform :send_batch_notifications, { notifications: batch_notifications }

    assert_transmissions 1
    response = transmissions.last
    assert_equal "batch_notifications", response["type"]
    assert_equal 3, response["notifications"].length
  end

  # Cleanup Tests
  test "cleans up user data on unsubscription" do
    subscribe user_id: @user.id

    # Store some temporary notification data
    Rails.cache.write("notification_session_#{@user.id}", { active: true })

    unsubscribe

    # Should clean up temporary data
    session_data = Rails.cache.read("notification_session_#{@user.id}")
    assert_nil session_data
  end

  # Integration Tests
  test "integrates with other channels for coordinated notifications" do
    subscribe user_id: @user.id

    # Should coordinate with PresenceChannel for user status
    PresenceChannel.expects(:broadcast_to).with(@user, hash_including(
      type: "notification_delivered",
      user_id: @user.id
    ))

    notification = {
      type: "test_integration",
      message: "Integration test",
      coordinate_with_presence: true
    }

    perform :send_coordinated_notification, notification

    assert_transmissions 1
  end

  private

  def assert_transmissions(count)
    assert_equal count, transmissions.size
  end
end