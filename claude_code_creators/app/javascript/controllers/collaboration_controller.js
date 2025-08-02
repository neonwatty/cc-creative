/**
 * CollaborationController - Stimulus controller for coordinating all real-time collaboration features
 * Integrates CollaborationManager, DocumentEditChannel, and NotificationChannel
 */

import { Controller } from "@hotwired/stimulus"
import CollaborationManager from "../services/collaboration_manager"
import webSocketManager from "../services/websocket_manager"
import { throttle, debounce } from "throttle-debounce"

export default class extends Controller {
  static targets = [
    "editor", "collaboratorsList", "typingIndicators", "conflictDialog", 
    "connectionStatus", "notifications", "presenceIndicator"
  ]
  
  static values = {
    documentId: Number,
    currentUser: Object,
    autoSave: { type: Boolean, default: true },
    enableCursors: { type: Boolean, default: true },
    enableTyping: { type: Boolean, default: true },
    enableConflictResolution: { type: Boolean, default: true },
    syncInterval: { type: Number, default: 30000 },
    operationBatchSize: { type: Number, default: 10 }
  }

  static classes = [
    "collaboratorActive", "collaboratorTyping", "conflictHighlight",
    "connectionGood", "connectionPoor", "connectionBad", "notification"
  ]

  connect() {
    if (!this.documentIdValue || !this.currentUserValue) {
      console.error("CollaborationController requires documentId and currentUser values")
      return
    }

    // Initialize collaboration state
    this.collaborators = new Map()
    this.typingUsers = new Set()
    this.pendingOperations = []
    this.conflictQueue = []
    this.isInitialized = false

    // Throttled functions
    this.throttledSendOperation = throttle(100, this.sendOperation.bind(this))
    this.debouncedStopTyping = debounce(2000, this.stopTyping.bind(this))
    this.throttledUpdateCursor = throttle(50, this.updateCursorPosition.bind(this))

    this.initializeCollaboration()
    this.setupEventListeners()
    this.setupWebSocketMonitoring()

    console.log("CollaborationController connected for document", this.documentIdValue)
  }

  disconnect() {
    this.cleanup()
    console.log("CollaborationController disconnected")
  }

  // Initialize collaboration manager
  async initializeCollaboration() {
    try {
      this.collaborationManager = new CollaborationManager(
        this.documentIdValue,
        this.currentUserValue,
        {
          autoReconnect: true,
          syncInterval: this.syncIntervalValue,
          operationQueueSize: this.operationBatchSizeValue * 2
        }
      )

      // Setup collaboration event listeners
      this.setupCollaborationEvents()

      // Initialize the connection
      const success = await this.collaborationManager.initialize()
      
      if (success) {
        this.isInitialized = true
        this.updateConnectionStatus("connected")
        this.showNotification("Connected to collaboration session", "success")
      } else {
        this.updateConnectionStatus("error")
        this.showNotification("Failed to connect to collaboration session", "error")
      }

    } catch (error) {
      console.error("Failed to initialize collaboration:", error)
      this.updateConnectionStatus("error")
      this.showNotification("Collaboration initialization failed", "error")
    }
  }

  // Setup collaboration manager event listeners
  setupCollaborationEvents() {
    const manager = this.collaborationManager

    // Connection events
    manager.on("connection:established", () => {
      this.updateConnectionStatus("connected")
      this.showNotification("Collaboration connected", "success")
    })

    manager.on("connection:lost", () => {
      this.updateConnectionStatus("reconnecting")
      this.showNotification("Connection lost, reconnecting...", "warning")
    })

    manager.on("connection:error", (data) => {
      this.updateConnectionStatus("error")
      this.showNotification(`Connection error: ${data.error}`, "error")
    })

    manager.on("connection:reconnecting", (data) => {
      this.updateConnectionStatus("reconnecting")
      this.showNotification(`Reconnecting... (${data.attempt}/${data.maxAttempts})`, "info")
    })

    // Collaborator events
    manager.on("collaborator:joined", (user) => {
      this.handleCollaboratorJoined(user)
    })

    manager.on("collaborator:left", (data) => {
      this.handleCollaboratorLeft(data.userId)
    })

    // Operation events
    manager.on("operation:applied", (data) => {
      this.handleOperationApplied(data)
    })

    manager.on("operation:confirmed", (data) => {
      this.handleOperationConfirmed(data)
    })

    manager.on("operation:error", (data) => {
      this.handleOperationError(data)
    })

    manager.on("operation:timeout", (data) => {
      this.handleOperationTimeout(data)
    })

    // Cursor and selection events
    manager.on("cursor:moved", (data) => {
      if (this.enableCursorsValue) {
        this.handleCursorMoved(data)
      }
    })

    manager.on("selection:changed", (data) => {
      if (this.enableCursorsValue) {
        this.handleSelectionChanged(data)
      }
    })

    // Document sync events
    manager.on("document:synced", (data) => {
      this.handleDocumentSynced(data)
    })

    manager.on("document:sync:confirmed", () => {
      this.showNotification("Document synchronized", "success")
    })

    // Conflict resolution events
    manager.on("conflict:resolved", (data) => {
      this.handleConflictResolved(data)
    })

    // Version events
    manager.on("version:created", (data) => {
      this.handleVersionCreated(data)
    })

    // Notification events
    manager.on("notification:received", (notification) => {
      this.handleNotificationReceived(notification)
    })
  }

