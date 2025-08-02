/**
 * CollaborationErrorHandler - Centralized error handling for collaboration features
 * Provides error recovery, user feedback, and diagnostic information
 */

class CollaborationErrorHandler {
  constructor(options = {}) {
    this.options = {
      enableRetry: true,
      maxRetryAttempts: 3,
      retryDelay: 1000,
      retryBackoffMultiplier: 2,
      enableUserNotifications: true,
      enableLogging: true,
      enableDiagnostics: true,
      fallbackMode: "offline",
      ...options
    }

    // Error tracking
    this.errorHistory = []
    this.maxErrorHistory = 100
    this.errorCounts = new Map() // errorType -> count
    this.retryAttempts = new Map() // operationId -> attemptCount

    // Recovery strategies
    this.recoveryStrategies = new Map()
    this.setupDefaultRecoveryStrategies()

    // Event listeners
    this.eventListeners = new Map()

    // Error rate monitoring
    this.errorRateWindow = 60000 // 1 minute
    this.errorRateThreshold = 10 // errors per minute
    this.lastErrorRateCheck = Date.now()

    console.log("CollaborationErrorHandler initialized")
  }

  // Setup default recovery strategies
  setupDefaultRecoveryStrategies() {
    // Connection errors
    this.recoveryStrategies.set("CONNECTION_LOST", {
      type: "retry",
      maxAttempts: 5,
      delay: 2000,
      backoff: true,
      userMessage: "Connection lost. Attempting to reconnect...",
      fallback: "offline_mode"
    })

    this.recoveryStrategies.set("CONNECTION_TIMEOUT", {
      type: "retry",
      maxAttempts: 3,
      delay: 1000,
      backoff: true,
      userMessage: "Connection timeout. Retrying...",
      fallback: "offline_mode"
    })

    // Operation errors
    this.recoveryStrategies.set("OPERATION_FAILED", {
      type: "queue_and_retry",
      maxAttempts: 3,
      delay: 500,
      backoff: true,
      userMessage: "Operation failed. Retrying...",
      fallback: "local_storage"
    })

    this.recoveryStrategies.set("OPERATION_TIMEOUT", {
      type: "retry",
      maxAttempts: 2,
      delay: 1000,
      backoff: false,
      userMessage: "Operation timed out. Retrying...",
      fallback: "manual_sync"
    })

    this.recoveryStrategies.set("OPERATION_CONFLICT", {
      type: "resolve_conflict",
      maxAttempts: 1,
      delay: 0,
      backoff: false,
      userMessage: "Conflict detected. Attempting automatic resolution...",
      fallback: "manual_resolution"
    })

    // Sync errors
    this.recoveryStrategies.set("SYNC_FAILED", {
      type: "full_sync",
      maxAttempts: 3,
      delay: 2000,
      backoff: true,
      userMessage: "Synchronization failed. Attempting full sync...",
      fallback: "read_only_mode"
    })

    this.recoveryStrategies.set("VERSION_MISMATCH", {
      type: "force_sync",
      maxAttempts: 1,
      delay: 0,
      backoff: false,
      userMessage: "Document version mismatch. Synchronizing...",
      fallback: "reload_required"
    })

    // Server errors
    this.recoveryStrategies.set("SERVER_ERROR", {
      type: "retry_with_backoff",
      maxAttempts: 3,
      delay: 5000,
      backoff: true,
      userMessage: "Server error. Retrying...",
      fallback: "offline_mode"
    })

    this.recoveryStrategies.set("AUTHENTICATION_FAILED", {
      type: "reauthenticate",
      maxAttempts: 1,
      delay: 0,
      backoff: false,
      userMessage: "Authentication expired. Please re-authenticate.",
      fallback: "logout_required"
    })

    // Channel errors
    this.recoveryStrategies.set("CHANNEL_REJECTED", {
      type: "resubscribe",
      maxAttempts: 2,
      delay: 1000,
      backoff: true,
      userMessage: "Channel subscription rejected. Retrying...",
      fallback: "permission_error"
    })

    this.recoveryStrategies.set("CHANNEL_DISCONNECTED", {
      type: "reconnect_channel",
      maxAttempts: 5,
      delay: 1000,
      backoff: true,
      userMessage: "Channel disconnected. Reconnecting...",
      fallback: "offline_mode"
    })
  }

  // Main error handling method
  handleError(error, context = {}) {
    const errorInfo = this.analyzeError(error, context)
    this.recordError(errorInfo)

    // Check error rate
    if (this.isErrorRateHigh()) {
      return this.handleHighErrorRate(errorInfo)
    }

    // Get recovery strategy
    const strategy = this.getRecoveryStrategy(errorInfo.type)
    if (!strategy) {
      return this.handleUnknownError(errorInfo)
    }

    // Execute recovery strategy
    return this.executeRecoveryStrategy(errorInfo, strategy, context)
  }

