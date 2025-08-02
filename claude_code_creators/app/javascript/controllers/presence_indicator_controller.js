import { Controller } from "@hotwired/stimulus"
import PresenceChannel from "../channels/presence_channel"

// Connects to data-controller="presence-indicator"
export default class extends Controller {
  static targets = ["userAvatar", "avatar", "typingIndicator", "cursorsContainer", "cursorTemplate", "statusUpdates"]
  static values = { 
    currentUserId: Number,
    showCursors: Boolean,
    documentId: Number
  }

  connect() {
    this.cursors = new Map() // Store cursor elements by user ID
    this.typingTimers = new Map() // Store typing timeout timers
    this.users = new Map() // Store user data
    
    this.animatePresenceIndicators()
    
    if (this.documentIdValue) {
      this.subscribeToPresenceChannel()
    }
  }

  disconnect() {
    if (this.presenceChannel) {
      this.presenceChannel.disconnect()
    }
    
    // Clear all timers
    this.typingTimers.forEach(timer => clearTimeout(timer))
    this.typingTimers.clear()
  }

  // Animate presence indicators on load
  animatePresenceIndicators() {
    this.userAvatarTargets.forEach((avatar, index) => {
      avatar.style.opacity = "0"
      avatar.style.transform = "scale(0.8)"
      
      setTimeout(() => {
        avatar.style.transition = "opacity 300ms ease-out, transform 300ms ease-out"
        avatar.style.opacity = "1"
        avatar.style.transform = "scale(1)"
      }, index * 100)
    })
  }

  // Subscribe to presence channel for real-time updates
  subscribeToPresenceChannel() {
    this.presenceChannel = PresenceChannel.create(
      this.documentIdValue,
      this.currentUserIdValue,
      {
        onConnected: () => {
          console.log("Connected to presence channel")
        },

        onDisconnected: () => {
          console.log("Disconnected from presence channel")
        },

        onUserJoined: (user) => {
          this.addUser(user)
        },

        onUserLeft: (userId) => {
          this.removeUser(userId)
        },

        onUserTyping: (userId, userName) => {
          this.showTypingIndicator(userId)
        },

        onUserStoppedTyping: (userId) => {
          this.hideTypingIndicator(userId)
        },

        onCursorMoved: (userId, userName, position) => {
          if (this.showCursorsValue) {
            this.updateCursor(userId, position, userName)
          }
        },

        onPresenceData: (users, cursors, typingUsers) => {
          this.loadPresenceData(users, cursors, typingUsers)
        }
      }
    )
  }

  // Load initial presence data
  loadPresenceData(users, cursors, typingUsers) {
    // Clear existing data
    this.users.clear()
    this.cursors.clear()
    
    // Load users
    users.forEach(user => {
      this.users.set(user.id, user)
      if (typingUsers.includes(user.id)) {
        this.showTypingIndicator(user.id)
      }
    })
    
    // Load cursors
    if (this.showCursorsValue) {
      Object.entries(cursors).forEach(([userId, cursor]) => {
        this.updateCursor(parseInt(userId), cursor, this.users.get(parseInt(userId))?.name)
      })
    }
    
    // Trigger UI update
    this.requestPresenceUpdate()
  }

  // Add a new user to the presence indicators
  addUser(user) {
    // Store user data
    this.users.set(user.id, user)
    
    // Check if user already exists in DOM
    const existingAvatar = this.userAvatarTargets.find(
      avatar => avatar.dataset.userId === user.id.toString()
    )
    
    if (existingAvatar) return

    // Trigger UI update to add new user
    this.requestPresenceUpdate()
  }

  // Remove a user from presence indicators
  removeUser(userId) {
    // Remove from stored data
    this.users.delete(userId)
    
    const avatar = this.userAvatarTargets.find(
      avatar => avatar.dataset.userId === userId.toString()
    )
    
    if (avatar) {
      avatar.style.transition = "opacity 200ms ease-out, transform 200ms ease-out"
      avatar.style.opacity = "0"
      avatar.style.transform = "scale(0.8)"
      
      setTimeout(() => {
        this.requestPresenceUpdate()
      }, 200)
    }

    // Remove cursor if it exists
    this.removeCursor(userId)
  }

  // Show typing indicator for a user
  showTypingIndicator(userId) {
    const avatar = this.userAvatarTargets.find(
      avatar => avatar.dataset.userId === userId.toString()
    )
    
    if (avatar) {
      const indicator = avatar.querySelector("[data-presence-indicator-target=\"typingIndicator\"]")
      if (indicator) {
        indicator.style.display = "block"
      }
    }

    // Clear existing timer
    if (this.typingTimers.has(userId)) {
      clearTimeout(this.typingTimers.get(userId))
    }

    // Set timer to hide indicator after 3 seconds of inactivity
    const timer = setTimeout(() => {
      this.hideTypingIndicator(userId)
    }, 3000)

    this.typingTimers.set(userId, timer)
  }

  // Hide typing indicator for a user
  hideTypingIndicator(userId) {
    const avatar = this.userAvatarTargets.find(
      avatar => avatar.dataset.userId === userId.toString()
    )
    
    if (avatar) {
      const indicator = avatar.querySelector("[data-presence-indicator-target=\"typingIndicator\"]")
      if (indicator) {
        indicator.style.display = "none"
      }
    }

    // Clear timer
    if (this.typingTimers.has(userId)) {
      clearTimeout(this.typingTimers.get(userId))
      this.typingTimers.delete(userId)
    }
  }

  // Update cursor position for a user
  updateCursor(userId, position, userName) {
    if (!this.showCursorsValue || !this.hasCursorsContainerTarget) return

    let cursor = this.cursors.get(userId)
    
    if (!cursor) {
      cursor = this.createCursor(userId, userName)
      this.cursors.set(userId, cursor)
      this.cursorsContainerTarget.appendChild(cursor)
    }

    // Update cursor position
    cursor.style.left = `${position.x}px`
    cursor.style.top = `${position.y}px`
  }

  // Create a new cursor element
  createCursor(userId, userName) {
    const template = this.cursorTemplateTarget
    const cursor = template.content.cloneNode(true).firstElementChild
    
    cursor.dataset.cursorUserId = userId
    cursor.querySelector(".cursor-user-name").textContent = userName
    
    return cursor
  }

  // Remove cursor for a user
  removeCursor(userId) {
    const cursor = this.cursors.get(userId)
    if (cursor) {
      cursor.remove()
      this.cursors.delete(userId)
    }
  }

  // Request server-side presence update (triggers Turbo Stream)
  requestPresenceUpdate() {
    if (this.channelNameValue && window.App?.cable) {
      // This would trigger a server-side update to refresh the presence indicators
      // Implementation depends on your Action Cable setup
    }
  }

  // Broadcast typing status
  broadcastTyping() {
    if (this.presenceChannel) {
      this.presenceChannel.perform("user_typing")
    }
  }

  // Broadcast stopped typing
  broadcastStoppedTyping() {
    if (this.presenceChannel) {
      this.presenceChannel.perform("user_stopped_typing")
    }
  }

  // Broadcast cursor position
  broadcastCursorPosition(x, y) {
    if (this.presenceChannel && this.showCursorsValue) {
      this.presenceChannel.perform("cursor_moved", { x, y })
    }
  }
}