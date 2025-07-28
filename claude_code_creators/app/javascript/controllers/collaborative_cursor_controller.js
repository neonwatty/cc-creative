import { Controller } from "@hotwired/stimulus"
import { throttle } from "throttle-debounce"

// Connects to data-controller="collaborative-cursor"
export default class extends Controller {
  static targets = ["cursorContainer", "cursorTemplate"]
  static values = {
    documentId: Number,
    currentUserId: Number,
    updateInterval: { type: Number, default: 100 }, // milliseconds
    fadeTimeout: { type: Number, default: 3000 }, // milliseconds
    enableCursors: { type: Boolean, default: true },
    enableSelections: { type: Boolean, default: true }
  }

  static classes = ["cursor", "cursorActive", "cursorFading", "selection"]

  connect() {
    if (!this.enableCursorsValue && !this.enableSelectionsValue) return
    
    this.cursors = new Map() // userId -> cursor element
    this.selections = new Map() // userId -> selection element
    this.fadeTimers = new Map() // userId -> timeout ID
    this.lastPosition = null
    this.presenceChannel = null
    
    // Throttled update functions
    this.throttledUpdateCursor = throttle(this.updateIntervalValue, this.broadcastCursorPosition.bind(this))
    this.throttledUpdateSelection = throttle(this.updateIntervalValue * 2, this.broadcastSelection.bind(this))
    
    this.setupPresenceChannel()
    this.setupEventListeners()
    
    console.log('CollaborativeCursorController connected')
  }

  disconnect() {
    if (this.presenceChannel) {
      this.presenceChannel.disconnect()
      this.presenceChannel = null
    }
    
    this.removeEventListeners()
    this.clearAllCursors()
    this.clearAllSelections()
    
    // Clear all fade timers
    this.fadeTimers.forEach(timer => clearTimeout(timer))
    this.fadeTimers.clear()
  }

  // Setup presence channel connection
  async setupPresenceChannel() {
    if (!this.documentIdValue || !this.currentUserIdValue) return
    
    try {
      const { default: PresenceChannel } = await import('../channels/presence_channel')
      
      this.presenceChannel = PresenceChannel.create(
        this.documentIdValue,
        this.currentUserIdValue,
        {
          onConnected: () => {
            console.log('Collaborative cursor connected to presence channel')
          },
          
          onDisconnected: () => {
            console.log('Collaborative cursor disconnected from presence channel')
            this.clearAllCursors()
            this.clearAllSelections()
          },
          
          onUserJoined: (user) => {
            console.log(`User ${user.name} joined for cursor tracking`)
          },
          
          onUserLeft: (userId) => {
            this.removeCursor(userId)
            this.removeSelection(userId)
          },
          
          onCursorMoved: (userId, userName, position) => {
            if (this.enableCursorsValue) {
              this.updateCursor(userId, userName, position)
            }
          },
          
          onSelectionChanged: (userId, userName, selection) => {
            if (this.enableSelectionsValue) {
              this.updateSelection(userId, userName, selection)
            }
          }
        }
      )
    } catch (error) {
      console.error('Failed to setup presence channel for cursors:', error)
    }
  }

  // Setup event listeners for cursor and selection tracking
  setupEventListeners() {
    // Track mouse movement
    if (this.enableCursorsValue) {
      document.addEventListener('mousemove', this.handleMouseMove.bind(this))
      document.addEventListener('mouseenter', this.handleMouseEnter.bind(this))
      document.addEventListener('mouseleave', this.handleMouseLeave.bind(this))
    }
    
    // Track text selection
    if (this.enableSelectionsValue) {
      document.addEventListener('selectionchange', this.handleSelectionChange.bind(this))
    }
    
    // Track focus changes
    document.addEventListener('focusin', this.handleFocusIn.bind(this))
    document.addEventListener('focusout', this.handleFocusOut.bind(this))
  }

  removeEventListeners() {
    if (this.enableCursorsValue) {
      document.removeEventListener('mousemove', this.handleMouseMove.bind(this))
      document.removeEventListener('mouseenter', this.handleMouseEnter.bind(this))
      document.removeEventListener('mouseleave', this.handleMouseLeave.bind(this))
    }
    
    if (this.enableSelectionsValue) {
      document.removeEventListener('selectionchange', this.handleSelectionChange.bind(this))
    }
    
    document.removeEventListener('focusin', this.handleFocusIn.bind(this))
    document.removeEventListener('focusout', this.handleFocusOut.bind(this))
  }

  // Handle mouse movement
  handleMouseMove(event) {
    if (!this.presenceChannel) return
    
    const position = {
      x: event.clientX,
      y: event.clientY,
      target: this.getElementPath(event.target)
    }
    
    // Only update if position changed significantly
    if (this.hasPositionChanged(position)) {
      this.lastPosition = position
      this.throttledUpdateCursor(position)
    }
  }

  handleMouseEnter(event) {
    if (this.presenceChannel) {
      this.broadcastPresenceState('active')
    }
  }

