# frozen_string_literal: true

class NotificationChannel < ApplicationCable::Channel
  VALID_NOTIFICATION_TYPES = %w[
    global user_specific document_specific
    collaboration_invitation user_mention document_shared
    system_maintenance system_error feature_announcement
    task_assigned code_review_requested workflow_update
  ].freeze

  VALID_SEVERITIES = %w[info warning error critical].freeze

  def subscribed
    subscription_type = params[:notification_type]
    user_id = params[:user_id]
    document_id = params[:document_id]

    case subscription_type
    when "global"
      subscribe_to_global_notifications
    when "user_specific"
      subscribe_to_user_notifications(user_id)
    when "document_specific"
      subscribe_to_document_notifications(document_id)
    else
      reject
      return
    end

    # Set up user session for notifications
    initialize_notification_session

    logger.info "User #{current_user.id} subscribed to NotificationChannel (#{subscription_type})"
  end

  def unsubscribed
    # Clean up user notification session data
    cleanup_notification_session

    logger.info "User #{current_user.id} unsubscribed from NotificationChannel"
  end

  # Notification Management Actions
  def mark_as_read(data = {})
    notification_id = data["notification_id"]
    return unless notification_id

    # Store read status
    read_key = "notification_read_#{current_user.id}_#{notification_id}"
    Rails.cache.write(read_key, true, expires_in: 30.days)

    # Update notification statistics
    update_notification_stats("read")

    transmit({
      type: "notification_marked_read",
      notification_id: notification_id,
      timestamp: Time.current.iso8601
    })
  end

  def dismiss_notification(data = {})
    notification_id = data["notification_id"]
    return unless notification_id

    # Store dismissed status
    dismissed_key = "notification_dismissed_#{current_user.id}_#{notification_id}"
    Rails.cache.write(dismissed_key, true, expires_in: 30.days)

    # Update notification statistics
    update_notification_stats("dismissed")

    transmit({
      type: "notification_dismissed",
      notification_id: notification_id,
      timestamp: Time.current.iso8601
    })
  end

  def update_preferences(data = {})
    preferences = data["preferences"] || {}

    # Validate preferences
    valid_prefs = validate_notification_preferences(preferences)

    # Store user preferences
    prefs_key = "notification_preferences_#{current_user.id}"
    Rails.cache.write(prefs_key, valid_prefs, expires_in: 1.year)

    transmit({
      type: "preferences_updated",
      preferences: valid_prefs,
      timestamp: Time.current.iso8601
    })
  end

  # Notification Sending Actions
  def send_notification(data = {})
    notification = prepare_notification(data)
    return unless notification

    if should_send_notification?(notification)
      # Send to user
      transmit(notification)

      # Track delivery
      track_notification_delivery(notification)
    end
  end

  def send_filtered_notification(data = {})
    notification = prepare_notification(data)
    return unless notification

    # Apply user filters
    if passes_user_filters?(notification)
      transmit(notification)
      track_notification_delivery(notification)
    end
  end

  def send_persistent_notification(data = {})
    notification = prepare_notification(data)
    return unless notification

    # Store persistent notification
    if notification[:persistent]
      store_persistent_notification(notification)
    end

    # Send immediately
    transmit(notification)
    track_notification_delivery(notification)
  end

  def send_batch_notifications(data = {})
    notifications = data["notifications"] || []
    return if notifications.empty?

    filtered_notifications = notifications.filter_map do |notif_data|
      notification = prepare_notification(notif_data)
      next unless notification && should_send_notification?(notification)

      notification
    end

    return if filtered_notifications.empty?

    # Send as batch
    transmit({
      type: "batch_notifications",
      notifications: filtered_notifications,
      count: filtered_notifications.length,
      timestamp: Time.current.iso8601
    })

    # Track each delivery
    filtered_notifications.each { |notif| track_notification_delivery(notif) }
  end

  # Notification Retrieval Actions
  def get_unread_notifications(data = {})
    limit = [ data["limit"]&.to_i || 50, 100 ].min

    unread_notifications = get_user_unread_notifications(limit)

    transmit({
      type: "unread_notifications",
      notifications: unread_notifications,
      count: unread_notifications.length,
      timestamp: Time.current.iso8601
    })
  end

  def get_notification_history(data = {})
    days = [ data["days"]&.to_i || 7, 30 ].min
    limit = [ data["limit"]&.to_i || 100, 500 ].min

    history = get_user_notification_history(days, limit)

    transmit({
      type: "notification_history",
      notifications: history,
      days: days,
      timestamp: Time.current.iso8601
    })
  end

  # Real-time Status Broadcasting
  def broadcast_status(data = {})
    # Only allow authorized users to broadcast status
    return unless can_broadcast_status?

    status_update = data.merge(
      broadcast_by: current_user.id,
      timestamp: Time.current.iso8601
    )

    # Broadcast to document subscribers
    if document_id = data["document_id"]
      document = Document.find_by(id: document_id)
      if document && authorized_for_document?(document)
        NotificationChannel.broadcast_to(document, status_update)
      end
    end
  end

  def broadcast_typing(data = {})
    return unless params[:notification_type] == "document_specific"

    document_id = params[:document_id]
    document = Document.find_by(id: document_id)
    return unless document && authorized_for_document?(document)

    typing_update = data.merge(
      user_id: current_user.id,
      user_name: current_user.name,
      timestamp: Time.current.iso8601
    )

    NotificationChannel.broadcast_to(document, typing_update)
  end

  # Coordination with Other Channels
  def send_coordinated_notification(data = {})
    notification = prepare_notification(data)
    return unless notification

    # Send notification
    transmit(notification)

    # Coordinate with presence channel if requested
    if data["coordinate_with_presence"]
      PresenceChannel.broadcast_to(current_user, {
        type: "notification_delivered",
        user_id: current_user.id,
        notification_type: notification[:type],
        timestamp: Time.current.iso8601
      })
    end

    track_notification_delivery(notification)
  end

  private

  # Subscription Setup
  def subscribe_to_global_notifications
    stream_from "global_notifications"
  end

  def subscribe_to_user_notifications(user_id)
    # Only allow users to subscribe to their own notifications
    unless user_id.to_i == current_user.id
      reject
      return
    end

    stream_for current_user
  end

  def subscribe_to_document_notifications(document_id)
    document = Document.find_by(id: document_id)
    unless document && authorized_for_document?(document)
      reject
      return
    end

    stream_for document
  end

  # Session Management
  def initialize_notification_session
    session_key = "notification_session_#{current_user.id}"
    session_data = {
      connected_at: Time.current.iso8601,
      subscription_type: params[:notification_type],
      user_id: current_user.id,
      active: true
    }
    Rails.cache.write(session_key, session_data, expires_in: 2.hours)
  end

  def cleanup_notification_session
    session_key = "notification_session_#{current_user.id}"
    Rails.cache.delete(session_key)
  end

  # Notification Preparation and Validation
  def prepare_notification(data)
    return nil unless data.is_a?(Hash)

    notification = {
      id: data["id"] || generate_notification_id,
      type: data["type"],
      title: data["title"],
      message: data["message"],
      severity: data["severity"] || "info",
      timestamp: data["timestamp"] || Time.current.iso8601,
      persistent: data["persistent"] == true,
      expires_at: data["expires_at"]
    }

    # Add optional fields
    %w[action_url action_text actions user_data document_data metadata].each do |field|
      notification[field.to_sym] = data[field] if data[field]
    end

    return nil unless validate_notification(notification)

    notification
  end

  def validate_notification(notification)
    return false unless notification[:type].present?
    return false unless VALID_NOTIFICATION_TYPES.include?(notification[:type])
    return false unless notification[:message].present?
    return false unless VALID_SEVERITIES.include?(notification[:severity])

    true
  end

  # Filtering and Preferences
  def should_send_notification?(notification)
    return false unless notification

    # Check if user has dismissed this type
    return false if notification_type_dismissed?(notification[:type])

    # Check user preferences
    return false unless notification_allowed_by_preferences?(notification)

    # Check rate limiting
    return false if rate_limited?(notification)

    true
  end

  def passes_user_filters?(notification)
    severity_filter = params[:severity_filter]
    type_filter = params[:type_filter]

    # Check severity filter
    if severity_filter && !severity_filter.include?(notification[:severity])
      return false
    end

    # Check type filter
    if type_filter && !type_filter.include?(notification[:type])
      return false
    end

    true
  end

  def get_user_preferences
    prefs_key = "notification_preferences_#{current_user.id}"
    Rails.cache.read(prefs_key) || default_notification_preferences
  end

  def default_notification_preferences
    {
      "collaboration_invitations" => true,
      "mentions" => true,
      "document_sharing" => true,
      "system_announcements" => true,
      "email_digest" => "daily"
    }
  end

  def validate_notification_preferences(preferences)
    valid_keys = default_notification_preferences.keys + %w[email_digest]

    preferences.slice(*valid_keys).tap do |prefs|
      # Validate email_digest values
      if prefs["email_digest"] && !%w[never daily weekly].include?(prefs["email_digest"])
        prefs["email_digest"] = "daily"
      end
    end
  end

  def notification_allowed_by_preferences?(notification)
    preferences = get_user_preferences

    case notification[:type]
    when "collaboration_invitation"
      preferences["collaboration_invitations"] != false
    when "user_mention"
      preferences["mentions"] != false
    when "document_shared"
      preferences["document_sharing"] != false
    when "system_maintenance", "feature_announcement"
      preferences["system_announcements"] != false
    else
      true # Allow by default for unknown types
    end
  end

  # Notification Storage and Retrieval
  def store_persistent_notification(notification)
    notifications_key = "persistent_notifications_#{current_user.id}"
    notifications = Rails.cache.read(notifications_key) || []

    # Add new notification
    notifications.unshift(notification)

    # Keep only last 100 notifications
    notifications = notifications.first(100)

    # Store with expiration
    expires_in = notification[:expires_at] ?
                   Time.parse(notification[:expires_at]) - Time.current :
                   30.days

    Rails.cache.write(notifications_key, notifications, expires_in: expires_in)
  end

  def get_user_unread_notifications(limit)
    notifications_key = "persistent_notifications_#{current_user.id}"
    all_notifications = Rails.cache.read(notifications_key) || []

    # Filter unread notifications
    unread = all_notifications.reject do |notif|
      read_key = "notification_read_#{current_user.id}_#{notif[:id]}"
      Rails.cache.read(read_key)
    end

    unread.first(limit)
  end

  def get_user_notification_history(days, limit)
    notifications_key = "persistent_notifications_#{current_user.id}"
    all_notifications = Rails.cache.read(notifications_key) || []

    cutoff_date = days.days.ago

    # Filter by date and limit
    recent = all_notifications.select do |notif|
      Time.parse(notif[:timestamp]) > cutoff_date
    end

    recent.first(limit)
  end

  # Rate Limiting
  def rate_limited?(notification)
    rate_key = "notification_rate_#{current_user.id}_#{notification[:type]}"
    current_count = Rails.cache.read(rate_key) || 0

    # Different limits for different types
    limit = case notification[:severity]
    when "critical" then 50
    when "error" then 20
    when "warning" then 10
    else 5
    end

    if current_count >= limit
      return true
    end

    # Increment counter
    Rails.cache.write(rate_key, current_count + 1, expires_in: 1.hour)
    false
  end

  # Tracking and Analytics
  def track_notification_delivery(notification)
    delivery_key = "notification_delivery_#{current_user.id}"
    deliveries = Rails.cache.read(delivery_key) || []

    delivery_record = {
      notification_id: notification[:id],
      type: notification[:type],
      severity: notification[:severity],
      delivered_at: Time.current.iso8601
    }

    deliveries.unshift(delivery_record)
    deliveries = deliveries.first(1000) # Keep last 1000 deliveries

    Rails.cache.write(delivery_key, deliveries, expires_in: 7.days)
  end

  def update_notification_stats(action)
    stats_key = "notification_stats_#{current_user.id}"
    stats = Rails.cache.read(stats_key) || { "read" => 0, "dismissed" => 0, "total_received" => 0 }

    stats[action] = (stats[action] || 0) + 1

    Rails.cache.write(stats_key, stats, expires_in: 30.days)
  end

  # Authorization Helpers
  def authorized_for_document?(document)
    document.user == current_user || current_user.admin?
  end

  def can_broadcast_status?
    # Only allow admins and document owners to broadcast status
    current_user.admin? || params[:document_id] &&
      Document.find_by(id: params[:document_id])&.user == current_user
  end

  def notification_type_dismissed?(type)
    dismissed_key = "notification_type_dismissed_#{current_user.id}_#{type}"
    Rails.cache.read(dismissed_key)
  end

  # Utility Methods
  def generate_notification_id
    "notif_#{SecureRandom.uuid}"
  end
end