  // Error analysis
  analyzeError(error, context) {
    let errorType = "UNKNOWN_ERROR"
    let severity = "medium"
    let isRetryable = true
    let diagnostics = {}

    // Analyze error based on type and message
    if (error instanceof Error) {
      const message = error.message.toLowerCase()
      
      if (message.includes("network") || message.includes("connection")) {
        errorType = "CONNECTION_LOST"
        severity = "high"
      } else if (message.includes("timeout")) {
        errorType = message.includes("connection") ? "CONNECTION_TIMEOUT" : "OPERATION_TIMEOUT"
        severity = "medium"
      } else if (message.includes("conflict")) {
        errorType = "OPERATION_CONFLICT"
        severity = "low"
      } else if (message.includes("sync")) {
        errorType = "SYNC_FAILED"
        severity = "medium"
      } else if (message.includes("version")) {
        errorType = "VERSION_MISMATCH"
        severity = "medium"
      } else if (message.includes("auth")) {
        errorType = "AUTHENTICATION_FAILED"
        severity = "critical"
        isRetryable = false
      } else if (message.includes("rejected")) {
        errorType = "CHANNEL_REJECTED"
        severity = "high"
      } else if (message.includes("server") || error.status >= 500) {
        errorType = "SERVER_ERROR"
        severity = "high"
      }
    }

    // Analyze context for additional information
    if (context.operationType) {
      if (errorType === "UNKNOWN_ERROR") {
        errorType = "OPERATION_FAILED"
      }
      diagnostics.operationType = context.operationType
    }

    if (context.channelName) {
      if (errorType === "UNKNOWN_ERROR") {
        errorType = "CHANNEL_DISCONNECTED"
      }
      diagnostics.channelName = context.channelName
    }

    // Generate diagnostics
    diagnostics = {
      ...diagnostics,
      timestamp: Date.now(),
      userAgent: navigator.userAgent,
      connectionType: this.getConnectionType(),
      documentId: context.documentId,
      userId: context.userId,
      stackTrace: error.stack,
      errorCode: error.code,
      errorStatus: error.status
    }

    return {
      type: errorType,
      severity,
      isRetryable,
      originalError: error,
      message: error.message,
      context,
      diagnostics,
      id: this.generateErrorId()
    }
  }

  recordError(errorInfo) {
    // Add to history
    this.errorHistory.unshift(errorInfo)
    if (this.errorHistory.length > this.maxErrorHistory) {
      this.errorHistory.pop()
    }

    // Update counts
    const currentCount = this.errorCounts.get(errorInfo.type) || 0
    this.errorCounts.set(errorInfo.type, currentCount + 1)

    // Log error if enabled
    if (this.options.enableLogging) {
      this.logError(errorInfo)
    }

    // Emit error event
    this.emit("error:recorded", errorInfo)
  }

  // Recovery strategy execution
  executeRecoveryStrategy(errorInfo, strategy, context) {
    const { type: recoveryType, maxAttempts, delay, backoff, userMessage, fallback } = strategy

    // Check retry attempts
    const attemptCount = this.retryAttempts.get(errorInfo.id) || 0
    if (attemptCount >= maxAttempts) {
      return this.executeFallbackStrategy(errorInfo, fallback, context)
    }

    // Show user message if enabled
    if (this.options.enableUserNotifications && userMessage) {
      this.showUserNotification(userMessage, errorInfo.severity)
    }

    // Execute recovery based on type
    switch (recoveryType) {
    case "retry":
      return this.executeRetryStrategy(errorInfo, strategy, context)
    case "queue_and_retry":
      return this.executeQueueAndRetryStrategy(errorInfo, strategy, context)
    case "resolve_conflict":
      return this.executeConflictResolutionStrategy(errorInfo, strategy, context)
    case "full_sync":
      return this.executeFullSyncStrategy(errorInfo, strategy, context)
    case "force_sync":
      return this.executeForceSyncStrategy(errorInfo, strategy, context)
    case "retry_with_backoff":
      return this.executeRetryWithBackoffStrategy(errorInfo, strategy, context)
    case "reauthenticate":
      return this.executeReauthenticationStrategy(errorInfo, strategy, context)
    case "resubscribe":
      return this.executeResubscribeStrategy(errorInfo, strategy, context)
    case "reconnect_channel":
      return this.executeReconnectChannelStrategy(errorInfo, strategy, context)
    default:
      return this.handleUnknownRecoveryType(errorInfo, strategy, context)
    }
  }

