import consumer from "./consumer"

class PresenceChannel {
  constructor(documentId, userId, callbacks = {}) {
    this.documentId = documentId
    this.userId = userId
    this.callbacks = callbacks
    this.subscription = null
    this.typingTimeout = null
    this.cursorUpdateThrottle = null
    this.isTyping = false
    
    this.connect()
  }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { 
        channel: "PresenceChannel", 
        document_id: this.documentId 
      },
      {
        connected: () => {
          console.log(`Connected to presence channel for document ${this.documentId}`)
          this.callbacks.onConnected?.()
          
          // Request current presence data
          this.getPresence()
        },

        disconnected: () => {
          console.log(`Disconnected from presence channel for document ${this.documentId}`)
          this.callbacks.onDisconnected?.()
        },

        received: (data) => {
          this.handlePresenceUpdate(data)
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
    
    if (this.cursorUpdateThrottle) {
      clearTimeout(this.cursorUpdateThrottle)
    }
  }

  // Handle incoming presence updates
  handlePresenceUpdate(data) {
    // Don't process updates from the current user
    if (data.user_id === this.userId) {
      return
    }

    switch (data.type) {
    case "user_joined":
      this.callbacks.onUserJoined?.(data.user)
      break
        
    case "user_left":
      this.callbacks.onUserLeft?.(data.user_id)
      break
        
    case "user_typing":
      this.callbacks.onUserTyping?.(data.user_id, data.user_name)
      break
        
    case "user_stopped_typing":
      this.callbacks.onUserStoppedTyping?.(data.user_id)
      break
        
    case "cursor_moved":
      this.callbacks.onCursorMoved?.(data.user_id, data.user_name, data.position)
      break
        
    case "selection_changed":
      this.callbacks.onSelectionChanged?.(data.user_id, data.user_name, data.selection)
      break
        
    case "presence_data":
      this.callbacks.onPresenceData?.(data.users, data.cursors, data.typing_users)
      break
        
    default:
      console.log("Unknown presence update:", data)
    }
  }

  // Send typing indicator
  startTyping() {
    if (!this.isTyping) {
      this.isTyping = true
      this.perform("user_typing")
    }

    // Clear existing timeout
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }

    // Set timeout to stop typing after 3 seconds of inactivity
    this.typingTimeout = setTimeout(() => {
      this.stopTyping()
    }, 3000)
  }

  // Stop typing indicator
  stopTyping() {
    if (this.isTyping) {
      this.isTyping = false
      this.perform("user_stopped_typing")
      
      if (this.typingTimeout) {
        clearTimeout(this.typingTimeout)
        this.typingTimeout = null
      }
    }
  }

  // Update cursor position (throttled)
  updateCursor(x, y) {
    if (this.cursorUpdateThrottle) {
      return // Still throttling
    }

    this.perform("cursor_moved", {
      position: { x, y }
    })

    // Throttle cursor updates to avoid spam
    this.cursorUpdateThrottle = setTimeout(() => {
      this.cursorUpdateThrottle = null
    }, 100) // 100ms throttle
  }

  // Update text selection
  updateSelection(selection) {
    this.perform("selection_changed", {
      selection: selection
    })
  }

  // Get current presence data
  getPresence() {
    this.perform("get_presence")
  }

  // Helper method to perform actions
  perform(action, data = {}) {
    if (this.subscription) {
      this.subscription.perform(action, data)
    }
  }

  // Static method to create and manage presence channels
  static channels = new Map()

  static create(documentId, userId, callbacks = {}) {
    const channelKey = `${documentId}-${userId}`
    
    // Disconnect existing channel if it exists
    if (this.channels.has(channelKey)) {
      this.channels.get(channelKey).disconnect()
    }

    // Create new channel
    const channel = new PresenceChannel(documentId, userId, callbacks)
    this.channels.set(channelKey, channel)
    
    return channel
  }

  static disconnect(documentId, userId) {
    const channelKey = `${documentId}-${userId}`
    
    if (this.channels.has(channelKey)) {
      this.channels.get(channelKey).disconnect()
      this.channels.delete(channelKey)
    }
  }

  static disconnectAll() {
    this.channels.forEach(channel => channel.disconnect())
    this.channels.clear()
  }
}

// Export for use in Stimulus controllers
export default PresenceChannel

// Also add to window for global access
window.PresenceChannel = PresenceChannel

// Cleanup on page unload
window.addEventListener("beforeunload", () => {
  PresenceChannel.disconnectAll()
})