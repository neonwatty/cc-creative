/**
 * CollaborationManager - Central service for coordinating real-time collaboration features
 * Integrates with DocumentEditChannel and NotificationChannel for seamless real-time editing
 */

import consumer from "../channels/consumer"
import { throttle, debounce } from "throttle-debounce"

class CollaborationManager {
  constructor(documentId, currentUser, options = {}) {
    this.documentId = documentId
    this.currentUser = currentUser
    this.options = {
      autoReconnect: true,
      reconnectDelay: 1000,
      maxReconnectAttempts: 5,
      operationQueueSize: 100,
      syncInterval: 30000, // 30 seconds
      heartbeatInterval: 15000, // 15 seconds
      conflictRetryDelay: 2000,
      ...options
    }

    // Connection state
    this.isConnected = false
    this.reconnectAttempts = 0
    this.connectionState = "disconnected" // 'connecting', 'connected', 'disconnected', 'error'

    // Channels
    this.documentChannel = null
    this.notificationChannel = null

    // Operation management
    this.operationQueue = []
    this.pendingOperations = new Map() // operationId -> operation
    this.acknowledgedOperations = new Set()
    this.documentState = {
      content: "",
      version: 0,
      stateHash: null
    }

    // Collaboration state
    this.collaborators = new Map() // userId -> user info
    this.cursors = new Map() // userId -> cursor position
    this.typingUsers = new Set() // userIds currently typing
    this.conflictResolutions = new Map() // conflictId -> resolution data

    // Event listeners
    this.eventListeners = new Map()

    // Throttled functions
    this.throttledSyncCheck = throttle(this.options.syncInterval, this.checkDocumentSync.bind(this))
    this.debouncedTypingNotification = debounce(1000, this.sendTypingNotification.bind(this, false))

    // Timers
    this.heartbeatTimer = null
    this.syncTimer = null
  }

  // Initialize collaboration
  async initialize() {
    try {
      this.connectionState = "connecting"
      this.emit("connection:state:changed", { state: "connecting" })

      await this.setupDocumentChannel()
      await this.setupNotificationChannel()
      
      this.startHeartbeat()
      this.startPeriodicSync()
      
      this.isConnected = true
      this.connectionState = "connected"
      this.reconnectAttempts = 0
      
      this.emit("connection:established", { 
        documentId: this.documentId,
        userId: this.currentUser.id 
      })

      console.log("CollaborationManager initialized successfully")
      return true
    } catch (error) {
      console.error("Failed to initialize collaboration:", error)
      this.connectionState = "error"
      this.emit("connection:error", { error: error.message })
      
      if (this.options.autoReconnect) {
        this.scheduleReconnect()
      }
      return false
    }
  }

  // Setup document editing channel
  async setupDocumentChannel() {
    return new Promise((resolve, reject) => {
      this.documentChannel = consumer.subscriptions.create(
        { 
          channel: "DocumentEditChannel", 
          document_id: this.documentId 
        },
        {
          connected: () => {
            console.log("Connected to DocumentEditChannel")
            this.emit("channel:document:connected")
            resolve()
          },

          disconnected: () => {
            console.log("Disconnected from DocumentEditChannel")
            this.isConnected = false
            this.connectionState = "disconnected"
            this.emit("channel:document:disconnected")
            
            if (this.options.autoReconnect) {
              this.scheduleReconnect()
            }
          },

          rejected: () => {
            console.error("DocumentEditChannel subscription rejected")
            this.connectionState = "error"
            this.emit("channel:document:rejected")
            reject(new Error("DocumentEditChannel subscription rejected"))
          },

          received: (data) => {
            this.handleDocumentChannelMessage(data)
          }
        }
      )
    })
  }

  // Setup notification channel
  async setupNotificationChannel() {
    return new Promise((resolve, reject) => {
      this.notificationChannel = consumer.subscriptions.create(
        { 
          channel: "NotificationChannel", 
          notification_type: "document_specific",
          document_id: this.documentId 
        },
        {
          connected: () => {
            console.log("Connected to NotificationChannel")
            this.emit("channel:notification:connected")
            resolve()
          },

          disconnected: () => {
            console.log("Disconnected from NotificationChannel")
            this.emit("channel:notification:disconnected")
          },

          rejected: () => {
            console.error("NotificationChannel subscription rejected")
            this.emit("channel:notification:rejected")
            reject(new Error("NotificationChannel subscription rejected"))
          },

          received: (data) => {
            this.handleNotificationChannelMessage(data)
          }
        }
      )
    })
  }