  // Specific recovery strategy implementations
  executeRetryStrategy(errorInfo, strategy, context) {
    const attemptCount = this.retryAttempts.get(errorInfo.id) || 0
    this.retryAttempts.set(errorInfo.id, attemptCount + 1)

    const delay = strategy.backoff 
      ? strategy.delay * Math.pow(this.options.retryBackoffMultiplier, attemptCount)
      : strategy.delay

    setTimeout(() => {
      this.emit("recovery:retry", { errorInfo, attemptCount: attemptCount + 1, delay })
      
      if (context.retryCallback) {
        context.retryCallback()
      }
    }, delay)

    return { 
      strategy: "retry", 
      delay, 
      attempt: attemptCount + 1,
      maxAttempts: strategy.maxAttempts
    }
  }

  executeQueueAndRetryStrategy(errorInfo, strategy, context) {
    // Queue the operation for later retry
    this.emit("recovery:queue_operation", { errorInfo, context })
    
    return this.executeRetryStrategy(errorInfo, strategy, context)
  }

  executeConflictResolutionStrategy(errorInfo, strategy, context) {
    this.emit("recovery:resolve_conflict", { errorInfo, context })
    
    return {
      strategy: "conflict_resolution",
      requiresUserInput: true
    }
  }

  executeFullSyncStrategy(errorInfo, strategy, context) {
    this.emit("recovery:full_sync", { errorInfo, context })
    
    return { strategy: "full_sync" }
  }

  executeForceSyncStrategy(errorInfo, strategy, context) {
    this.emit("recovery:force_sync", { errorInfo, context })
    
    return { strategy: "force_sync" }
  }

  executeRetryWithBackoffStrategy(errorInfo, strategy, context) {
    return this.executeRetryStrategy(errorInfo, { ...strategy, backoff: true }, context)
  }

  executeReauthenticationStrategy(errorInfo, strategy, context) {
    this.emit("recovery:reauthenticate", { errorInfo, context })
    
    return {
      strategy: "reauthenticate",
      requiresUserAction: true,
      userMessage: "Please log in again to continue."
    }
  }

  executeResubscribeStrategy(errorInfo, strategy, context) {
    this.emit("recovery:resubscribe", { errorInfo, context })
    
    return this.executeRetryStrategy(errorInfo, strategy, context)
  }

  executeReconnectChannelStrategy(errorInfo, strategy, context) {
    this.emit("recovery:reconnect_channel", { errorInfo, context })
    
    return this.executeRetryStrategy(errorInfo, strategy, context)
  }

  // Fallback strategies
  executeFallbackStrategy(errorInfo, fallback, context) {
    switch (fallback) {
    case "offline_mode":
      return this.enableOfflineMode(errorInfo, context)
    case "local_storage":
      return this.enableLocalStorageMode(errorInfo, context)
    case "manual_sync":
      return this.enableManualSyncMode(errorInfo, context)
    case "manual_resolution":
      return this.enableManualResolutionMode(errorInfo, context)
    case "read_only_mode":
      return this.enableReadOnlyMode(errorInfo, context)
    case "reload_required":
      return this.requirePageReload(errorInfo, context)
    case "logout_required":
      return this.requireLogout(errorInfo, context)
    case "permission_error":
      return this.showPermissionError(errorInfo, context)
    default:
      return this.showGenericError(errorInfo, context)
    }
  }

  enableOfflineMode(errorInfo, context) {
    this.emit("fallback:offline_mode", { errorInfo, context })
    this.showUserNotification("Working offline. Changes will sync when connection is restored.", "warning")
    
    return { strategy: "offline_mode", persistent: true }
  }

  enableLocalStorageMode(errorInfo, context) {
    this.emit("fallback:local_storage", { errorInfo, context })
    this.showUserNotification("Saving changes locally. Will sync when possible.", "warning")
    
    return { strategy: "local_storage", persistent: true }
  }

  enableManualSyncMode(errorInfo, context) {
    this.emit("fallback:manual_sync", { errorInfo, context })
    this.showUserNotification("Automatic sync disabled. Use the sync button to update.", "warning")
    
    return { strategy: "manual_sync", requiresUserAction: true }
  }

  enableManualResolutionMode(errorInfo, context) {
    this.emit("fallback:manual_resolution", { errorInfo, context })
    this.showUserNotification("Manual conflict resolution required.", "warning")
    
    return { strategy: "manual_resolution", requiresUserInput: true }
  }

  enableReadOnlyMode(errorInfo, context) {
    this.emit("fallback:read_only", { errorInfo, context })
    this.showUserNotification("Document is now read-only due to sync issues.", "error")
    
    return { strategy: "read_only", persistent: true }
  }

  requirePageReload(errorInfo, context) {
    this.emit("fallback:reload_required", { errorInfo, context })
    this.showUserNotification("Page reload required to continue.", "error")
    
    return { strategy: "reload_required", requiresUserAction: true }
  }