  handleMouseLeave(event) {
    if (this.presenceChannel) {
      this.broadcastPresenceState('away')
    }
  }

  // Handle selection changes
  handleSelectionChange(event) {
    if (!this.presenceChannel) return
    
    const selection = window.getSelection()
    if (selection.rangeCount === 0) return
    
    const range = selection.getRangeAt(0)
    if (range.collapsed) return // No selection
    
    const selectionData = {
      text: selection.toString(),
      startContainer: this.getElementPath(range.startContainer),
      endContainer: this.getElementPath(range.endContainer),
      startOffset: range.startOffset,
      endOffset: range.endOffset
    }
    
    this.throttledUpdateSelection(selectionData)
  }

  handleFocusIn(event) {
    // User is active, show their cursor more prominently
    if (this.presenceChannel) {
      this.broadcastPresenceState('focused')
    }
  }

  handleFocusOut(event) {
    // User focus left, fade cursor slightly
    if (this.presenceChannel) {
      this.broadcastPresenceState('active')
    }
  }

  // Get a unique path to an element for consistent targeting
  getElementPath(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) return null
    
    const path = []
    let current = element
    
    while (current && current !== document.body) {
      let selector = current.tagName.toLowerCase()
      
      if (current.id) {
        selector += `#${current.id}`
        path.unshift(selector)
        break // ID is unique, we can stop here
      }
      
      if (current.className) {
        const classes = Array.from(current.classList)
          .filter(cls => !cls.startsWith('cursor-') && !cls.startsWith('selection-'))
          .slice(0, 2) // Limit classes to avoid overly long selectors
          .join('.')
        if (classes) {
          selector += `.${classes}`
        }
      }
      
      // Add nth-child for specificity
      const siblings = Array.from(current.parentNode?.children || [])
        .filter(sibling => sibling.tagName === current.tagName)
      
      if (siblings.length > 1) {
        const index = siblings.indexOf(current) + 1
        selector += `:nth-child(${index})`
      }
      
      path.unshift(selector)
      current = current.parentNode
    }
    
