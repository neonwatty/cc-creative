/**
 * DocumentEditChannel - Frontend client for real-time document editing
 * Integrates with Rails DocumentEditChannel for operational transform and collaboration
 */

import consumer from "./consumer"

class DocumentEditChannel {
  constructor() {
    this.subscriptions = new Map() // documentId -> subscription
    this.callbacks = new Map() // documentId -> callbacks
  }

  // Subscribe to document editing for a specific document
  subscribe(documentId, callbacks = {}) {
    if (this.subscriptions.has(documentId)) {
      console.warn(`Already subscribed to document ${documentId}`)
      return this.subscriptions.get(documentId)
    }

    const subscription = consumer.subscriptions.create(
      { 
        channel: "DocumentEditChannel", 
        document_id: documentId 
      },
      {
        connected: () => {
          console.log(`Connected to DocumentEditChannel for document ${documentId}`)
          this.handleConnected(documentId, callbacks)
        },

        disconnected: () => {
          console.log(`Disconnected from DocumentEditChannel for document ${documentId}`)
          this.handleDisconnected(documentId, callbacks)
        },

        rejected: () => {
          console.error(`DocumentEditChannel subscription rejected for document ${documentId}`)
          this.handleRejected(documentId, callbacks)
        },

        received: (data) => {
          this.handleReceived(documentId, data, callbacks)
        }
      }
    )

    this.subscriptions.set(documentId, subscription)
    this.callbacks.set(documentId, callbacks)

    return subscription
  }

  // Unsubscribe from document editing
  unsubscribe(documentId) {
    const subscription = this.subscriptions.get(documentId)
    if (subscription) {
      subscription.unsubscribe()
      this.subscriptions.delete(documentId)
      this.callbacks.delete(documentId)
      console.log(`Unsubscribed from DocumentEditChannel for document ${documentId}`)
    }
  }