  requireLogout(errorInfo, context) {
    this.emit("fallback:logout_required", { errorInfo, context })
    this.showUserNotification("Please log out and log back in.", "error")
    
    return { strategy: "logout_required", requiresUserAction: true }
  }

  showPermissionError(errorInfo, context) {
    this.emit("fallback:permission_error", { errorInfo, context })
    this.showUserNotification("You do not have permission to access this document.", "error")
    
    return { strategy: "permission_error", terminal: true }
  }

  showGenericError(errorInfo, context) {
    this.emit("fallback:generic_error", { errorInfo, context })
    this.showUserNotification("An unexpected error occurred. Please try refreshing the page.", "error")
    
    return { strategy: "generic_error", terminal: true }
  }

  // Error rate monitoring
  isErrorRateHigh() {
    const now = Date.now()
    const windowStart = now - this.errorRateWindow
    
    const recentErrors = this.errorHistory.filter(
      error => error.diagnostics.timestamp > windowStart
    )
    
    return recentErrors.length > this.errorRateThreshold
  }

  handleHighErrorRate(errorInfo) {
    this.emit("error:rate_high", { 
      errorInfo, 
      recentErrorCount: this.getRecentErrorCount(),
      threshold: this.errorRateThreshold
    })
    
    this.showUserNotification(
      "Experiencing multiple errors. Switching to safe mode.",
      "critical"
    )
    
    return this.enableOfflineMode(errorInfo, { reason: "high_error_rate" })
  }

  getRecentErrorCount() {
    const windowStart = Date.now() - this.errorRateWindow
    return this.errorHistory.filter(
      error => error.diagnostics.timestamp > windowStart
    ).length
  }

  // Unknown error handling
  handleUnknownError(errorInfo) {
    this.emit("error:unknown", errorInfo)
    
    if (this.options.enableUserNotifications) {
      this.showUserNotification(
        "An unexpected error occurred. Our team has been notified.",
        "error"
      )
    }
    
    return { strategy: "unknown_error", logged: true }
  }

  handleUnknownRecoveryType(errorInfo, strategy, context) {
    console.warn("Unknown recovery type:", strategy.type)
    return this.handleUnknownError(errorInfo)
  }

  // Utility methods
  getRecoveryStrategy(errorType) {
    return this.recoveryStrategies.get(errorType)
  }

  setRecoveryStrategy(errorType, strategy) {
    this.recoveryStrategies.set(errorType, strategy)
  }

  generateErrorId() {
    return `error_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  getConnectionType() {
    if ("connection" in navigator) {
      return navigator.connection.effectiveType || "unknown"
    }
    return "unknown"
  }

  logError(errorInfo) {
    const logLevel = this.getLogLevel(errorInfo.severity)
    const logData = {
      type: errorInfo.type,
      message: errorInfo.message,
      severity: errorInfo.severity,
      context: errorInfo.context,
      diagnostics: errorInfo.diagnostics
    }
    
    console[logLevel]("Collaboration Error:", logData)
    
    // Send to external logging service if configured
    this.emit("error:log", { errorInfo, logLevel, logData })
  }

  getLogLevel(severity) {
    const levelMap = {
      low: "info",
      medium: "warn",
      high: "error",
      critical: "error"
    }
    
    return levelMap[severity] || "warn"
  }

  showUserNotification(message, severity) {
    this.emit("error:notification", { message, severity })
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
          console.error(`Error in error handler event listener for ${event}:`, error)
        }
      })
    }
  }

  // Public API
  getErrorHistory() {
    return [...this.errorHistory]
  }

  getErrorCounts() {
    return new Map(this.errorCounts)
  }

  getErrorStats() {
    const total = this.errorHistory.length
    const byType = {}
    const bySeverity = {}
    
    this.errorHistory.forEach(error => {
      byType[error.type] = (byType[error.type] || 0) + 1
      bySeverity[error.severity] = (bySeverity[error.severity] || 0) + 1
    })
    
    return {
      total,
      byType,
      bySeverity,
      recentErrorRate: this.getRecentErrorCount(),
      errorRateThreshold: this.errorRateThreshold
    }
  }

  clearErrorHistory() {
    this.errorHistory = []
    this.errorCounts.clear()
    this.retryAttempts.clear()
  }

  // Configuration
  updateOptions(newOptions) {
    this.options = { ...this.options, ...newOptions }
  }

  setErrorRateThreshold(threshold) {
    this.errorRateThreshold = threshold
  }

  setErrorRateWindow(windowMs) {
    this.errorRateWindow = windowMs
  }
}

// Export singleton instance
const collaborationErrorHandler = new CollaborationErrorHandler()
export default collaborationErrorHandler

// Also export the class for testing
export { CollaborationErrorHandler }