  // Handle document channel messages
  handleDocumentChannelMessage(data) {
    const { type } = data

    switch (type) {
    case "user_joined_editing":
      this.handleUserJoined(data)
      break
    case "user_left_editing":
      this.handleUserLeft(data)
      break
    case "operation_applied":
      this.handleOperationApplied(data)
      break
    case "operation_confirmed":
      this.handleOperationConfirmed(data)
      break
    case "operation_error":
      this.handleOperationError(data)
      break
    case "batch_operations_applied":
      this.handleBatchOperationsApplied(data)
      break
    case "cursor_moved":
      this.handleCursorMoved(data)
      break
    case "selection_changed":
      this.handleSelectionChanged(data)
      break
    case "cursor_transformed":
      this.handleCursorTransformed(data)
      break
    case "document_sync":
      this.handleDocumentSync(data)
      break
    case "sync_confirmed":
      this.handleSyncConfirmed(data)
      break
    case "conflict_resolved":
      this.handleConflictResolved(data)
      break
    case "version_created":
      this.handleVersionCreated(data)
      break
    default:
      console.warn("Unknown document channel message type:", type, data)
    }
  }

  // Handle notification channel messages
  handleNotificationChannelMessage(data) {
    const { type } = data

    switch (type) {
    case "batch_notifications":
      data.notifications.forEach(notification => {
        this.emit("notification:received", notification)
      })
      break
    case "collaboration_invitation":
    case "user_mention":
    case "document_shared":
    case "system_maintenance":
    case "feature_announcement":
      this.emit("notification:received", data)
      break
    default:
      // Handle typing notifications and other real-time updates
      if (data.user_id && data.user_id !== this.currentUser.id) {
        this.emit("notification:received", data)
      }
    }
  }

  // Operation management
  async sendOperation(operation) {
    if (!this.isConnected || !this.documentChannel) {
      this.queueOperation(operation)
      return { success: false, error: "Not connected" }
    }

    const operationId = this.generateOperationId()
    const enrichedOperation = {
      ...operation,
      operation_id: operationId,
      timestamp: Date.now(),
      user_id: this.currentUser.id
    }

    try {
      // Add to pending operations
      this.pendingOperations.set(operationId, enrichedOperation)

      // Send to server
      this.documentChannel.perform("edit_operation", enrichedOperation)

      // Start timeout for operation acknowledgment
      setTimeout(() => {
        if (this.pendingOperations.has(operationId)) {
          this.handleOperationTimeout(operationId)
        }
      }, 10000) // 10 second timeout

      return { success: true, operationId }
    } catch (error) {
      this.pendingOperations.delete(operationId)
      console.error("Failed to send operation:", error)
      return { success: false, error: error.message }
    }
  }

  // Send batch operations
  async sendBatchOperations(operations) {
    if (!this.isConnected || !this.documentChannel) {
      operations.forEach(op => this.queueOperation(op))
      return { success: false, error: "Not connected" }
    }

    const enrichedOperations = operations.map(operation => ({
      ...operation,
      operation_id: this.generateOperationId(),
      timestamp: Date.now(),
      user_id: this.currentUser.id
    }))

    try {
      this.documentChannel.perform("batch_operations", {
        operations: enrichedOperations
      })

      return { success: true, operationCount: operations.length }
    } catch (error) {
      console.error("Failed to send batch operations:", error)
      return { success: false, error: error.message }
    }
  }

  // Queue operation for when connection is restored
  queueOperation(operation) {
    if (this.operationQueue.length >= this.options.operationQueueSize) {
      this.operationQueue.shift() // Remove oldest operation
    }
    this.operationQueue.push(operation)
  }

  // Process queued operations
  async processQueuedOperations() {
    if (!this.isConnected || this.operationQueue.length === 0) return

    console.log(`Processing ${this.operationQueue.length} queued operations`)

    const operations = [...this.operationQueue]
    this.operationQueue = []

    if (operations.length === 1) {
      await this.sendOperation(operations[0])
    } else {
      await this.sendBatchOperations(operations)
    }
  }

  // Cursor and presence management
  updateCursorPosition(position, selection = null) {
    if (!this.isConnected || !this.documentChannel) return

    this.documentChannel.perform("cursor_moved", {
      position,
      selection
    })
  }

  updateSelection(selection) {
    if (!this.isConnected || !this.documentChannel) return

    this.documentChannel.perform("selection_changed", {
      selection
    })
  }