  // Setup DOM event listeners
  setupEventListeners() {
    // Editor events
    if (this.hasEditorTarget) {
      this.editorTarget.addEventListener("input", this.handleEditorInput.bind(this))
      this.editorTarget.addEventListener("selectionchange", this.handleSelectionChange.bind(this))
      this.editorTarget.addEventListener("keydown", this.handleKeyDown.bind(this))
      this.editorTarget.addEventListener("paste", this.handlePaste.bind(this))
      
      if (this.enableCursorsValue) {
        this.editorTarget.addEventListener("mousemove", this.handleMouseMove.bind(this))
        this.editorTarget.addEventListener("click", this.handleClick.bind(this))
      }
    }

    // Document-level events
    document.addEventListener("visibilitychange", this.handleVisibilityChange.bind(this))
    window.addEventListener("beforeunload", this.handleBeforeUnload.bind(this))
  }

  // Setup WebSocket connection monitoring
  setupWebSocketMonitoring() {
    webSocketManager.on("connection:quality_changed", (data) => {
      this.updateConnectionQuality(data.quality)
    })

    webSocketManager.on("connection:latency", (data) => {
      this.updateLatencyIndicator(data.latency)
    })
  }

  // Editor event handlers
  handleEditorInput(event) {
    if (!this.isInitialized) return

    const operation = this.extractOperationFromInput(event)
    if (operation) {
      this.queueOperation(operation)
      
      if (this.enableTypingValue) {
        this.startTyping()
      }
    }
  }

  handleSelectionChange(event) {
    if (!this.isInitialized || !this.enableCursorsValue) return

    const selection = this.getSelectionData()
    if (selection) {
      this.throttledUpdateCursor(null, selection)
    }
  }

