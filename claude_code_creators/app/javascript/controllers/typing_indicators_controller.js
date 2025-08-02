/**
 * TypingIndicatorsController - Manages real-time typing indicators and user awareness
 * Shows who is currently typing and provides smooth visual feedback
 */

import { Controller } from "@hotwired/stimulus"
import { throttle, debounce } from "throttle-debounce"

export default class extends Controller {
  static targets = [
    "container", "avatarsContainer", "typingText", "animation",
    "avatarTemplate"
  ]

  static values = {
    documentId: Number,
    currentUserId: Number,
    maxVisible: { type: Number, default: 3 },
    showAvatars: { type: Boolean, default: true },
    style: { type: String, default: "compact" },
    animationStyle: { type: String, default: "pulse" }
  }

  static classes = [
    "typing", "typingActive", "typingFading", "userBadge", 
    "avatar", "overflow", "compact"
  ]

  connect() {
    // Typing state management
    this.typingUsers = new Map() // userId -> user data with timestamp
    this.fadeTimers = new Map() // userId -> setTimeout id
    this.isCurrentUserTyping = false

    // Animation state
    this.animationQueue = []
    this.isAnimating = false

    // Throttled update function
    this.throttledUpdate = throttle(100, this.updateDisplay.bind(this))
    this.debouncedCleanup = debounce(5000, this.cleanupStaleUsers.bind(this))

    // Setup event listeners
    this.setupEventListeners()

    // Hide container initially
    this.element.style.display = "none"

    console.log("TypingIndicatorsController connected")
  }

  disconnect() {
    this.cleanup()
    console.log("TypingIndicatorsController disconnected")
  }

  setupEventListeners() {
    // Listen for collaboration events
    this.element.addEventListener("collaboration:typing:started", this.handleTypingStarted.bind(this))
    this.element.addEventListener("collaboration:typing:stopped", this.handleTypingStopped.bind(this))
    this.element.addEventListener("collaboration:user:joined", this.handleUserJoined.bind(this))
    this.element.addEventListener("collaboration:user:left", this.handleUserLeft.bind(this))
    
    // Listen for notification channel events
    this.element.addEventListener("notification:typing:indicator", this.handleTypingNotification.bind(this))
  }

  // User typing management
  addTypingUser(userId, userData) {
    if (userId === this.currentUserIdValue) {
      this.isCurrentUserTyping = true
      return // Don't show current user as typing
    }

    const user = {
      id: userId,
      name: userData.name || userData.user_name || `User ${userId}`,
      avatar: userData.avatar_url || this.generateAvatarUrl(userId),
      color: userData.color || this.generateUserColor(userId),
      timestamp: Date.now(),
      ...userData
    }

    // Clear existing fade timer
    this.clearFadeTimer(userId)

    // Add or update user
    this.typingUsers.set(userId, user)
    
    // Update display
    this.throttledUpdate()
    
    // Set fade timer
    this.setFadeTimer(userId)

    this.dispatch("typing:user:added", { detail: { user } })
  }

  removeTypingUser(userId) {
    if (userId === this.currentUserIdValue) {
      this.isCurrentUserTyping = false
      return
    }

    const user = this.typingUsers.get(userId)
    if (user) {
      // Clear fade timer
      this.clearFadeTimer(userId)
      
      // Remove user with animation
      this.animateUserRemoval(userId)
      
      // Remove from map
      this.typingUsers.delete(userId)
      
      // Update display after animation
      setTimeout(() => {
        this.throttledUpdate()
      }, this.animationDurationValue)

      this.dispatch("typing:user:removed", { detail: { userId, user } })
    }
  }

  updateTypingUser(userId, userData) {
    if (this.typingUsers.has(userId)) {
      const existingUser = this.typingUsers.get(userId)
      const updatedUser = {
        ...existingUser,
        ...userData,
        timestamp: Date.now()
      }
      
      this.typingUsers.set(userId, updatedUser)
      this.throttledUpdate()
      
      // Reset fade timer
      this.clearFadeTimer(userId)
      this.setFadeTimer(userId)
    }
  }

  // Timer management
  setFadeTimer(userId) {
    const timer = setTimeout(() => {
      this.fadeUser(userId)
    }, this.fadeDelayValue)
    
    this.fadeTimers.set(userId, timer)
  }

  clearFadeTimer(userId) {
    const timer = this.fadeTimers.get(userId)
    if (timer) {
      clearTimeout(timer)
      this.fadeTimers.delete(userId)
    }
  }