  // Typing indicators
  startTyping() {
    if (!this.isConnected || !this.notificationChannel) return

    this.notificationChannel.perform("broadcast_typing", {
      type: "typing_started",
      user_id: this.currentUser.id,
      user_name: this.currentUser.name
    })

    // Auto-stop typing after delay
    this.debouncedTypingNotification()
  }

  stopTyping() {
    if (!this.isConnected || !this.notificationChannel) return

    this.notificationChannel.perform("broadcast_typing", {
      type: "typing_stopped",
      user_id: this.currentUser.id,
      user_name: this.currentUser.name
    })
  }

  sendTypingNotification(isTyping) {
    if (isTyping) {
      this.startTyping()
    } else {
      this.stopTyping()
    }
  }

  // Document synchronization
  async requestDocumentSync() {
    if (!this.isConnected || !this.documentChannel) return false

    try {
      this.documentChannel.perform("request_sync", {
        client_state_hash: this.documentState.stateHash
      })
      return true
    } catch (error) {
      console.error("Failed to request document sync:", error)
      return false
    }
  }

  checkDocumentSync() {
    this.requestDocumentSync()
  }

  // Conflict resolution
  async resolveConflict(conflictId, resolution) {
    if (!this.isConnected || !this.documentChannel) {
      return { success: false, error: "Not connected" }
    }

    try {
      this.documentChannel.perform("resolve_conflict", {
        conflict_id: conflictId,
        resolution
      })

      this.conflictResolutions.set(conflictId, {
        resolution,
        timestamp: Date.now(),
        resolved_by: this.currentUser.id
      })

      return { success: true }
    } catch (error) {
      console.error("Failed to resolve conflict:", error)
      return { success: false, error: error.message }
    }
  }

  // Version management
  async createVersion(versionData) {
    if (!this.isConnected || !this.documentChannel) {
      return { success: false, error: "Not connected" }
    }

    try {
      this.documentChannel.perform("create_version", {
        version_data: versionData
      })
      return { success: true }
    } catch (error) {
      console.error("Failed to create version:", error)
      return { success: false, error: error.message }
    }
  }

  // Event handlers for channel messages
  handleUserJoined(data) {
    const { user } = data
    this.collaborators.set(user.id, user)
    this.emit("collaborator:joined", user)
  }

  handleUserLeft(data) {
    const { user_id } = data
    this.collaborators.delete(user_id)
    this.cursors.delete(user_id)
    this.typingUsers.delete(user_id)
    this.emit("collaborator:left", { userId: user_id })
  }

  handleOperationApplied(data) {
    const { operation, user_id, conflicts } = data
    
    this.emit("operation:applied", {
      operation,
      userId: user_id,
      conflicts
    })

    // Update document state if we have content
    if (operation.content !== undefined) {
      this.updateDocumentState(operation)
    }
  }

  handleOperationConfirmed(data) {
    const { operation_id, status, conflicts } = data
    
    if (this.pendingOperations.has(operation_id)) {
      const operation = this.pendingOperations.get(operation_id)
      this.pendingOperations.delete(operation_id)
      this.acknowledgedOperations.add(operation_id)
      
      this.emit("operation:confirmed", {
        operationId: operation_id,
        operation,
        status,
        conflicts
      })
    }
  }

  handleOperationError(data) {
    const { error, operation } = data
    
    this.emit("operation:error", {
      error,
      operation
    })

    // Remove from pending if it has an ID
    if (operation?.operation_id) {
      this.pendingOperations.delete(operation.operation_id)
    }
  }

  handleBatchOperationsApplied(data) {
    const { operations, user_id } = data
    
    this.emit("batch:operations:applied", {
      operations,
      userId: user_id
    })
  }

  handleCursorMoved(data) {
    const { user_id, user_name, position } = data
    
    this.cursors.set(user_id, {
      userId: user_id,
      userName: user_name,
      position,
      timestamp: Date.now()
    })

    this.emit("cursor:moved", {
      userId: user_id,
      userName: user_name,
      position
    })
  }

  handleSelectionChanged(data) {
    const { user_id, user_name, selection } = data
    
    this.emit("selection:changed", {
      userId: user_id,
      userName: user_name,
      selection
    })
  }

  handleCursorTransformed(data) {
    const { user_id, new_position, operation } = data
    
    if (this.cursors.has(user_id)) {
      const cursor = this.cursors.get(user_id)
      cursor.position = new_position
      this.cursors.set(user_id, cursor)
    }

    this.emit("cursor:transformed", {
      userId: user_id,
      newPosition: new_position,
      operation
    })
  }

