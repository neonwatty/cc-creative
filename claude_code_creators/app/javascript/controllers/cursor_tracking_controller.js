/**
 * CursorTrackingController - Manages real-time cursor tracking and visualization
 * Shows other users' cursor positions with smooth animations and collision detection
 */

import { Controller } from "@hotwired/stimulus"
import { throttle } from "throttle-debounce"

export default class extends Controller {
  static targets = [
    "cursorsContainer", "trailsContainer", "collisionOverlay",
    "cursorTemplate", "trailTemplate", "collisionTemplate"
  ]

  static values = {
    documentId: Number,
    currentUserId: Number,
    cursorStyle: { type: String, default: "default" },
    showLabels: { type: Boolean, default: true },
    showTrails: { type: Boolean, default: false },
    cursorTimeout: { type: Number, default: 5000 },
    smoothMovement: { type: Boolean, default: true },
    collisionDetection: { type: Boolean, default: true },
    containerSelector: { type: String, default: ".editor-content" }
  }

  static classes = [
    "cursor", "cursorActive", "cursorIdle", "trail", "collision"
  ]

  connect() {
    // Cursor management
    this.cursors = new Map() // userId -> cursor element
    this.cursorData = new Map() // userId -> cursor data
    this.cursorTimers = new Map() // userId -> timeout id
    
    // Trail management (if enabled)
    this.trails = new Map() // userId -> array of trail elements
    this.maxTrailLength = 10
    
    // Collision detection (if enabled)
    this.collisionZones = new Map() // collision id -> zone element
    this.collisionThreshold = 50 // pixels
    
    // Throttled functions
    this.throttledBroadcast = throttle(50, this.broadcastCursorPosition.bind(this))
    this.throttledCollisionCheck = throttle(100, this.checkCollisions.bind(this))
    
    // Setup event listeners
    this.setupEventListeners()
    this.setupContainerObserver()
    
    console.log("CursorTrackingController connected")
  }

  disconnect() {
    this.cleanup()
    console.log("CursorTrackingController disconnected")
  }

  setupEventListeners() {
    // Mouse movement tracking
    this.boundHandleMouseMove = this.handleMouseMove.bind(this)
    this.boundHandleMouseLeave = this.handleMouseLeave.bind(this)
    
    const container = this.getTrackingContainer()
    if (container) {
      container.addEventListener("mousemove", this.boundHandleMouseMove)
      container.addEventListener("mouseleave", this.boundHandleMouseLeave)
    }
    
    // Collaboration events
    this.element.addEventListener("collaboration:cursor:moved", this.handleCursorMoved.bind(this))
    this.element.addEventListener("collaboration:cursor:hidden", this.handleCursorHidden.bind(this))
    this.element.addEventListener("collaboration:user:joined", this.handleUserJoined.bind(this))
    this.element.addEventListener("collaboration:user:left", this.handleUserLeft.bind(this))
    
    // Window events
    window.addEventListener("resize", this.handleWindowResize.bind(this))
    window.addEventListener("scroll", this.handleWindowScroll.bind(this))
    
    // Focus events
    document.addEventListener("visibilitychange", this.handleVisibilityChange.bind(this))
  }

  setupContainerObserver() {
    if (!window.ResizeObserver) return
    
    const container = this.getTrackingContainer()
    if (container) {
      this.containerObserver = new ResizeObserver(() => {
        this.updateCursorPositions()
      })
      this.containerObserver.observe(container)
    }
  }

  getTrackingContainer() {
    return document.querySelector(this.containerSelectorValue) || this.element
  }

  // Cursor position tracking
  handleMouseMove(event) {
    if (!this.isInTrackingArea(event)) return
    
    const position = this.getRelativePosition(event)
    this.updateOwnCursorPosition(position)
    this.throttledBroadcast(position.x, position.y)
    
    if (this.collisionDetectionValue) {
      this.throttledCollisionCheck()
    }
  }

  handleMouseLeave(event) {
    this.hideOwnCursor()
    this.dispatch("cursor:hidden", { 
      detail: { userId: this.currentUserIdValue } 
    })
  }

