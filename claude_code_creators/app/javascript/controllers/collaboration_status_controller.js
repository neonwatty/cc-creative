/**
 * CollaborationStatusController - Manages and displays collaboration connection status
 * Shows connection quality, sync status, active users, and system notifications
 */

import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

export default class extends Controller {
  static targets = [
    "container", "statusIndicator", "statusText", "connectionQuality",
    "signalBars", "qualityText", "syncStatus", "syncIcon", "syncText",
    "lastSave", "lastSaveText", "usersInfo", "activeUsersCount",
    "notificationToast", "notificationIcon", "notificationTitle",
    "notificationMessage", "notificationClose"
  ]

  static values = {
    documentId: Number,
    currentUserId: Number,
    position: { type: String, default: "top_right" },
    style: { type: String, default: "compact" },
    showConnectionQuality: { type: Boolean, default: true },
    showSyncStatus: { type: Boolean, default: true },
    showLastSave: { type: Boolean, default: true },
    autoHide: { type: Boolean, default: false },
    hideDelay: { type: Number, default: 5000 }
  }

  static classes = [
    "connected", "connecting", "disconnected", "syncing", "error",
    "qualityExcellent", "qualityGood", "qualityFair", "qualityPoor",
    "toast", "toastShow", "toastHide"
  ]

  connect() {
    // Connection state
    this.connectionStatus = "connecting"
    this.connectionQuality = "unknown"
    this.syncStatus = "idle"
    this.lastSaveTime = null
    this.activeUsers = new Set()
    
    // Notification system
    this.notificationQueue = []
    this.isShowingNotification = false
    
    // Timers
    this.autoHideTimer = null
    this.lastSaveUpdateTimer = null
    this.connectionCheckTimer = null
    
    // Debounced functions
    this.debouncedUpdateDisplay = debounce(100, this.updateDisplay.bind(this))
    this.debouncedHideToast = debounce(3000, this.hideNotificationToast.bind(this))
    
    // Setup event listeners
    this.setupEventListeners()
    this.startConnectionMonitoring()
    this.startLastSaveUpdates()
    
    // Initial state
    this.updateDisplay()
    
    console.log("CollaborationStatusController connected")
  }

  disconnect() {
    this.cleanup()
    console.log("CollaborationStatusController disconnected")
  }

  setupEventListeners() {
    // Collaboration events
    this.element.addEventListener("collaboration:connected", this.handleConnected.bind(this))
    this.element.addEventListener("collaboration:disconnected", this.handleDisconnected.bind(this))
    this.element.addEventListener("collaboration:reconnecting", this.handleReconnecting.bind(this))
    this.element.addEventListener("collaboration:error", this.handleError.bind(this))
    
    // Sync events
    this.element.addEventListener("collaboration:sync:started", this.handleSyncStarted.bind(this))
    this.element.addEventListener("collaboration:sync:completed", this.handleSyncCompleted.bind(this))
    this.element.addEventListener("collaboration:sync:failed", this.handleSyncFailed.bind(this))
    this.element.addEventListener("collaboration:save:completed", this.handleSaveCompleted.bind(this))
    
    // User events
    this.element.addEventListener("collaboration:user:joined", this.handleUserJoined.bind(this))
    this.element.addEventListener("collaboration:user:left", this.handleUserLeft.bind(this))
    this.element.addEventListener("collaboration:users:updated", this.handleUsersUpdated.bind(this))
    
    // Quality monitoring
    this.element.addEventListener("collaboration:quality:changed", this.handleQualityChanged.bind(this))
    this.element.addEventListener("collaboration:latency:updated", this.handleLatencyUpdated.bind(this))
    
    // Notification events
    this.element.addEventListener("collaboration:notification", this.handleNotification.bind(this))
    
    // Mouse activity (for auto-hide)
    if (this.autoHideValue) {
      this.element.addEventListener("mouseenter", this.handleMouseEnter.bind(this))
      this.element.addEventListener("mouseleave", this.handleMouseLeave.bind(this))
    }
  }

  startConnectionMonitoring() {
    // Monitor connection every 30 seconds
    this.connectionCheckTimer = setInterval(() => {
      this.checkConnectionQuality()
    }, 30000)
    
    // Initial check
    this.checkConnectionQuality()
  }

  startLastSaveUpdates() {
    // Update "last saved" text every 30 seconds
    this.lastSaveUpdateTimer = setInterval(() => {
      this.updateLastSaveDisplay()
    }, 30000)
  }

  checkConnectionQuality() {
    // Simulate connection quality check
    // In a real implementation, this would measure latency, packet loss, etc.
    const startTime = Date.now()
    
    // Ping the server
    this.dispatch("connection:ping", { 
      detail: { 
        startTime,
        callback: this.handlePingResponse.bind(this)
      } 
    })
  }