  handleDocumentSync(data) {
    const { content, state_hash, version, active_operations } = data
    
    this.documentState = {
      content,
      stateHash: state_hash,
      version
    }

    this.emit("document:synced", {
      content,
      stateHash: state_hash,
      version,
      activeOperations: active_operations
    })
  }

  handleSyncConfirmed(data) {
    this.emit("document:sync:confirmed", data)
  }

  handleConflictResolved(data) {
    const { conflict_id, resolved_by, final_content } = data
    
    this.conflictResolutions.delete(conflict_id)
    
    this.emit("conflict:resolved", {
      conflictId: conflict_id,
      resolvedBy: resolved_by,
      finalContent: final_content
    })
  }

  handleVersionCreated(data) {
    this.emit("version:created", data)
  }

  handleOperationTimeout(operationId) {
    const operation = this.pendingOperations.get(operationId)
    if (operation) {
      this.pendingOperations.delete(operationId)
      this.emit("operation:timeout", {
        operationId,
        operation
      })
    }
  }

  // Connection management
  async reconnect() {
    if (this.isConnected) return true

    if (this.reconnectAttempts >= this.options.maxReconnectAttempts) {
      this.emit("connection:max:attempts:reached")
      return false
    }

    this.reconnectAttempts++
    console.log(`Attempting to reconnect (${this.reconnectAttempts}/${this.options.maxReconnectAttempts})`)
    
    this.emit("connection:reconnecting", { 
      attempt: this.reconnectAttempts,
      maxAttempts: this.options.maxReconnectAttempts
    })

    const success = await this.initialize()
    
    if (success) {
      await this.processQueuedOperations()
    }

    return success
  }

  scheduleReconnect() {
    const delay = this.options.reconnectDelay * Math.pow(2, this.reconnectAttempts)
    setTimeout(() => {
      this.reconnect()
    }, Math.min(delay, 30000)) // Max 30 second delay
  }

  disconnect() {
    this.isConnected = false
    this.connectionState = "disconnected"
    
    if (this.documentChannel) {
      this.documentChannel.unsubscribe()
      this.documentChannel = null
    }
    
    if (this.notificationChannel) {
      this.notificationChannel.unsubscribe()
      this.notificationChannel = null
    }

    this.stopHeartbeat()
    this.stopPeriodicSync()
    
    this.emit("connection:disconnected")
  }

  // Heartbeat and periodic sync
  startHeartbeat() {
    this.heartbeatTimer = setInterval(() => {
      if (this.isConnected) {
        this.requestDocumentSync()
      }
    }, this.options.heartbeatInterval)
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = null
    }
  }

  startPeriodicSync() {
    this.syncTimer = setInterval(() => {
      this.throttledSyncCheck()
    }, this.options.syncInterval)
  }

  stopPeriodicSync() {
    if (this.syncTimer) {
      clearInterval(this.syncTimer)
      this.syncTimer = null
    }
  }

  // Utility methods
  updateDocumentState(operation) {
    // This would integrate with your document model/editor
    // For now, just emit the change
    this.emit("document:state:updated", operation)
  }

  generateOperationId() {
    return `op_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  // Event system
  on(event, callback) {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, [])
    }
    this.eventListeners.get(event).push(callback)
  }

  off(event, callback) {
    const listeners = this.eventListeners.get(event)
    if (listeners) {
      const index = listeners.indexOf(callback)
      if (index > -1) {
        listeners.splice(index, 1)
      }
    }
  }

  emit(event, data = {}) {
    const listeners = this.eventListeners.get(event)
    if (listeners) {
      listeners.forEach(callback => {
        try {
          callback(data)
        } catch (error) {
          console.error(`Error in event listener for ${event}:`, error)
        }
      })
    }
  }

  // Getters
  getCollaborators() {
    return Array.from(this.collaborators.values())
  }

  getCursors() {
    return Array.from(this.cursors.values())
  }

  getTypingUsers() {
    return Array.from(this.typingUsers)
  }

  getPendingOperationsCount() {
    return this.pendingOperations.size
  }

  getQueuedOperationsCount() {
    return this.operationQueue.length
  }

  isUserTyping(userId) {
    return this.typingUsers.has(userId)
  }

  getConnectionState() {
    return {
      isConnected: this.isConnected,
      state: this.connectionState,
      reconnectAttempts: this.reconnectAttempts,
      collaboratorsCount: this.collaborators.size,
      pendingOperations: this.pendingOperations.size,
      queuedOperations: this.operationQueue.length
    }
  }
}

export default CollaborationManager