  isInTrackingArea(event) {
    const container = this.getTrackingContainer()
    if (!container) return false
    
    const rect = container.getBoundingClientRect()
    return (
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom
    )
  }

  getRelativePosition(event) {
    const container = this.getTrackingContainer()
    const rect = container.getBoundingClientRect()
    
    return {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
      timestamp: Date.now()
    }
  }

  updateOwnCursorPosition(position) {
    // Update our own cursor position data (for collision detection)
    this.ownCursorPosition = position
  }

  hideOwnCursor() {
    this.ownCursorPosition = null
  }

  // Remote cursor management
  handleCursorMoved(event) {
    const { userId, position, userName, userColor } = event.detail
    
    if (userId === this.currentUserIdValue) return
    
    this.updateCursor(userId, position, userName, userColor)
    
    if (this.showTrailsValue) {
      this.addTrailPoint(userId, position, userColor)
    }
  }

  handleCursorHidden(event) {
    const { userId } = event.detail
    this.hideCursor(userId)
  }

  handleUserJoined(event) {
    const { user } = event.detail
    // Prepare for potential cursor updates
    this.initializeUserCursor(user.id, user)
  }

  handleUserLeft(event) {
    const { userId } = event.detail
    this.removeCursor(userId)
  }

  // Cursor element management
  updateCursor(userId, position, userName, userColor) {
    let cursor = this.cursors.get(userId)
    
    if (!cursor) {
      cursor = this.createCursor(userId, userName, userColor)
      this.cursors.set(userId, cursor)
      this.cursorsContainerTarget.appendChild(cursor)
    }
    
    // Update position with smooth animation
    this.animateCursorToPosition(cursor, position)
    
    // Update cursor data
    this.cursorData.set(userId, {
      position,
      userName,
      userColor,
      timestamp: Date.now()
    })
    
    // Reset timeout timer
    this.resetCursorTimer(userId)
  }

  createCursor(userId, userName, userColor) {
    const template = this.cursorTemplateTarget
    const cursor = template.content.cloneNode(true).firstElementChild
    
    // Set user data
    cursor.dataset.cursorUserId = userId
    cursor.dataset.cursorUserName = userName
    cursor.dataset.cursorLastActivity = Date.now()
    
    // Apply user color
    const colorClass = this.getUserColorClass(userColor)
    cursor.querySelector('svg').classList.add(colorClass)
    
    if (this.showLabelsValue) {
      const label = cursor.querySelector('.cursor-label')
      if (label) {
        label.classList.add(`cursor-bg-${this.getColorName(userColor)}`)
        cursor.querySelector('.cursor-user-name-placeholder').textContent = userName
      }
    }
    
    // Add entrance animation
    cursor.classList.add('entering')
    setTimeout(() => {
      cursor.classList.remove('entering')
    }, 200)
    
    return cursor
  }

  animateCursorToPosition(cursor, position) {
    if (this.smoothMovementValue) {
      cursor.style.transition = 'transform 150ms cubic-bezier(0.4, 0, 0.2, 1)'
    } else {
      cursor.style.transition = 'none'
    }
    
    cursor.style.transform = `translate(${position.x}px, ${position.y}px)`
  }

  hideCursor(userId) {
    const cursor = this.cursors.get(userId)
    if (cursor) {
      cursor.classList.add('leaving')
      setTimeout(() => {
        this.removeCursor(userId)
      }, 200)
    }
  }

  removeCursor(userId) {
    const cursor = this.cursors.get(userId)
    if (cursor) {
      cursor.remove()
      this.cursors.delete(userId)
    }
    
    this.cursorData.delete(userId)
    this.clearCursorTimer(userId)
    
    if (this.showTrailsValue) {
      this.clearTrails(userId)
    }
  }

  initializeUserCursor(userId, userData) {
    // Pre-initialize cursor data without showing cursor
    this.cursorData.set(userId, {
      userName: userData.name || `User ${userId}`,
      userColor: userData.color || this.generateUserColor(userId),
      position: null,
      timestamp: Date.now()
    })
  }

