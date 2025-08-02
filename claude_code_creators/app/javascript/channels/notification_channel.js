/**
 * NotificationChannel - Frontend client for real-time notifications and typing indicators
 * Integrates with Rails NotificationChannel for collaboration awareness
 */

import consumer from "./consumer"

class NotificationChannel {
  constructor() {
    this.subscriptions = new Map() // subscriptionKey -> subscription
    this.callbacks = new Map() // subscriptionKey -> callbacks
  }

  // Subscribe to global notifications
  subscribeToGlobal(callbacks = {}) {
    const subscriptionKey = "global"
    
    if (this.subscriptions.has(subscriptionKey)) {
      console.warn("Already subscribed to global notifications")
      return this.subscriptions.get(subscriptionKey)
    }

    const subscription = consumer.subscriptions.create(
      { 
        channel: "NotificationChannel", 
        notification_type: "global"
      },
      {
        connected: () => {
          console.log("Connected to global NotificationChannel")
          this.handleConnected(subscriptionKey, callbacks)
        },

        disconnected: () => {
          console.log("Disconnected from global NotificationChannel")
          this.handleDisconnected(subscriptionKey, callbacks)
        },

        rejected: () => {
          console.error("Global NotificationChannel subscription rejected")
          this.handleRejected(subscriptionKey, callbacks)
        },

        received: (data) => {
          this.handleReceived(subscriptionKey, data, callbacks)
        }
      }
    )

    this.subscriptions.set(subscriptionKey, subscription)
    this.callbacks.set(subscriptionKey, callbacks)

    return subscription
  }

  // Subscribe to user-specific notifications
  subscribeToUser(userId, callbacks = {}) {
    const subscriptionKey = `user_${userId}`
    
    if (this.subscriptions.has(subscriptionKey)) {
      console.warn(`Already subscribed to user ${userId} notifications`)
      return this.subscriptions.get(subscriptionKey)
    }

    const subscription = consumer.subscriptions.create(
      { 
        channel: "NotificationChannel", 
        notification_type: "user_specific",
        user_id: userId
      },
      {
        connected: () => {
          console.log(`Connected to user ${userId} NotificationChannel`)
          this.handleConnected(subscriptionKey, callbacks)
        },

        disconnected: () => {
          console.log(`Disconnected from user ${userId} NotificationChannel`)
          this.handleDisconnected(subscriptionKey, callbacks)
        },

        rejected: () => {
          console.error(`User ${userId} NotificationChannel subscription rejected`)
          this.handleRejected(subscriptionKey, callbacks)
        },

        received: (data) => {
          this.handleReceived(subscriptionKey, data, callbacks)
        }
      }
    )

    this.subscriptions.set(subscriptionKey, subscription)
    this.callbacks.set(subscriptionKey, callbacks)

    return subscription
  }

  // Subscribe to document-specific notifications
  subscribeToDocument(documentId, callbacks = {}) {
    const subscriptionKey = `document_${documentId}`
    
    if (this.subscriptions.has(subscriptionKey)) {
      console.warn(`Already subscribed to document ${documentId} notifications`)
      return this.subscriptions.get(subscriptionKey)
    }

    const subscription = consumer.subscriptions.create(
      { 
        channel: "NotificationChannel", 
        notification_type: "document_specific",
        document_id: documentId
      },
      {
        connected: () => {
          console.log(`Connected to document ${documentId} NotificationChannel`)
          this.handleConnected(subscriptionKey, callbacks)
        },

        disconnected: () => {
          console.log(`Disconnected from document ${documentId} NotificationChannel`)
          this.handleDisconnected(subscriptionKey, callbacks)
        },

        rejected: () => {
          console.error(`Document ${documentId} NotificationChannel subscription rejected`)
          this.handleRejected(subscriptionKey, callbacks)
        },

        received: (data) => {
          this.handleReceived(subscriptionKey, data, callbacks)
        }
      }
    )

    this.subscriptions.set(subscriptionKey, subscription)
    this.callbacks.set(subscriptionKey, callbacks)

    return subscription
  }