  fadeUser(userId) {
    const userElement = this.element.querySelector(`[data-user-id="${userId}"]`)
    if (userElement) {
      userElement.classList.add(this.typingFadingClass)
      
      setTimeout(() => {
        this.removeTypingUser(userId)
      }, this.animationDurationValue)
    }
    
    this.fadeTimers.delete(userId)
  }

  cleanupStaleUsers() {
    const now = Date.now()
    const staleThreshold = 10000 // 10 seconds
    
    this.typingUsers.forEach((user, userId) => {
      if (now - user.timestamp > staleThreshold) {
        console.log(`Removing stale typing user: ${user.name}`)
        this.removeTypingUser(userId)
      }
    })
  }

  // Display management
  updateDisplay() {
    if (this.isAnimating) {
      this.animationQueue.push(() => this.updateDisplay())
      return
    }

    const typingUsers = Array.from(this.typingUsers.values())
    const visibleUsers = typingUsers.slice(0, this.maxVisibleValue)
    const overflowCount = Math.max(0, typingUsers.length - this.maxVisibleValue)

    this.updateAvatars(visibleUsers, overflowCount)
    this.updateTypingMessage(visibleUsers, overflowCount)
    this.updateContainerVisibility(typingUsers.length > 0)

    // Trigger cleanup check
    this.debouncedCleanup()
  }

  updateAvatars(visibleUsers, overflowCount) {
    if (!this.showAvatarsValue || !this.hasAvatarsContainerTarget) return

    const container = this.avatarsContainerTarget
    container.innerHTML = ""

    // Add visible users
    visibleUsers.forEach(user => {
      const avatarElement = this.createAvatarElement(user)
      container.appendChild(avatarElement)
    })

    // Add overflow indicator
    if (overflowCount > 0) {
      const overflowElement = this.createOverflowElement(overflowCount)
      container.appendChild(overflowElement)
    }
  }

  createAvatarElement(user) {
    if (!this.hasAvatarTemplateTarget) {
      // Fallback if no template
      const element = document.createElement("div")
      element.className = "typing-avatar"
      element.dataset.userId = user.id
      element.dataset.userName = user.name
      element.textContent = this.getUserInitials(user.name)
      return element
    }

    const template = this.avatarTemplateTarget
    const element = template.content.cloneNode(true).firstElementChild
    
    // Set user data
    element.dataset.userId = user.id
    element.dataset.userName = user.name
    
    // Apply user color
    element.classList.remove("avatar-color-placeholder")
    element.classList.add(this.getUserColorClass(user.color))
    
    // Set initials
    const initialsElement = element.querySelector(".avatar-initials")
    if (initialsElement) {
      initialsElement.textContent = this.getUserInitials(user.name)
    }
    
    return element
  }

  createOverflowElement(count) {
    const element = document.createElement("div")
    element.className = `typing-overflow ${this.overflowClass}`
    element.innerHTML = `
      <span class="overflow-count">+${count}</span>
      <span class="overflow-text">more</span>
    `
    element.title = `${count} more user${count === 1 ? "" : "s"} typing...`
    
    return element
  }

  updateTypingMessage(visibleUsers, overflowCount) {
    if (!this.hasTypingTextTarget) return

    const totalUsers = visibleUsers.length + overflowCount
    let message = ""

    if (totalUsers === 0) {
      message = ""
    } else if (totalUsers === 1) {
      message = `${visibleUsers[0].name} is typing...`
    } else if (totalUsers === 2) {
      if (overflowCount === 0) {
        message = `${visibleUsers[0].name} and ${visibleUsers[1].name} are typing...`
      } else {
        message = `${visibleUsers[0].name} and 1 other are typing...`
      }
    } else {
      const displayedName = visibleUsers[0].name
      const otherCount = totalUsers - 1
      message = `${displayedName} and ${otherCount} others are typing...`
    }

    this.typingTextTarget.textContent = message
  }

  updateContainerVisibility(hasTypingUsers) {
    if (hasTypingUsers) {
      this.element.style.display = "block"
      this.element.setAttribute("aria-hidden", "false")
    } else {
      // Hide after animation
      setTimeout(() => {
        if (this.typingUsers.size === 0) {
          this.element.style.display = "none"
          this.element.setAttribute("aria-hidden", "true")
        }
      }, 300)
    }
  }