  // Send edit operation
  sendOperation(documentId, operation) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("edit_operation", operation)
  }

  // Send batch operations
  sendBatchOperations(documentId, operations) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("batch_operations", { operations })
  }

  // Send cursor movement
  sendCursorMovement(documentId, position, selection = null) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("cursor_moved", {
      position,
      selection
    })
  }

  // Send selection change
  sendSelectionChange(documentId, selection) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("selection_changed", { selection })
  }

  // Request cursor transformation
  requestCursorTransform(documentId, operation, cursorPosition) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("transform_cursor", {
      operation,
      cursor_position: cursorPosition
    })
  }

  // Request document sync
  requestSync(documentId, clientStateHash) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("request_sync", {
      client_state_hash: clientStateHash
    })
  }

  // Resolve conflict
  resolveConflict(documentId, conflictId, resolution) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("resolve_conflict", {
      conflict_id: conflictId,
      resolution
    })
  }

  // Create version
  createVersion(documentId, versionData) {
    const subscription = this.subscriptions.get(documentId)
    if (!subscription) {
      throw new Error(`Not subscribed to document ${documentId}`)
    }

    subscription.perform("create_version", {
      version_data: versionData
    })
  }

  // Connection event handlers
  handleConnected(documentId, callbacks) {
    if (callbacks.onConnected) {
      callbacks.onConnected(documentId)
    }
  }

  handleDisconnected(documentId, callbacks) {
    if (callbacks.onDisconnected) {
      callbacks.onDisconnected(documentId)
    }
  }

  handleRejected(documentId, callbacks) {
    if (callbacks.onRejected) {
      callbacks.onRejected(documentId)
    }
  }

  // Message handling
  handleReceived(documentId, data, callbacks) {
    const { type } = data

    switch (type) {
    case "user_joined_editing":
      this.handleUserJoinedEditing(documentId, data, callbacks)
      break
    case "user_left_editing":
      this.handleUserLeftEditing(documentId, data, callbacks)
      break
    case "operation_applied":
      this.handleOperationApplied(documentId, data, callbacks)
      break
    case "operation_confirmed":
      this.handleOperationConfirmed(documentId, data, callbacks)
      break
    case "operation_error":
      this.handleOperationError(documentId, data, callbacks)
      break
    case "batch_operations_applied":
      this.handleBatchOperationsApplied(documentId, data, callbacks)
      break
    case "batch_confirmed":
      this.handleBatchConfirmed(documentId, data, callbacks)
      break
    case "batch_error":
      this.handleBatchError(documentId, data, callbacks)
      break
    case "cursor_moved":
      this.handleCursorMoved(documentId, data, callbacks)
      break
    case "selection_changed":
      this.handleSelectionChanged(documentId, data, callbacks)
      break
    case "cursor_transformed":
      this.handleCursorTransformed(documentId, data, callbacks)
      break
    case "cursor_position_updated":
      this.handleCursorPositionUpdated(documentId, data, callbacks)
      break
    case "cursor_transform_error":
      this.handleCursorTransformError(documentId, data, callbacks)
      break
    case "document_sync":
      this.handleDocumentSync(documentId, data, callbacks)
      break
    case "sync_confirmed":
      this.handleSyncConfirmed(documentId, data, callbacks)
      break
    case "sync_error":
      this.handleSyncError(documentId, data, callbacks)
      break
    case "conflict_resolved":
      this.handleConflictResolved(documentId, data, callbacks)
      break
    case "conflict_resolution_confirmed":
      this.handleConflictResolutionConfirmed(documentId, data, callbacks)
      break
    case "conflict_resolution_error":
      this.handleConflictResolutionError(documentId, data, callbacks)
      break
    case "version_created":
      this.handleVersionCreated(documentId, data, callbacks)
      break
    case "version_creation_error":
      this.handleVersionCreationError(documentId, data, callbacks)
      break
    case "service_error":
      this.handleServiceError(documentId, data, callbacks)
      break
    default:
      console.warn(`Unknown message type: ${type}`, data)
      if (callbacks.onUnknownMessage) {
        callbacks.onUnknownMessage(documentId, data)
      }
    }
  }

  // Specific message handlers
  handleUserJoinedEditing(documentId, data, callbacks) {
    if (callbacks.onUserJoined) {
      callbacks.onUserJoined(documentId, data.user, data)
    }
  }

  handleUserLeftEditing(documentId, data, callbacks) {
    if (callbacks.onUserLeft) {
      callbacks.onUserLeft(documentId, data.user_id, data)
    }
  }

  handleOperationApplied(documentId, data, callbacks) {
    if (callbacks.onOperationApplied) {
      callbacks.onOperationApplied(documentId, data.operation, data)
    }
  }

  handleOperationConfirmed(documentId, data, callbacks) {
    if (callbacks.onOperationConfirmed) {
      callbacks.onOperationConfirmed(documentId, data.operation_id, data)
    }
  }

  handleOperationError(documentId, data, callbacks) {
    if (callbacks.onOperationError) {
      callbacks.onOperationError(documentId, data.error, data.operation, data)
    }
  }

  handleBatchOperationsApplied(documentId, data, callbacks) {
    if (callbacks.onBatchOperationsApplied) {
      callbacks.onBatchOperationsApplied(documentId, data.operations, data)
    }
  }

  handleBatchConfirmed(documentId, data, callbacks) {
    if (callbacks.onBatchConfirmed) {
      callbacks.onBatchConfirmed(documentId, data.applied_operations, data.final_content, data)
    }
  }

  handleBatchError(documentId, data, callbacks) {
    if (callbacks.onBatchError) {
      callbacks.onBatchError(documentId, data.error, data.failed_operation_index, data)
    }
  }

  handleCursorMoved(documentId, data, callbacks) {
    if (callbacks.onCursorMoved) {
      callbacks.onCursorMoved(documentId, data.user_id, data.user_name, data.position, data.selection, data)
    }
  }

  handleSelectionChanged(documentId, data, callbacks) {
    if (callbacks.onSelectionChanged) {
      callbacks.onSelectionChanged(documentId, data.user_id, data.user_name, data.selection, data)
    }
  }

  handleCursorTransformed(documentId, data, callbacks) {
    if (callbacks.onCursorTransformed) {
      callbacks.onCursorTransformed(documentId, data.user_id, data.old_position, data.new_position, data.operation, data)
    }
  }

  handleCursorPositionUpdated(documentId, data, callbacks) {
    if (callbacks.onCursorPositionUpdated) {
      callbacks.onCursorPositionUpdated(documentId, data.new_position, data.operation, data)
    }
  }

  handleCursorTransformError(documentId, data, callbacks) {
    if (callbacks.onCursorTransformError) {
      callbacks.onCursorTransformError(documentId, data.error, data)
    }
  }

  handleDocumentSync(documentId, data, callbacks) {
    if (callbacks.onDocumentSync) {
      callbacks.onDocumentSync(documentId, data.content, data.state_hash, data.version, data.active_operations, data)
    }
  }

  handleSyncConfirmed(documentId, data, callbacks) {
    if (callbacks.onSyncConfirmed) {
      callbacks.onSyncConfirmed(documentId, data.state_hash, data)
    }
  }

  handleSyncError(documentId, data, callbacks) {
    if (callbacks.onSyncError) {
      callbacks.onSyncError(documentId, data.error, data)
    }
  }

  handleConflictResolved(documentId, data, callbacks) {
    if (callbacks.onConflictResolved) {
      callbacks.onConflictResolved(documentId, data.conflict_id, data.resolved_by, data.final_content, data)
    }
  }

  handleConflictResolutionConfirmed(documentId, data, callbacks) {
    if (callbacks.onConflictResolutionConfirmed) {
      callbacks.onConflictResolutionConfirmed(documentId, data.conflict_id, data.final_content, data)
    }
  }

  handleConflictResolutionError(documentId, data, callbacks) {
    if (callbacks.onConflictResolutionError) {
      callbacks.onConflictResolutionError(documentId, data.error, data)
    }
  }

  handleVersionCreated(documentId, data, callbacks) {
    if (callbacks.onVersionCreated) {
      callbacks.onVersionCreated(documentId, data.version_number, data.version_name, data.created_by, data)
    }
  }

  handleVersionCreationError(documentId, data, callbacks) {
    if (callbacks.onVersionCreationError) {
      callbacks.onVersionCreationError(documentId, data.error, data)
    }
  }

  handleServiceError(documentId, data, callbacks) {
    if (callbacks.onServiceError) {
      callbacks.onServiceError(documentId, data.error, data)
    }
  }

  // Utility methods
  isSubscribed(documentId) {
    return this.subscriptions.has(documentId)
  }

  getSubscription(documentId) {
    return this.subscriptions.get(documentId)
  }

  getSubscribedDocuments() {
    return Array.from(this.subscriptions.keys())
  }

  unsubscribeAll() {
    for (const documentId of this.subscriptions.keys()) {
      this.unsubscribe(documentId)
    }
  }

  // Static factory method for convenience
  static create(documentId, callbacks = {}) {
    const channel = new DocumentEditChannel()
    return channel.subscribe(documentId, callbacks)
  }
}

// Export singleton instance
const documentEditChannel = new DocumentEditChannel()
export default documentEditChannel

// Also export the class for testing
export { DocumentEditChannel }