  // Unsubscribe from notifications
  unsubscribe(subscriptionKey) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (subscription) {
      subscription.unsubscribe()
      this.subscriptions.delete(subscriptionKey)
      this.callbacks.delete(subscriptionKey)
      console.log(`Unsubscribed from NotificationChannel: ${subscriptionKey}`)
    }
  }

  // Mark notification as read
  markAsRead(subscriptionKey, notificationId) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("mark_as_read", {
      notification_id: notificationId
    })
  }

  // Dismiss notification
  dismissNotification(subscriptionKey, notificationId) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("dismiss_notification", {
      notification_id: notificationId
    })
  }

  // Update notification preferences
  updatePreferences(subscriptionKey, preferences) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("update_preferences", {
      preferences
    })
  }

  // Send notification (if authorized)
  sendNotification(subscriptionKey, notificationData) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("send_notification", notificationData)
  }

  // Send filtered notification
  sendFilteredNotification(subscriptionKey, notificationData) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("send_filtered_notification", notificationData)
  }

  // Send persistent notification
  sendPersistentNotification(subscriptionKey, notificationData) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("send_persistent_notification", notificationData)
  }

  // Send batch notifications
  sendBatchNotifications(subscriptionKey, notifications) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("send_batch_notifications", {
      notifications
    })
  }

  // Get unread notifications
  getUnreadNotifications(subscriptionKey, limit = 50) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("get_unread_notifications", { limit })
  }

  // Get notification history
  getNotificationHistory(subscriptionKey, days = 7, limit = 100) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("get_notification_history", { days, limit })
  }

  // Broadcast status (for authorized users)
  broadcastStatus(subscriptionKey, statusData) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("broadcast_status", statusData)
  }

  // Broadcast typing indicator
  broadcastTyping(subscriptionKey, typingData) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("broadcast_typing", typingData)
  }

  // Send coordinated notification
  sendCoordinatedNotification(subscriptionKey, notificationData) {
    const subscription = this.subscriptions.get(subscriptionKey)
    if (!subscription) {
      throw new Error(`Not subscribed to ${subscriptionKey}`)
    }

    subscription.perform("send_coordinated_notification", notificationData)
  }

  // Connection event handlers
  handleConnected(subscriptionKey, callbacks) {
    if (callbacks.onConnected) {
      callbacks.onConnected(subscriptionKey)
    }
  }

  handleDisconnected(subscriptionKey, callbacks) {
    if (callbacks.onDisconnected) {
      callbacks.onDisconnected(subscriptionKey)
    }
  }

  handleRejected(subscriptionKey, callbacks) {
    if (callbacks.onRejected) {
      callbacks.onRejected(subscriptionKey)
    }
  }

  // Message handling
  handleReceived(subscriptionKey, data, callbacks) {
    const { type } = data

    switch (type) {
    case "notification_marked_read":
      this.handleNotificationMarkedRead(subscriptionKey, data, callbacks)
      break
    case "notification_dismissed":
      this.handleNotificationDismissed(subscriptionKey, data, callbacks)
      break
    case "preferences_updated":
      this.handlePreferencesUpdated(subscriptionKey, data, callbacks)
      break
    case "batch_notifications":
      this.handleBatchNotifications(subscriptionKey, data, callbacks)
      break
    case "unread_notifications":
      this.handleUnreadNotifications(subscriptionKey, data, callbacks)
      break
    case "notification_history":
      this.handleNotificationHistory(subscriptionKey, data, callbacks)
      break
    case "typing_started":
    case "typing_stopped":
      this.handleTypingIndicator(subscriptionKey, data, callbacks)
      break
    case "user_joined":
    case "user_left":
      this.handleUserPresence(subscriptionKey, data, callbacks)
      break
    case "collaboration_invitation":
      this.handleCollaborationInvitation(subscriptionKey, data, callbacks)
      break
    case "user_mention":
      this.handleUserMention(subscriptionKey, data, callbacks)
      break
    case "document_shared":
      this.handleDocumentShared(subscriptionKey, data, callbacks)
      break
    case "system_maintenance":
    case "system_error":
    case "feature_announcement":
      this.handleSystemNotification(subscriptionKey, data, callbacks)
      break
    case "task_assigned":
    case "code_review_requested":
    case "workflow_update":
      this.handleWorkflowNotification(subscriptionKey, data, callbacks)
      break
    default:
      console.warn(`Unknown notification type: ${type}`, data)
      if (callbacks.onUnknownNotification) {
        callbacks.onUnknownNotification(subscriptionKey, data)
      } else if (callbacks.onNotificationReceived) {
        // Fallback to generic notification handler
        callbacks.onNotificationReceived(subscriptionKey, data)
      }
    }
  }

  // Specific message handlers
  handleNotificationMarkedRead(subscriptionKey, data, callbacks) {
    if (callbacks.onNotificationMarkedRead) {
      callbacks.onNotificationMarkedRead(subscriptionKey, data.notification_id, data)
    }
  }

  handleNotificationDismissed(subscriptionKey, data, callbacks) {
    if (callbacks.onNotificationDismissed) {
      callbacks.onNotificationDismissed(subscriptionKey, data.notification_id, data)
    }
  }

  handlePreferencesUpdated(subscriptionKey, data, callbacks) {
    if (callbacks.onPreferencesUpdated) {
      callbacks.onPreferencesUpdated(subscriptionKey, data.preferences, data)
    }
  }

  handleBatchNotifications(subscriptionKey, data, callbacks) {
    if (callbacks.onBatchNotifications) {
      callbacks.onBatchNotifications(subscriptionKey, data.notifications, data)
    }
    
    // Also trigger individual notification handlers
    if (callbacks.onNotificationReceived) {
      data.notifications.forEach(notification => {
        callbacks.onNotificationReceived(subscriptionKey, notification)
      })
    }
  }

  handleUnreadNotifications(subscriptionKey, data, callbacks) {
    if (callbacks.onUnreadNotifications) {
      callbacks.onUnreadNotifications(subscriptionKey, data.notifications, data.count, data)
    }
  }

  handleNotificationHistory(subscriptionKey, data, callbacks) {
    if (callbacks.onNotificationHistory) {
      callbacks.onNotificationHistory(subscriptionKey, data.notifications, data.days, data)
    }
  }

  handleTypingIndicator(subscriptionKey, data, callbacks) {
    if (callbacks.onTypingIndicator) {
      callbacks.onTypingIndicator(subscriptionKey, data.type, data.user_id, data.user_name, data)
    }
  }

  handleUserPresence(subscriptionKey, data, callbacks) {
    if (callbacks.onUserPresence) {
      callbacks.onUserPresence(subscriptionKey, data.type, data.user_id, data.user_name, data)
    }
  }

  handleCollaborationInvitation(subscriptionKey, data, callbacks) {
    if (callbacks.onCollaborationInvitation) {
      callbacks.onCollaborationInvitation(subscriptionKey, data)
    }
    this.handleGenericNotification(subscriptionKey, data, callbacks)
  }

  handleUserMention(subscriptionKey, data, callbacks) {
    if (callbacks.onUserMention) {
      callbacks.onUserMention(subscriptionKey, data)
    }
    this.handleGenericNotification(subscriptionKey, data, callbacks)
  }

  handleDocumentShared(subscriptionKey, data, callbacks) {
    if (callbacks.onDocumentShared) {
      callbacks.onDocumentShared(subscriptionKey, data)
    }
    this.handleGenericNotification(subscriptionKey, data, callbacks)
  }

  handleSystemNotification(subscriptionKey, data, callbacks) {
    if (callbacks.onSystemNotification) {
      callbacks.onSystemNotification(subscriptionKey, data)
    }
    this.handleGenericNotification(subscriptionKey, data, callbacks)
  }

  handleWorkflowNotification(subscriptionKey, data, callbacks) {
    if (callbacks.onWorkflowNotification) {
      callbacks.onWorkflowNotification(subscriptionKey, data)
    }
    this.handleGenericNotification(subscriptionKey, data, callbacks)
  }

  handleGenericNotification(subscriptionKey, data, callbacks) {
    if (callbacks.onNotificationReceived) {
      callbacks.onNotificationReceived(subscriptionKey, data)
    }
  }

  // Utility methods
  isSubscribed(subscriptionKey) {
    return this.subscriptions.has(subscriptionKey)
  }

  getSubscription(subscriptionKey) {
    return this.subscriptions.get(subscriptionKey)
  }

  getActiveSubscriptions() {
    return Array.from(this.subscriptions.keys())
  }

  unsubscribeAll() {
    for (const subscriptionKey of this.subscriptions.keys()) {
      this.unsubscribe(subscriptionKey)
    }
  }

  // Convenience methods for typing indicators
  startTyping(documentId, userId, userName) {
    const subscriptionKey = `document_${documentId}`
    if (this.isSubscribed(subscriptionKey)) {
      this.broadcastTyping(subscriptionKey, {
        type: "typing_started",
        user_id: userId,
        user_name: userName
      })
    }
  }

  stopTyping(documentId, userId, userName) {
    const subscriptionKey = `document_${documentId}`
    if (this.isSubscribed(subscriptionKey)) {
      this.broadcastTyping(subscriptionKey, {
        type: "typing_stopped",
        user_id: userId,
        user_name: userName
      })
    }
  }

  // Static factory methods for convenience
  static createGlobal(callbacks = {}) {
    const channel = new NotificationChannel()
    return channel.subscribeToGlobal(callbacks)
  }

  static createForUser(userId, callbacks = {}) {
    const channel = new NotificationChannel()
    return channel.subscribeToUser(userId, callbacks)
  }

  static createForDocument(documentId, callbacks = {}) {
    const channel = new NotificationChannel()
    return channel.subscribeToDocument(documentId, callbacks)
  }
}

// Export singleton instance
const notificationChannel = new NotificationChannel()
export default notificationChannel

// Also export the class for testing
export { NotificationChannel }