  handleKeyDown(event) {
    if (!this.isInitialized) return

    // Handle special key combinations
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
      case "s":
        event.preventDefault()
        this.saveDocument()
        break
      case "z":
        if (event.shiftKey) {
          // Redo
          this.handleRedo()
        } else {
          // Undo
          this.handleUndo()
        }
        break
      }
    }

    if (this.enableTypingValue) {
      this.startTyping()
    }
  }

  handlePaste(event) {
    if (!this.isInitialized) return

    // Handle paste operations
    const pastedData = event.clipboardData.getData("text")
    if (pastedData) {
      const operation = this.createPasteOperation(pastedData)
      this.queueOperation(operation)
    }
  }

  handleMouseMove(event) {
    if (!this.isInitialized || !this.enableCursorsValue) return

    const position = this.getCursorPosition(event)
    if (position) {
      this.throttledUpdateCursor(position)
    }
  }

  handleClick(event) {
    if (!this.isInitialized || !this.enableCursorsValue) return

    const position = this.getCursorPosition(event)
    if (position) {
      this.updateCursorPosition(position)
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      // Page is hidden, reduce activity
      if (this.enableTypingValue) {
        this.stopTyping()
      }
    } else {
      // Page is visible, resume normal activity
      if (this.isInitialized) {
        this.collaborationManager.requestDocumentSync()
      }
    }
  }

  handleBeforeUnload() {
    // Save any pending operations before leaving
    this.flushPendingOperations()
  }

  // Collaboration event handlers
  handleCollaboratorJoined(user) {
    this.collaborators.set(user.id, user)
    this.updateCollaboratorsList()
    this.showNotification(`${user.name} joined the collaboration`, "info")
  }

  handleCollaboratorLeft(userId) {
    const user = this.collaborators.get(userId)
    this.collaborators.delete(userId)
    this.typingUsers.delete(userId)
    this.updateCollaboratorsList()
    this.updateTypingIndicators()
    
    if (user) {
      this.showNotification(`${user.name} left the collaboration`, "info")
    }
  }

  handleOperationApplied(data) {
    const { operation, userId, conflicts } = data
    
    if (userId !== this.currentUserValue.id) {
      this.applyOperationToEditor(operation)
      
      if (conflicts && conflicts.length > 0) {
        this.handleConflicts(conflicts, operation)
      }
    }
  }

  handleOperationConfirmed(data) {
    const { operationId, status, conflicts } = data
    
    // Remove from pending operations
    this.removePendingOperation(operationId)
    
    if (conflicts && conflicts.length > 0) {
      this.handleConflicts(conflicts)
    }
    
    if (status === "conflict_resolved") {
      this.showNotification("Operation applied with conflict resolution", "warning")
    }
  }

  handleOperationError(data) {
    const { error, operation } = data
    
    console.error("Operation error:", error, operation)
    this.showNotification(`Operation failed: ${error}`, "error")
    
    // Remove from pending operations if it has an ID
    if (operation?.operation_id) {
      this.removePendingOperation(operation.operation_id)
    }
  }

  handleOperationTimeout(data) {
    const { operationId, operation } = data
    
    console.warn("Operation timeout:", operationId, operation)
    this.showNotification("Operation timed out - retrying...", "warning")
    
    // Retry the operation
    this.retryOperation(operation)
  }

  handleCursorMoved(data) {
    const { userId, userName, position } = data
    
    if (userId !== this.currentUserValue.id) {
      this.updateRemoteCursor(userId, userName, position)
    }
  }

  handleSelectionChanged(data) {
    const { userId, userName, selection } = data
    
    if (userId !== this.currentUserValue.id) {
      this.updateRemoteSelection(userId, userName, selection)
    }
  }

  handleDocumentSynced(data) {
    const { content, stateHash, version, activeOperations } = data
    
    // Update editor content if needed
    if (this.hasEditorTarget && this.editorTarget.value !== content) {
      this.editorTarget.value = content
      this.showNotification("Document synchronized with server", "info")
    }
    
    // Apply any active operations
    if (activeOperations && activeOperations.length > 0) {
      activeOperations.forEach(op => this.applyOperationToEditor(op))
    }
  }

  handleConflictResolved(data) {
    const { conflictId, resolvedBy, finalContent } = data
    
    this.removeConflictFromQueue(conflictId)
    
    if (resolvedBy === this.currentUserValue.id) {
      this.showNotification("Conflict resolved successfully", "success")
    } else {
      this.showNotification("Conflict was resolved by another user", "info")
    }
    
    if (this.hasEditorTarget) {
      this.editorTarget.value = finalContent
    }
  }

  handleVersionCreated(data) {
    const { version_number, version_name, created_by } = data
    
    let message = `Version ${version_number} created`
    if (version_name) {
      message += `: ${version_name}`
    }
    if (created_by !== this.currentUserValue.id) {
      message += " by another user"
    }
    
    this.showNotification(message, "success")
  }

  handleNotificationReceived(notification) {
    this.displayNotification(notification)
  }

  // Operation management
  extractOperationFromInput(event) {
    // Extract operation data from input event
    // This would depend on your editor implementation
    const target = event.target
    const operation = {
      type: "insert", // or 'delete', 'replace'
      position: target.selectionStart,
      content: event.data || "",
      timestamp: Date.now()
    }
    
    return operation
  }

  createPasteOperation(content) {
    const target = this.editorTarget
    return {
      type: "insert",
      position: target.selectionStart,
      content: content,
      timestamp: Date.now()
    }
  }

  queueOperation(operation) {
    this.pendingOperations.push(operation)
    
    // Send immediately or batch based on configuration
    if (this.pendingOperations.length >= this.operationBatchSizeValue) {
      this.flushPendingOperations()
    } else {
      this.throttledSendOperation()
    }
  }

  sendOperation() {
    if (this.pendingOperations.length === 0) return
    
    const operations = this.pendingOperations.splice(0, this.operationBatchSizeValue)
    
    if (operations.length === 1) {
      this.collaborationManager.sendOperation(operations[0])
    } else {
      this.collaborationManager.sendBatchOperations(operations)
    }
  }

  flushPendingOperations() {
    while (this.pendingOperations.length > 0) {
      this.sendOperation()
    }
  }

  removePendingOperation(operationId) {
    this.pendingOperations = this.pendingOperations.filter(
      op => op.operation_id !== operationId
    )
  }

  retryOperation(operation) {
    // Add back to queue for retry
    this.pendingOperations.unshift(operation)
    this.throttledSendOperation()
  }

  applyOperationToEditor(operation) {
    if (!this.hasEditorTarget) return
    
    const target = this.editorTarget
    const { type, position, content, length } = operation
    
    switch (type) {
    case "insert":
      this.insertTextAtPosition(target, position, content)
      break
    case "delete":
      this.deleteTextAtPosition(target, position, length)
      break
    case "replace":
      this.replaceTextAtPosition(target, position, length, content)
      break
    }
  }

  // Cursor and selection management
  getCursorPosition(event) {
    const rect = this.editorTarget.getBoundingClientRect()
    return {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
      textPosition: this.editorTarget.selectionStart
    }
  }

  getSelectionData() {
    if (!this.hasEditorTarget) return null
    
    const target = this.editorTarget
    if (target.selectionStart === target.selectionEnd) return null
    
    return {
      start: target.selectionStart,
      end: target.selectionEnd,
      text: target.value.substring(target.selectionStart, target.selectionEnd)
    }
  }

  updateCursorPosition(position, selection = null) {
    if (this.collaborationManager) {
      this.collaborationManager.updateCursorPosition(position, selection)
    }
  }

  updateRemoteCursor(userId, userName, position) {
    // Update cursor display for remote user
    // This would integrate with your cursor visualization system
    this.dispatch("cursor:updated", { 
      detail: { userId, userName, position }
    })
  }

  updateRemoteSelection(userId, userName, selection) {
    // Update selection display for remote user
    this.dispatch("selection:updated", { 
      detail: { userId, userName, selection }
    })
  }

  // Typing indicators
  startTyping() {
    if (!this.collaborationManager) return
    
    this.collaborationManager.startTyping()
    this.debouncedStopTyping()
  }

  stopTyping() {
    if (!this.collaborationManager) return
    
    this.collaborationManager.stopTyping()
  }

  updateTypingIndicators() {
    if (!this.hasTypingIndicatorsTarget) return
    
    const typingUsers = Array.from(this.typingUsers)
      .map(userId => this.collaborators.get(userId))
      .filter(user => user)
    
    if (typingUsers.length === 0) {
      this.typingIndicatorsTarget.textContent = ""
      this.typingIndicatorsTarget.style.display = "none"
    } else {
      const names = typingUsers.map(user => user.name)
      let message = ""
      
      if (names.length === 1) {
        message = `${names[0]} is typing...`
      } else if (names.length === 2) {
        message = `${names[0]} and ${names[1]} are typing...`
      } else {
        message = `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]} are typing...`
      }
      
      this.typingIndicatorsTarget.textContent = message
      this.typingIndicatorsTarget.style.display = "block"
    }
  }

  // Conflict handling
  handleConflicts(conflicts, operation = null) {
    if (!this.enableConflictResolutionValue) return
    
    conflicts.forEach(conflict => {
      this.conflictQueue.push({ ...conflict, operation })
    })
    
    this.showConflictDialog()
  }

  showConflictDialog() {
    if (!this.hasConflictDialogTarget || this.conflictQueue.length === 0) return
    
    const conflict = this.conflictQueue[0]
    
    // Populate conflict dialog with conflict data
    this.conflictDialogTarget.querySelector(".conflict-description").textContent = 
      conflict.description || "A conflict occurred during collaboration"
    
    this.conflictDialogTarget.style.display = "block"
  }

  resolveConflict(conflictId, resolution) {
    if (this.collaborationManager) {
      this.collaborationManager.resolveConflict(conflictId, resolution)
    }
    
    this.removeConflictFromQueue(conflictId)
    this.hideConflictDialog()
  }

  removeConflictFromQueue(conflictId) {
    this.conflictQueue = this.conflictQueue.filter(c => c.id !== conflictId)
  }

  hideConflictDialog() {
    if (this.hasConflictDialogTarget) {
      this.conflictDialogTarget.style.display = "none"
    }
  }

  // UI Updates
  updateConnectionStatus(status) {
    if (!this.hasConnectionStatusTarget) return
    
    const target = this.connectionStatusTarget
    target.className = target.className.replace(/connection-\w+/, "")
    
    switch (status) {
    case "connected":
      target.classList.add(this.connectionGoodClass)
      target.textContent = "Connected"
      break
    case "reconnecting":
      target.classList.add(this.connectionPoorClass)
      target.textContent = "Reconnecting..."
      break
    case "error":
      target.classList.add(this.connectionBadClass)
      target.textContent = "Connection Error"
      break
    }
  }

  updateConnectionQuality(quality) {
    if (!this.hasConnectionStatusTarget) return
    
    const target = this.connectionStatusTarget
    target.classList.remove(this.connectionGoodClass, this.connectionPoorClass, this.connectionBadClass)
    
    switch (quality) {
    case "good":
      target.classList.add(this.connectionGoodClass)
      break
    case "poor":
      target.classList.add(this.connectionPoorClass)
      break
    case "bad":
      target.classList.add(this.connectionBadClass)
      break
    }
  }

  updateLatencyIndicator(latency) {
    // Update latency display if you have one
    this.dispatch("latency:updated", { detail: { latency } })
  }

  updateCollaboratorsList() {
    if (!this.hasCollaboratorsListTarget) return
    
    const target = this.collaboratorsListTarget
    target.innerHTML = ""
    
    this.collaborators.forEach(user => {
      const userElement = document.createElement("div")
      userElement.className = `collaborator ${this.collaboratorActiveClass}`
      userElement.textContent = user.name
      userElement.dataset.userId = user.id
      
      if (this.typingUsers.has(user.id)) {
        userElement.classList.add(this.collaboratorTypingClass)
      }
      
      target.appendChild(userElement)
    })
  }

  showNotification(message, type = "info") {
    const notification = {
      id: `notif_${Date.now()}`,
      message,
      type,
      timestamp: new Date().toISOString()
    }
    
    this.displayNotification(notification)
  }

  displayNotification(notification) {
    if (!this.hasNotificationsTarget) {
      console.log("Notification:", notification.message)
      return
    }
    
    const element = document.createElement("div")
    element.className = `notification ${this.notificationClass} notification-${notification.type}`
    element.textContent = notification.message
    element.dataset.notificationId = notification.id
    
    this.notificationsTarget.appendChild(element)
    
    // Auto-remove after delay
    setTimeout(() => {
      element.remove()
    }, 5000)
  }

  // Document operations
  saveDocument() {
    this.flushPendingOperations()
    
    if (this.collaborationManager) {
      this.collaborationManager.createVersion({
        name: `Manual save ${new Date().toLocaleString()}`,
        notes: "Manual save during collaboration"
      })
    }
  }

  handleUndo() {
    // Implement undo functionality
    this.showNotification("Undo functionality not yet implemented", "info")
  }

  handleRedo() {
    // Implement redo functionality
    this.showNotification("Redo functionality not yet implemented", "info")
  }

  // Text manipulation helpers
  insertTextAtPosition(target, position, text) {
    const value = target.value
    target.value = value.slice(0, position) + text + value.slice(position)
  }

  deleteTextAtPosition(target, position, length) {
    const value = target.value
    target.value = value.slice(0, position) + value.slice(position + length)
  }

  replaceTextAtPosition(target, position, length, text) {
    const value = target.value
    target.value = value.slice(0, position) + text + value.slice(position + length)
  }

  // Public API methods for external interaction
  getCollaborationInfo() {
    if (!this.collaborationManager) return null
    
    return {
      ...this.collaborationManager.getConnectionState(),
      collaborators: Array.from(this.collaborators.values()),
      typingUsers: Array.from(this.typingUsers),
      conflictQueue: this.conflictQueue.length
    }
  }

  forceSync() {
    if (this.collaborationManager) {
      this.collaborationManager.requestDocumentSync()
      this.showNotification("Synchronization requested", "info")
    }
  }

  // Cleanup
  cleanup() {
    if (this.collaborationManager) {
      this.collaborationManager.disconnect()
      this.collaborationManager = null
    }
    
    this.collaborators.clear()
    this.typingUsers.clear()
    this.pendingOperations = []
    this.conflictQueue = []
  }
}