  // Timer management
  resetCursorTimer(userId) {
    this.clearCursorTimer(userId)
    
    const timer = setTimeout(() => {
      this.fadeCursor(userId)
    }, this.cursorTimeoutValue)
    
    this.cursorTimers.set(userId, timer)
  }

  clearCursorTimer(userId) {
    const timer = this.cursorTimers.get(userId)
    if (timer) {
      clearTimeout(timer)
      this.cursorTimers.delete(userId)
    }
  }

  fadeCursor(userId) {
    const cursor = this.cursors.get(userId)
    if (cursor) {
      cursor.classList.add('cursor-idle')
      
      // Remove after fade animation
      setTimeout(() => {
        this.removeCursor(userId)
      }, 1000)
    }
  }

  // Trail effects (if enabled)
  addTrailPoint(userId, position, userColor) {
    if (!this.showTrailsValue || !this.hasTrailsContainerTarget) return
    
    let userTrails = this.trails.get(userId)
    if (!userTrails) {
      userTrails = []
      this.trails.set(userId, userTrails)
    }
    
    // Create trail dot
    const trailDot = this.createTrailDot(position, userColor)
    this.trailsContainerTarget.appendChild(trailDot)
    userTrails.push(trailDot)
    
    // Limit trail length
    if (userTrails.length > this.maxTrailLength) {
      const oldestTrail = userTrails.shift()
      oldestTrail.remove()
    }
    
    // Auto-remove trail dot
    setTimeout(() => {
      trailDot.remove()
      const index = userTrails.indexOf(trailDot)
      if (index > -1) {
        userTrails.splice(index, 1)
      }
    }, 2000)
  }

  createTrailDot(position, userColor) {
    const template = this.trailTemplateTarget
    const trailDot = template.content.cloneNode(true).firstElementChild
    
    trailDot.style.left = `${position.x}px`
    trailDot.style.top = `${position.y}px`
    trailDot.dataset.trailTimestamp = Date.now()
    
    const colorClass = this.getUserColorClass(userColor)
    trailDot.classList.add(colorClass)
    
    return trailDot
  }

  clearTrails(userId) {
    const userTrails = this.trails.get(userId)
    if (userTrails) {
      userTrails.forEach(trail => trail.remove())
      this.trails.delete(userId)
    }
  }

  // Collision detection (if enabled)
  checkCollisions() {
    if (!this.collisionDetectionValue || !this.ownCursorPosition) return
    
    const ownPos = this.ownCursorPosition
    const collisions = []
    
    this.cursorData.forEach((data, userId) => {
      if (!data.position || userId === this.currentUserIdValue) return
      
      const distance = this.calculateDistance(ownPos, data.position)
      if (distance < this.collisionThreshold) {
        collisions.push({
          userId,
          distance,
          position: data.position,
          userName: data.userName
        })
      }
    })
    
    this.updateCollisionZones(collisions)
  }

  calculateDistance(pos1, pos2) {
    const dx = pos1.x - pos2.x
    const dy = pos1.y - pos2.y
    return Math.sqrt(dx * dx + dy * dy)
  }

  updateCollisionZones(collisions) {
    // Clear existing collision zones
    this.collisionZones.forEach(zone => zone.remove())
    this.collisionZones.clear()
    
    // Create new collision zones
    collisions.forEach(collision => {
      const zone = this.createCollisionZone(collision)
      this.collisionOverlayTarget.appendChild(zone)
      this.collisionZones.set(collision.userId, zone)
    })
  }

  createCollisionZone(collision) {
    const template = this.collisionTemplateTarget
    const zone = template.content.cloneNode(true).firstElementChild
    
    const centerX = (this.ownCursorPosition.x + collision.position.x) / 2
    const centerY = (this.ownCursorPosition.y + collision.position.y) / 2
    
    zone.style.left = `${centerX - 16}px` // Half of zone width
    zone.style.top = `${centerY - 16}px` // Half of zone height
    zone.dataset.collisionUserIds = `${this.currentUserIdValue},${collision.userId}`
    zone.dataset.collisionIntensity = Math.max(0, 1 - (collision.distance / this.collisionThreshold))
    
    return zone
  }