  handlePingResponse(latency) {
    let quality = "unknown"
    
    if (latency < 100) {
      quality = "excellent"
    } else if (latency < 300) {
      quality = "good"
    } else if (latency < 800) {
      quality = "fair"
    } else {
      quality = "poor"
    }
    
    this.updateConnectionQuality(quality, latency)
  }

  // Connection status management
  updateConnectionStatus(status) {
    const previousStatus = this.connectionStatus
    this.connectionStatus = status
    
    this.debouncedUpdateDisplay()
    
    if (previousStatus !== status) {
      this.showStatusNotification(status)
      this.dispatch("status:changed", { 
        detail: { 
          status, 
          previousStatus 
        } 
      })
    }
  }

  updateConnectionQuality(quality, latency = null) {
    const previousQuality = this.connectionQuality
    this.connectionQuality = quality
    this.latency = latency
    
    if (this.showConnectionQualityValue) {
      this.debouncedUpdateDisplay()
    }
    
    if (previousQuality !== quality) {
      this.dispatch("quality:changed", { 
        detail: { 
          quality, 
          latency,
          previousQuality 
        } 
      })
    }
  }

  updateSyncStatus(status) {
    const previousStatus = this.syncStatus
    this.syncStatus = status
    
    if (this.showSyncStatusValue) {
      this.debouncedUpdateDisplay()
    }
    
    if (previousStatus !== status) {
      this.dispatch("sync:status:changed", { 
        detail: { 
          status, 
          previousStatus 
        } 
      })
    }
  }

  updateLastSave(timestamp = null) {
    this.lastSaveTime = timestamp || Date.now()
    
    if (this.showLastSaveValue) {
      this.updateLastSaveDisplay()
    }
  }

  updateActiveUsers(users) {
    this.activeUsers = new Set(users.map(user => user.id))
    this.debouncedUpdateDisplay()
  }

  // Display updates
  updateDisplay() {
    this.updateStatusIndicator()
    this.updateStatusText()
    this.updateConnectionQualityDisplay()
    this.updateSyncStatusDisplay()
    this.updateUsersDisplay()
    this.updateAutoHide()
  }

  updateStatusIndicator() {
    if (!this.hasStatusIndicatorTarget) return
    
    const indicator = this.statusIndicatorTarget
    
    // Remove all status classes
    const statusClasses = [
      this.connectedClass,
      this.connectingClass,
      this.disconnectedClass,
      this.syncingClass,
      this.errorClass
    ].filter(Boolean)
    
    indicator.classList.remove(...statusClasses)
    
    // Add current status class
    const statusClass = this[`${this.connectionStatus}Class`]
    if (statusClass) {
      indicator.classList.add(statusClass)
    }
  }

  updateStatusText() {
    if (!this.hasStatusTextTarget) return
    
    const statusMessages = {
      connected: "Connected",
      connecting: "Connecting...",
      disconnected: "Disconnected",
      syncing: "Syncing...",
      error: "Connection Error"
    }
    
    this.statusTextTarget.textContent = statusMessages[this.connectionStatus] || "Unknown"
  }

  updateConnectionQualityDisplay() {
    if (!this.showConnectionQualityValue || !this.hasSignalBarsTarget) return
    
    const signalBars = this.signalBarsTarget.querySelectorAll("[data-signal-level]")
    const qualityLevels = {
      excellent: 4,
      good: 3,
      fair: 2,
      poor: 1,
      unknown: 0
    }
    
    const activeLevel = qualityLevels[this.connectionQuality] || 0
    
    signalBars.forEach((bar, index) => {
      const level = parseInt(bar.dataset.signalLevel)
      bar.style.opacity = level <= activeLevel ? "1" : "0.3"
    })
    
    // Update quality text
    if (this.hasQualityTextTarget) {
      const qualityTexts = {
        excellent: "Excellent",
        good: "Good",
        fair: "Fair",
        poor: "Poor",
        unknown: "Unknown"
      }
      
      this.qualityTextTarget.textContent = qualityTexts[this.connectionQuality]
      
      if (this.latency) {
        this.qualityTextTarget.textContent += ` (${this.latency}ms)`
      }
    }
  }