  // Animation management
  animateUserRemoval(userId) {
    const userElement = this.element.querySelector(`[data-user-id="${userId}"]`)
    if (userElement) {
      this.isAnimating = true
      
      userElement.style.transition = `all ${this.animationDurationValue}ms ease-out`
      userElement.style.opacity = "0"
      userElement.style.transform = "scale(0.8)"
      
      setTimeout(() => {
        userElement.remove()
        this.isAnimating = false
        this.processAnimationQueue()
      }, this.animationDurationValue)
    }
  }

  processAnimationQueue() {
    if (this.animationQueue.length > 0) {
      const nextAnimation = this.animationQueue.shift()
      nextAnimation()
    }
  }

  // Event handlers
  handleTypingStarted(event) {
    const { userId, userName, userAvatar } = event.detail
    this.addTypingUser(userId, {
      name: userName,
      avatar_url: userAvatar
    })
  }

  handleTypingStopped(event) {
    const { userId } = event.detail
    this.removeTypingUser(userId)
  }

  handleUserJoined(event) {
    const { user } = event.detail
    // User joined but not necessarily typing yet
    // Could be used to preload user data
  }

  handleUserLeft(event) {
    const { userId } = event.detail
    this.removeTypingUser(userId)
  }

  handleTypingNotification(event) {
    const { type, user_id, user_name, user_avatar } = event.detail

    switch (type) {
    case "typing_started":
      this.addTypingUser(user_id, {
        name: user_name,
        avatar_url: user_avatar
      })
      break
    case "typing_stopped":
      this.removeTypingUser(user_id)
      break
    }
  }

  // Utility methods
  generateUserColor(userId) {
    const colors = [
      "#ef4444", "#f97316", "#eab308", "#22c55e",
      "#06b6d4", "#3b82f6", "#8b5cf6", "#ec4899"
    ]
    
    return colors[userId % colors.length]
  }

  generateAvatarUrl(userId) {
    // Generate a default avatar URL (could use services like Gravatar, Identicon, etc.)
    return `https://ui-avatars.com/api/?name=User+${userId}&background=random&size=32`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  getUserInitials(name) {
    return name.split(" ").map(word => word[0]).join("").toUpperCase().substring(0, 2)
  }

  getUserColorClass(color) {
    const colorMap = {
      "#ef4444": "bg-creative-accent-rose text-white",
      "#f97316": "bg-creative-accent-orange text-white", 
      "#eab308": "bg-creative-accent-amber text-white",
      "#22c55e": "bg-creative-accent-teal text-white",
      "#06b6d4": "bg-creative-accent-teal text-white",
      "#3b82f6": "bg-creative-primary-500 text-white",
      "#8b5cf6": "bg-creative-accent-purple text-white",
      "#ec4899": "bg-creative-accent-rose text-white"
    }
    
    return colorMap[color] || "bg-creative-primary-500 text-white"
  }

  // Public API methods
  getTypingUsers() {
    return Array.from(this.typingUsers.values())
  }

  getTypingUserCount() {
    return this.typingUsers.size
  }

  isUserTyping(userId) {
    return this.typingUsers.has(userId)
  }

  isCurrentUserTyping() {
    return this.isCurrentUserTyping
  }

  hasAnyTypingUsers() {
    return this.typingUsers.size > 0
  }

  // Manual control methods (for external integration)
  startTypingForUser(userId, userData) {
    this.addTypingUser(userId, userData)
  }

  stopTypingForUser(userId) {
    this.removeTypingUser(userId)
  }

  clearAllTypingUsers() {
    // Clear all timers
    this.fadeTimers.forEach(timer => clearTimeout(timer))
    this.fadeTimers.clear()
    
    // Clear users
    this.typingUsers.clear()
    
    // Update display
    this.updateDisplay()
  }

  // Configuration methods
  setCompactMode(enabled) {
    this.compactModeValue = enabled
    if (enabled) {
      this.element.classList.add(this.compactClass)
    } else {
      this.element.classList.remove(this.compactClass)
    }
    this.updateDisplay()
  }

  setMaxVisibleUsers(count) {
    this.maxVisibleUsersValue = Math.max(1, count)
    this.updateDisplay()
  }

  setShowAvatars(enabled) {
    this.showAvatarsValue = enabled
    this.updateDisplay()
  }

  setShowNames(enabled) {
    this.showNamesValue = enabled
    this.updateDisplay()
  }

  // Cleanup
  cleanup() {
    // Clear all timers
    this.fadeTimers.forEach(timer => clearTimeout(timer))
    this.fadeTimers.clear()
    
    // Clear data
    this.typingUsers.clear()
    this.animationQueue = []
    
    // Reset state
    this.isAnimating = false
    this.isCurrentUserTyping = false
  }
}