  // Window event handlers
  handleWindowResize() {
    this.updateCursorPositions()
  }

  handleWindowScroll() {
    this.updateCursorPositions()
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.hideOwnCursor()
    }
  }

  updateCursorPositions() {
    // Recalculate positions after container changes
    this.cursors.forEach((cursor, userId) => {
      const data = this.cursorData.get(userId)
      if (data && data.position) {
        this.animateCursorToPosition(cursor, data.position)
      }
    })
  }

  // Utility methods
  getUserColorClass(userColor) {
    const colorName = this.getColorName(userColor)
    return `cursor-${colorName}`
  }

  getColorName(color) {
    const colorMap = {
      "#ef4444": "rose",
      "#f97316": "orange", 
      "#eab308": "amber",
      "#22c55e": "teal",
      "#06b6d4": "teal",
      "#3b82f6": "primary",
      "#8b5cf6": "purple",
      "#ec4899": "rose"
    }
    
    return colorMap[color] || "primary"
  }

  generateUserColor(userId) {
    const colors = [
      "#3b82f6", "#06b6d4", "#8b5cf6", "#ec4899",
      "#ef4444", "#f97316", "#eab308", "#22c55e"
    ]
    
    return colors[userId % colors.length]
  }

  // Broadcasting
  broadcastCursorPosition(x, y) {
    this.dispatch("cursor:moved", {
      detail: {
        userId: this.currentUserIdValue,
        position: { x, y },
        timestamp: Date.now()
      }
    })
  }

  // Public API
  getCursors() {
    return Array.from(this.cursors.keys())
  }

  getCursorPosition(userId) {
    const data = this.cursorData.get(userId)
    return data ? data.position : null
  }

  getOwnCursorPosition() {
    return this.ownCursorPosition
  }

  // Configuration
  setShowLabels(enabled) {
    this.showLabelsValue = enabled
    this.cursors.forEach(cursor => {
      const label = cursor.querySelector('.cursor-label')
      if (label) {
        label.style.display = enabled ? 'block' : 'none'
      }
    })
  }

  setShowTrails(enabled) {
    this.showTrailsValue = enabled
    if (!enabled) {
      this.trails.forEach((userTrails) => {
        userTrails.forEach(trail => trail.remove())
      })
      this.trails.clear()
    }
  }

  setCollisionDetection(enabled) {
    this.collisionDetectionValue = enabled
    if (!enabled) {
      this.collisionZones.forEach(zone => zone.remove())
      this.collisionZones.clear()
    }
  }

  // Cleanup
  cleanup() {
    // Remove event listeners
    const container = this.getTrackingContainer()
    if (container && this.boundHandleMouseMove) {
      container.removeEventListener("mousemove", this.boundHandleMouseMove)
      container.removeEventListener("mouseleave", this.boundHandleMouseLeave)
    }
    
    window.removeEventListener("resize", this.handleWindowResize.bind(this))
    window.removeEventListener("scroll", this.handleWindowScroll.bind(this))
    document.removeEventListener("visibilitychange", this.handleVisibilityChange.bind(this))
    
    // Clear observers
    if (this.containerObserver) {
      this.containerObserver.disconnect()
    }
    
    // Clear timers
    this.cursorTimers.forEach(timer => clearTimeout(timer))
    this.cursorTimers.clear()
    
    // Clear elements
    this.cursors.forEach(cursor => cursor.remove())
    this.cursors.clear()
    
    this.trails.forEach(userTrails => {
      userTrails.forEach(trail => trail.remove())
    })
    this.trails.clear()
    
    this.collisionZones.forEach(zone => zone.remove())
    this.collisionZones.clear()
    
    // Clear data
    this.cursorData.clear()
    this.ownCursorPosition = null
  }
}