    return path.join(' > ')
  }

  // Check if position changed significantly
  hasPositionChanged(newPosition) {
    if (!this.lastPosition) return true
    
    const threshold = 5 // pixels
    return Math.abs(newPosition.x - this.lastPosition.x) > threshold ||
           Math.abs(newPosition.y - this.lastPosition.y) > threshold
  }

  // Broadcast cursor position
  broadcastCursorPosition(position) {
    if (this.presenceChannel) {
      this.presenceChannel.perform('cursor_moved', {
        position: position
      })
    }
  }

  // Broadcast selection
  broadcastSelection(selectionData) {
    if (this.presenceChannel) {
      this.presenceChannel.perform('selection_changed', {
        selection: selectionData
      })
    }
  }

  // Broadcast presence state
  broadcastPresenceState(state) {
    if (this.presenceChannel) {
      this.presenceChannel.perform('presence_state_changed', {
        state: state
      })
    }
  }

  // Update cursor position for another user
  updateCursor(userId, userName, position) {
    if (userId === this.currentUserIdValue) return // Don't show own cursor
    
    let cursor = this.cursors.get(userId)
    
    if (!cursor) {
      cursor = this.createCursor(userId, userName)
      this.cursors.set(userId, cursor)
      
      if (this.hasCursorContainerTarget) {
        this.cursorContainerTarget.appendChild(cursor)
      } else {
        document.body.appendChild(cursor)
      }
    }
    
    // Update cursor position
    this.positionCursor(cursor, position)
    
    // Show cursor and reset fade timer
    this.showCursor(cursor, userId)
    this.resetFadeTimer(userId)
  }

  // Create cursor element
  createCursor(userId, userName) {
    let cursor
    
    if (this.hasCursorTemplateTarget) {
      cursor = this.cursorTemplateTarget.content.cloneNode(true).firstElementChild
    } else {
      cursor = this.createDefaultCursor()
    }
    
    cursor.dataset.userId = userId
    cursor.dataset.userName = userName
    cursor.classList.add(this.cursorClass)
    
    // Add user name
    const nameElement = cursor.querySelector('.cursor-user-name')
    if (nameElement) {
      nameElement.textContent = userName
    }
    
    // Add user-specific color
    cursor.style.setProperty('--user-color', this.getUserColor(userId))
    
    return cursor
  }

  // Create default cursor if no template provided
  createDefaultCursor() {
    const cursor = document.createElement('div')
    cursor.className = 'collaborative-cursor'
    cursor.innerHTML = `
      <div class="cursor-pointer"></div>
      <div class="cursor-label">
        <span class="cursor-user-name"></span>
      </div>
    `
    return cursor
  }

  // Position cursor element
  positionCursor(cursor, position) {
    cursor.style.left = `${position.x}px`
    cursor.style.top = `${position.y}px`
    
    // Try to position relative to target element if available
    if (position.target) {
      const targetElement = document.querySelector(position.target)
      if (targetElement) {
        const rect = targetElement.getBoundingClientRect()
        cursor.style.left = `${rect.left + (position.x || 0)}px`
        cursor.style.top = `${rect.top + (position.y || 0)}px`
      }
    }
  }

  // Show cursor with animation
  showCursor(cursor, userId) {
    cursor.classList.add(this.cursorActiveClass)
    cursor.classList.remove(this.cursorFadingClass)
  }

  // Reset fade timer for cursor
  resetFadeTimer(userId) {
    // Clear existing timer
    if (this.fadeTimers.has(userId)) {
      clearTimeout(this.fadeTimers.get(userId))
    }
    
    // Set new timer
    const timer = setTimeout(() => {
      this.fadeCursor(userId)
    }, this.fadeTimeoutValue)
    
    this.fadeTimers.set(userId, timer)
  }

  // Fade cursor after inactivity
  fadeCursor(userId) {
    const cursor = this.cursors.get(userId)
    if (cursor) {
      cursor.classList.add(this.cursorFadingClass)
      cursor.classList.remove(this.cursorActiveClass)
    }
    
    this.fadeTimers.delete(userId)
  }

  // Remove cursor
  removeCursor(userId) {
    const cursor = this.cursors.get(userId)
    if (cursor) {
      cursor.style.transition = 'opacity 0.3s ease'
      cursor.style.opacity = '0'
      
      setTimeout(() => {
        cursor.remove()
      }, 300)
      
      this.cursors.delete(userId)
    }
    
    // Clear fade timer
    if (this.fadeTimers.has(userId)) {
      clearTimeout(this.fadeTimers.get(userId))
      this.fadeTimers.delete(userId)
    }
  }

  // Update selection for another user
  updateSelection(userId, userName, selectionData) {
    if (userId === this.currentUserIdValue) return // Don't show own selection
    
    // Remove existing selection
    this.removeSelection(userId)
    
    // Create new selection
    const selection = this.createSelection(userId, userName, selectionData)
    if (selection) {
      this.selections.set(userId, selection)
      document.body.appendChild(selection)
      
      // Auto-remove selection after timeout
      setTimeout(() => {
        this.removeSelection(userId)
      }, this.fadeTimeoutValue * 2)
    }
  }

  // Create selection element
  createSelection(userId, userName, selectionData) {
    try {
      // Find the target elements
      const startElement = document.querySelector(selectionData.startContainer)
      const endElement = document.querySelector(selectionData.endContainer)
      
      if (!startElement || !endElement) return null
      
      // Create selection overlay
      const selection = document.createElement('div')
      selection.classList.add(this.selectionClass)
      selection.dataset.userId = userId
      selection.style.setProperty('--user-color', this.getUserColor(userId))
      
      // Calculate selection bounds
      const range = document.createRange()
      range.setStart(startElement, selectionData.startOffset)
      range.setEnd(endElement, selectionData.endOffset)
      
      const rects = range.getClientRects()
      
      // Create highlight for each rect
      for (let i = 0; i < rects.length; i++) {
        const rect = rects[i]
        const highlight = document.createElement('div')
        highlight.className = 'selection-highlight'
        highlight.style.cssText = `
          position: fixed;
          left: ${rect.left}px;
          top: ${rect.top}px;
          width: ${rect.width}px;
          height: ${rect.height}px;
          background-color: var(--user-color, #3b82f6);
          opacity: 0.3;
          pointer-events: none;
          z-index: 1000;
        `
        selection.appendChild(highlight)
      }
      
      // Add user label
      if (rects.length > 0) {
        const firstRect = rects[0]
        const label = document.createElement('div')
        label.className = 'selection-label'
        label.textContent = userName
        label.style.cssText = `
          position: fixed;
          left: ${firstRect.left}px;
          top: ${firstRect.top - 20}px;
          background-color: var(--user-color, #3b82f6);
          color: white;
          padding: 2px 6px;
          border-radius: 3px;
          font-size: 12px;
          white-space: nowrap;
          z-index: 1001;
        `
        selection.appendChild(label)
      }
      
      return selection
      
    } catch (error) {
      console.error('Failed to create selection:', error)
      return null
    }
  }

  // Remove selection
  removeSelection(userId) {
    const selection = this.selections.get(userId)
    if (selection) {
      selection.style.transition = 'opacity 0.3s ease'
      selection.style.opacity = '0'
      
      setTimeout(() => {
        selection.remove()
      }, 300)
      
      this.selections.delete(userId)
    }
  }

  // Clear all cursors
  clearAllCursors() {
    this.cursors.forEach((cursor, userId) => {
      cursor.remove()
    })
    this.cursors.clear()
  }

  // Clear all selections
  clearAllSelections() {
    this.selections.forEach((selection, userId) => {
      selection.remove()
    })
    this.selections.clear()
  }

  // Get consistent color for user
  getUserColor(userId) {
    const colors = [
      '#ef4444', '#f97316', '#eab308', '#22c55e',
      '#06b6d4', '#3b82f6', '#8b5cf6', '#ec4899'
    ]
    
    return colors[userId % colors.length]
  }
}