  updateSyncStatusDisplay() {
    if (!this.showSyncStatusValue) return
    
    if (this.hasSyncIconTarget) {
      const syncIcon = this.syncIconTarget
      
      // Update icon based on sync status
      if (this.syncStatus === "syncing") {
        syncIcon.classList.add("animate-spin")
      } else {
        syncIcon.classList.remove("animate-spin")
      }
    }
    
    if (this.hasSyncTextTarget) {
      const syncTexts = {
        idle: "Saved",
        syncing: "Syncing...",
        saving: "Saving...",
        error: "Sync Error"
      }
      
      this.syncTextTarget.textContent = syncTexts[this.syncStatus] || "Unknown"
    }
  }

  updateLastSaveDisplay() {
    if (!this.showLastSaveValue || !this.hasLastSaveTextTarget) return
    
    if (this.lastSaveTime) {
      const timeAgo = this.formatTimeAgo(this.lastSaveTime)
      this.lastSaveTextTarget.textContent = timeAgo
    } else {
      this.lastSaveTextTarget.textContent = "Never"
    }
  }

  updateUsersDisplay() {
    if (this.hasActiveUsersCountTarget) {
      this.activeUsersCountTarget.textContent = this.activeUsers.size.toString()
    }
  }

  updateAutoHide() {
    if (!this.autoHideValue) return
    
    // Clear existing timer
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer)
    }
    
    // Set new timer
    this.autoHideTimer = setTimeout(() => {
      this.hideStatus()
    }, this.hideDelayValue)
  }

  // Event handlers
  handleConnected(event) {
    this.updateConnectionStatus("connected")
    this.showNotification("Connected", "Successfully connected to collaboration server", "success")
  }

  handleDisconnected(event) {
    this.updateConnectionStatus("disconnected")
    this.showNotification("Disconnected", "Lost connection to collaboration server", "warning")
  }

  handleReconnecting(event) {
    this.updateConnectionStatus("connecting")
    this.showNotification("Reconnecting", "Attempting to reconnect...", "info")
  }

  handleError(event) {
    const { error } = event.detail
    this.updateConnectionStatus("error")
    this.showNotification("Connection Error", error.message || "An error occurred", "error")
  }

  handleSyncStarted(event) {
    this.updateSyncStatus("syncing")
  }

  handleSyncCompleted(event) {
    this.updateSyncStatus("idle")
    this.updateLastSave()
  }

  handleSyncFailed(event) {
    this.updateSyncStatus("error")
    const { error } = event.detail
    this.showNotification("Sync Failed", error.message || "Failed to sync changes", "error")
  }

  handleSaveCompleted(event) {
    this.updateLastSave()
    this.updateSyncStatus("idle")
  }

  handleUserJoined(event) {
    const { user } = event.detail
    this.activeUsers.add(user.id)
    this.debouncedUpdateDisplay()
    
    if (user.id !== this.currentUserIdValue) {
      this.showNotification("User Joined", `${user.name} joined the document`, "info")
    }
  }

  handleUserLeft(event) {
    const { userId, userName } = event.detail
    this.activeUsers.delete(userId)
    this.debouncedUpdateDisplay()
    
    if (userId !== this.currentUserIdValue) {
      this.showNotification("User Left", `${userName} left the document`, "info")
    }
  }

  handleUsersUpdated(event) {
    const { users } = event.detail
    this.updateActiveUsers(users)
  }

  handleQualityChanged(event) {
    const { quality, latency } = event.detail
    this.updateConnectionQuality(quality, latency)
  }

  handleLatencyUpdated(event) {
    const { latency } = event.detail
    this.updateConnectionQuality(this.connectionQuality, latency)
  }

  handleNotification(event) {
    const { title, message, type } = event.detail
    this.showNotification(title, message, type)
  }

  handleMouseEnter() {
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer)
      this.autoHideTimer = null
    }
    this.showStatus()
  }

  handleMouseLeave() {
    if (this.autoHideValue) {
      this.updateAutoHide()
    }
  }

  // Auto-hide functionality
  showStatus() {
    if (this.hasContainerTarget) {
      this.containerTarget.style.opacity = "1"
      this.containerTarget.style.pointerEvents = "auto"
    }
  }

  hideStatus() {
    if (this.hasContainerTarget && this.autoHideValue) {
      this.containerTarget.style.opacity = "0.5"
      this.containerTarget.style.pointerEvents = "none"
    }
  }

  // Notification system
  showNotification(title, message, type = "info") {
    const notification = {
      title,
      message,
      type,
      timestamp: Date.now()
    }
    
    this.notificationQueue.push(notification)
    
    if (!this.isShowingNotification) {
      this.processNotificationQueue()
    }
  }

  processNotificationQueue() {
    if (this.notificationQueue.length === 0) {
      this.isShowingNotification = false
      return
    }
    
    const notification = this.notificationQueue.shift()
    this.displayNotification(notification)
  }

  displayNotification(notification) {
    if (!this.hasNotificationToastTarget) return
    
    this.isShowingNotification = true
    
    // Update notification content
    if (this.hasNotificationTitleTarget) {
      this.notificationTitleTarget.textContent = notification.title
    }
    
    if (this.hasNotificationMessageTarget) {
      this.notificationMessageTarget.textContent = notification.message
    }
    
    // Update notification icon
    if (this.hasNotificationIconTarget) {
      this.updateNotificationIcon(notification.type)
    }
    
    // Show notification
    this.showNotificationToast()
    
    // Auto-hide after delay
    this.debouncedHideToast()
  }

  updateNotificationIcon(type) {
    const iconSvgs = {
      success: "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z\"/>",
      error: "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z\"/>",
      warning: "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z\"/>",
      info: "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z\"/>"
    }
    
    const iconColors = {
      success: "text-creative-accent-teal",
      error: "text-creative-accent-rose",
      warning: "text-creative-accent-amber",
      info: "text-creative-primary-500"
    }
    
    this.notificationIconTarget.innerHTML = `
      <svg class="w-full h-full ${iconColors[type] || iconColors.info}" 
           fill="none" viewBox="0 0 24 24" stroke="currentColor">
        ${iconSvgs[type] || iconSvgs.info}
      </svg>
    `
  }

  showNotificationToast() {
    const toast = this.notificationToastTarget
    toast.classList.remove("translate-x-full", "opacity-0")
    toast.classList.add("translate-x-0", "opacity-100")
  }

  hideNotificationToast() {
    const toast = this.notificationToastTarget
    toast.classList.remove("translate-x-0", "opacity-100")
    toast.classList.add("translate-x-full", "opacity-0")
    
    setTimeout(() => {
      this.isShowingNotification = false
      this.processNotificationQueue()
    }, 300)
  }

  closeNotification() {
    this.hideNotificationToast()
  }

  // Utility methods
  formatTimeAgo(timestamp) {
    const now = Date.now()
    const diff = now - timestamp
    
    if (diff < 60000) { // Less than 1 minute
      return "Just now"
    } else if (diff < 3600000) { // Less than 1 hour
      const minutes = Math.floor(diff / 60000)
      return `${minutes} minute${minutes === 1 ? "" : "s"} ago`
    } else if (diff < 86400000) { // Less than 24 hours
      const hours = Math.floor(diff / 3600000)
      return `${hours} hour${hours === 1 ? "" : "s"} ago`
    } else {
      return new Date(timestamp).toLocaleDateString()
    }
  }

  showStatusNotification(status) {
    const statusMessages = {
      connected: {
        title: "Connected",
        message: "Successfully connected to collaboration server",
        type: "success"
      },
      disconnected: {
        title: "Disconnected", 
        message: "Lost connection to collaboration server",
        type: "warning"
      },
      connecting: {
        title: "Connecting",
        message: "Attempting to connect...",
        type: "info"
      },
      error: {
        title: "Connection Error",
        message: "Failed to connect to collaboration server",
        type: "error"
      }
    }
    
    const notification = statusMessages[status]
    if (notification) {
      this.showNotification(notification.title, notification.message, notification.type)
    }
  }

  // Public API
  getConnectionStatus() {
    return this.connectionStatus
  }

  getConnectionQuality() {
    return this.connectionQuality
  }

  getSyncStatus() {
    return this.syncStatus
  }

  getActiveUserCount() {
    return this.activeUsers.size
  }

  getLastSaveTime() {
    return this.lastSaveTime
  }

  // Manual control methods
  setConnectionStatus(status) {
    this.updateConnectionStatus(status)
  }

  setConnectionQuality(quality, latency = null) {
    this.updateConnectionQuality(quality, latency)
  }

  setSyncStatus(status) {
    this.updateSyncStatus(status)
  }

  // Configuration
  setAutoHide(enabled) {
    this.autoHideValue = enabled
    if (enabled) {
      this.updateAutoHide()
    } else {
      this.showStatus()
      if (this.autoHideTimer) {
        clearTimeout(this.autoHideTimer)
        this.autoHideTimer = null
      }
    }
  }

  setPosition(position) {
    this.positionValue = position
    // Would trigger CSS class updates for positioning
  }

  // Cleanup
  cleanup() {
    // Clear timers
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer)
    }
    if (this.lastSaveUpdateTimer) {
      clearInterval(this.lastSaveUpdateTimer)
    }
    if (this.connectionCheckTimer) {
      clearInterval(this.connectionCheckTimer)
    }
    
    // Clear state
    this.notificationQueue = []
    this.activeUsers.clear()
    this.isShowingNotification = false
  }
}