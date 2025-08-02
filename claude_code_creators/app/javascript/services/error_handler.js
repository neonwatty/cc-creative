/**
 * ErrorHandler - Comprehensive error handling for plugin failures
 * Provides error recovery, user notifications, and detailed logging
 */
export class ErrorHandler {
  constructor(options = {}) {
    this.options = {
      enableLogging: true,
      enableUserNotifications: true,
      enableErrorRecovery: true,
      maxRetries: 3,
      retryDelay: 1000,
      logToConsole: true,
      logToServer: true,
      showStackTrace: false,
      ...options
    }
    
    this.errorLog = []
    this.errorPatterns = new Map()
    this.recoveryStrategies = new Map()
    this.errorNotifications = new Map()
    this.eventEmitter = new EventTarget()
    
    this.init()
  }

  init() {
    this.setupGlobalErrorHandlers()
    this.setupErrorPatterns()
    this.setupRecoveryStrategies()
    this.createErrorNotificationSystem()
    
    this.emit("error-handler:initialized")
  }

  setupGlobalErrorHandlers() {
    // Handle unhandled promise rejections
    window.addEventListener("unhandledrejection", (event) => {
      this.handleError(event.reason, {
        type: "unhandled_promise_rejection",
        source: "global",
        event: event
      })
    })
    
    // Handle JavaScript errors
    window.addEventListener("error", (event) => {
      // Filter out errors from our sandbox iframe
      if (event.filename && event.filename.includes("sandbox")) {
        return // Let sandbox handle its own errors
      }
      
      this.handleError(event.error || new Error(event.message), {
        type: "javascript_error",
        source: "global",
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno,
        event: event
      })
    })
    
    // Handle fetch errors
    const originalFetch = window.fetch
    window.fetch = async (...args) => {
      try {
        const response = await originalFetch(...args)
        
        // Handle HTTP errors
        if (!response.ok) {
          const error = new Error(`HTTP ${response.status}: ${response.statusText}`)
          error.response = response
          this.handleError(error, {
            type: "http_error",
            source: "fetch",
            url: args[0],
            status: response.status
          })
        }
        
        return response
      } catch (error) {
        this.handleError(error, {
          type: "network_error",
          source: "fetch",
          url: args[0]
        })
        throw error
      }
    }
  }

  setupErrorPatterns() {
    // Define common error patterns and their handling
    const patterns = [
      {
        pattern: /plugin.*not.*found/i,
        category: "plugin_not_found",
        severity: "medium",
        userMessage: "Plugin not found. It may have been uninstalled or moved.",
        recovery: "refresh_plugin_list"
      },
      {
        pattern: /permission.*denied/i,
        category: "permission_denied",
        severity: "medium",
        userMessage: "Permission denied. Check plugin permissions.",
        recovery: "request_permission"
      },
      {
        pattern: /timeout/i,
        category: "timeout",
        severity: "low",
        userMessage: "Operation timed out. Please try again.",
        recovery: "retry_operation"
      },
      {
        pattern: /network.*error|fetch.*failed/i,
        category: "network_error",
        severity: "medium",
        userMessage: "Network error. Check your connection and try again.",
        recovery: "retry_with_delay"
      },
      {
        pattern: /memory.*exceeded|out.*of.*memory/i,
        category: "memory_error",
        severity: "high",
        userMessage: "Memory limit exceeded. Plugin has been terminated.",
        recovery: "terminate_plugin"
      },
      {
        pattern: /security.*violation|unsafe.*operation/i,
        category: "security_error",
        severity: "critical",
        userMessage: "Security violation detected. Plugin has been blocked.",
        recovery: "block_plugin"
      },
      {
        pattern: /rate.*limit.*exceeded/i,
        category: "rate_limit",
        severity: "low",
        userMessage: "Rate limit exceeded. Please wait before trying again.",
        recovery: "delay_retry"
      },
      {
        pattern: /api.*key.*invalid|authentication.*failed/i,
        category: "authentication_error",
        severity: "medium",
        userMessage: "Authentication failed. Check your API credentials.",
        recovery: "reauth_required"
      }
    ]
    
    patterns.forEach(pattern => {
      this.errorPatterns.set(pattern.pattern, pattern)
    })
  }

  setupRecoveryStrategies() {
    // Define recovery strategies for different error types
    const strategies = {
      refresh_plugin_list: async (context) => {
        if (window.PluginMarketplace) {
          await window.PluginMarketplace.refreshData()
          return { success: true, message: "Plugin list refreshed" }
        }
        return { success: false, message: "Plugin marketplace not available" }
      },
      
      request_permission: async (context) => {
        if (window.PermissionManager && context.pluginId) {
          try {
            const result = await window.PermissionManager.requestPermission(
              context.pluginId, 
              context.requiredPermission || "api_access"
            )
            return { success: result.granted, message: result.granted ? "Permission granted" : "Permission denied" }
          } catch (error) {
            return { success: false, message: "Permission request failed" }
          }
        }
        return { success: false, message: "Permission manager not available" }
      },
      
      retry_operation: async (context) => {
        if (context.retryFunction && context.retryCount < this.options.maxRetries) {
          try {
            const result = await context.retryFunction()
            return { success: true, message: "Operation successful on retry", result }
          } catch (error) {
            return { success: false, message: "Retry failed", error }
          }
        }
        return { success: false, message: "Max retries exceeded" }
      },
      
      retry_with_delay: async (context) => {
        const delay = this.options.retryDelay * Math.pow(2, context.retryCount || 0)
        await new Promise(resolve => setTimeout(resolve, delay))
        return await strategies.retry_operation(context)
      },
      
      terminate_plugin: async (context) => {
        if (window.PluginSandbox && context.pluginId) {
          window.PluginSandbox.terminateAllExecutions()
          return { success: true, message: "Plugin terminated due to resource constraints" }
        }
        return { success: false, message: "Could not terminate plugin" }
      },
      
      block_plugin: async (context) => {
        if (context.pluginId) {
          // Add plugin to blocked list
          const blocked = JSON.parse(localStorage.getItem("blocked-plugins") || "[]")
          if (!blocked.includes(context.pluginId)) {
            blocked.push(context.pluginId)
            localStorage.setItem("blocked-plugins", JSON.stringify(blocked))
          }
          return { success: true, message: "Plugin blocked for security violation" }
        }
        return { success: false, message: "Could not block plugin" }
      },
      
      delay_retry: async (context) => {
        const delay = 60000 // 1 minute delay for rate limits
        await new Promise(resolve => setTimeout(resolve, delay))
        return await strategies.retry_operation(context)
      },
      
      reauth_required: async (context) => {
        // Trigger re-authentication flow
        this.emit("error-handler:reauth-required", { context })
        return { success: false, message: "Re-authentication required" }
      }
    }
    
    Object.entries(strategies).forEach(([name, strategy]) => {
      this.recoveryStrategies.set(name, strategy)
    })
  }

  createErrorNotificationSystem() {
    // Create notification container
    this.notificationContainer = document.createElement("div")
    this.notificationContainer.className = "error-notifications"
    this.notificationContainer.innerHTML = `
      <div class="notifications-list"></div>
    `
    
    document.body.appendChild(this.notificationContainer)
  }

  // Main error handling method
  async handleError(error, context = {}) {
    try {
      // Create error record
      const errorRecord = this.createErrorRecord(error, context)
      
      // Log the error
      this.logError(errorRecord)
      
      // Classify the error
      const classification = this.classifyError(error, context)
      errorRecord.classification = classification
      
      // Attempt recovery if enabled
      let recoveryResult = null
      if (this.options.enableErrorRecovery && classification.recovery) {
        recoveryResult = await this.attemptRecovery(classification.recovery, {
          ...context,
          error: error,
          errorRecord: errorRecord
        })
        errorRecord.recoveryResult = recoveryResult
      }
      
      // Show user notification if enabled
      if (this.options.enableUserNotifications) {
        this.showUserNotification(errorRecord, classification, recoveryResult)
      }
      
      // Emit error event
      this.emit("error-handler:error", { errorRecord, classification, recoveryResult })
      
      return {
        handled: true,
        errorRecord: errorRecord,
        classification: classification,
        recoveryResult: recoveryResult
      }
      
    } catch (handlingError) {
      console.error("Error in error handler:", handlingError)
      this.showFallbackNotification(error)
      return { handled: false, error: handlingError }
    }
  }

  createErrorRecord(error, context) {
    const record = {
      id: this.generateErrorId(),
      timestamp: new Date().toISOString(),
      message: error.message || "Unknown error",
      stack: error.stack,
      name: error.name || "Error",
      type: context.type || "unknown",
      source: context.source || "unknown",
      context: context,
      userAgent: navigator.userAgent,
      url: window.location.href,
      severity: "unknown"
    }
    
    // Add additional context if available
    if (error.response) {
      record.httpStatus = error.response.status
      record.httpStatusText = error.response.statusText
    }
    
    return record
  }

  classifyError(error, context) {
    const message = error.message || ""
    
    // Check against known patterns
    for (const [pattern, classification] of this.errorPatterns) {
      if (pattern.test(message)) {
        return classification
      }
    }
    
    // Default classification based on context type
    const defaultClassifications = {
      network_error: {
        category: "network_error",
        severity: "medium",
        userMessage: "Network error occurred. Please check your connection.",
        recovery: "retry_with_delay"
      },
      plugin_error: {
        category: "plugin_error",
        severity: "medium",
        userMessage: "Plugin error occurred. The plugin may need to be restarted.",
        recovery: "restart_plugin"
      },
      widget_error: {
        category: "widget_error",
        severity: "low",
        userMessage: "Widget error occurred. You may need to recreate the widget.",
        recovery: "refresh_widget"
      }
    }
    
    return defaultClassifications[context.type] || {
      category: "unknown_error",
      severity: "medium",
      userMessage: "An unexpected error occurred. Please try again.",
      recovery: "retry_operation"
    }
  }

  async attemptRecovery(recoveryType, context) {
    const strategy = this.recoveryStrategies.get(recoveryType)
    if (!strategy) {
      return { success: false, message: `Unknown recovery strategy: ${recoveryType}` }
    }
    
    try {
      const result = await strategy(context)
      this.logRecoveryAttempt(context, recoveryType, result)
      return result
    } catch (error) {
      const result = { success: false, message: error.message, error }
      this.logRecoveryAttempt(context, recoveryType, result)
      return result
    }
  }

  logError(errorRecord) {
    // Add to internal log
    this.errorLog.push(errorRecord)
    
    // Keep only last 100 errors
    if (this.errorLog.length > 100) {
      this.errorLog.shift()
    }
    
    // Console logging
    if (this.options.logToConsole) {
      const logMethod = this.getConsoleMethod(errorRecord.classification?.severity)
      logMethod("[ErrorHandler]", errorRecord.message, {
        id: errorRecord.id,
        type: errorRecord.type,
        context: errorRecord.context,
        stack: this.options.showStackTrace ? errorRecord.stack : undefined
      })
    }
    
    // Server logging
    if (this.options.logToServer) {
      this.sendErrorToServer(errorRecord)
    }
  }

  logRecoveryAttempt(context, recoveryType, result) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      errorId: context.errorRecord?.id,
      recoveryType: recoveryType,
      success: result.success,
      message: result.message
    }
    
    if (this.options.logToConsole) {
      console.log("[ErrorHandler Recovery]", logEntry)
    }
  }

  getConsoleMethod(severity) {
    switch (severity) {
    case "critical":
    case "high":
      return console.error
    case "medium":
      return console.warn
    case "low":
    default:
      return console.info
    }
  }

  async sendErrorToServer(errorRecord) {
    try {
      // Don't send sensitive information
      const sanitizedRecord = {
        id: errorRecord.id,
        timestamp: errorRecord.timestamp,
        message: errorRecord.message,
        type: errorRecord.type,
        source: errorRecord.source,
        severity: errorRecord.classification?.severity,
        category: errorRecord.classification?.category,
        userAgent: errorRecord.userAgent,
        url: errorRecord.url
      }
      
      await fetch("/api/errors", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({ error: sanitizedRecord })
      })
    } catch (error) {
      console.warn("Failed to send error to server:", error)
    }
  }

  showUserNotification(errorRecord, classification, recoveryResult) {
    const notificationId = this.generateNotificationId()
    
    const notification = document.createElement("div")
    notification.className = `error-notification severity-${classification.severity}`
    notification.dataset.notificationId = notificationId
    notification.innerHTML = `
      <div class="notification-content">
        <div class="notification-header">
          <div class="notification-icon ${classification.category}"></div>
          <div class="notification-title">${this.getNotificationTitle(classification)}</div>
          <button type="button" class="notification-close" data-action="close">&times;</button>
        </div>
        
        <div class="notification-body">
          <div class="notification-message">${classification.userMessage}</div>
          
          ${recoveryResult ? `
          <div class="notification-recovery">
            ${recoveryResult.success ? 
    `<div class="recovery-success">✓ ${recoveryResult.message}</div>` :
    `<div class="recovery-failed">✗ ${recoveryResult.message}</div>`
}
          </div>
          ` : ""}
          
          <div class="notification-details" style="display: none;">
            <div class="error-id">Error ID: ${errorRecord.id}</div>
            <div class="error-time">${new Date(errorRecord.timestamp).toLocaleString()}</div>
            ${this.options.showStackTrace ? `<div class="error-stack">${errorRecord.stack}</div>` : ""}
          </div>
        </div>
        
        <div class="notification-actions">
          ${this.getNotificationActions(classification, errorRecord, recoveryResult)}
        </div>
      </div>
    `
    
    // Add event listeners
    this.bindNotificationEvents(notification, errorRecord, classification)
    
    // Add to container
    const notificationsList = this.notificationContainer.querySelector(".notifications-list")
    notificationsList.appendChild(notification)
    
    // Store notification reference
    this.errorNotifications.set(notificationId, {
      element: notification,
      errorRecord: errorRecord,
      classification: classification,
      recoveryResult: recoveryResult
    })
    
    // Auto-dismiss for low severity errors
    if (classification.severity === "low") {
      setTimeout(() => {
        this.dismissNotification(notificationId)
      }, 5000)
    }
    
    return notificationId
  }

  getNotificationTitle(classification) {
    const titles = {
      plugin_error: "Plugin Error",
      widget_error: "Widget Error",
      network_error: "Network Error",
      permission_denied: "Permission Denied",
      security_error: "Security Error",
      memory_error: "Memory Error",
      timeout: "Timeout Error"
    }
    
    return titles[classification.category] || "Error"
  }

  getNotificationActions(classification, errorRecord, recoveryResult) {
    const actions = []
    
    // Show details action
    actions.push("<button type=\"button\" class=\"btn btn-sm btn-secondary\" data-action=\"toggle-details\">Show Details</button>")
    
    // Retry action for failed recovery
    if (recoveryResult && !recoveryResult.success && classification.recovery) {
      actions.push("<button type=\"button\" class=\"btn btn-sm btn-primary\" data-action=\"retry\">Retry</button>")
    }
    
    // Specific actions based on error type
    switch (classification.category) {
    case "plugin_error":
      actions.push("<button type=\"button\" class=\"btn btn-sm btn-warning\" data-action=\"reload-plugin\">Reload Plugin</button>")
      break
    case "permission_denied":
      actions.push("<button type=\"button\" class=\"btn btn-sm btn-primary\" data-action=\"manage-permissions\">Manage Permissions</button>")
      break
    case "network_error":
      actions.push("<button type=\"button\" class=\"btn btn-sm btn-primary\" data-action=\"check-connection\">Check Connection</button>")
      break
    }
    
    // Report bug action for critical errors
    if (classification.severity === "critical") {
      actions.push("<button type=\"button\" class=\"btn btn-sm btn-danger\" data-action=\"report-bug\">Report Bug</button>")
    }
    
    return actions.join("")
  }

  bindNotificationEvents(notification, errorRecord, classification) {
    notification.addEventListener("click", async (e) => {
      const action = e.target.dataset.action
      if (!action) return
      
      e.preventDefault()
      
      switch (action) {
      case "close":
        this.dismissNotification(notification.dataset.notificationId)
        break
          
      case "toggle-details":
        const details = notification.querySelector(".notification-details")
        const isVisible = details.style.display !== "none"
        details.style.display = isVisible ? "none" : "block"
        e.target.textContent = isVisible ? "Show Details" : "Hide Details"
        break
          
      case "retry":
        await this.retryOperation(errorRecord, classification)
        break
          
      case "reload-plugin":
        await this.reloadPlugin(errorRecord.context.pluginId)
        break
          
      case "manage-permissions":
        if (window.PermissionManager) {
          window.PermissionManager.openPermissionModal("manage")
        }
        break
          
      case "check-connection":
        await this.checkNetworkConnection()
        break
          
      case "report-bug":
        this.openBugReport(errorRecord)
        break
      }
    })
  }

  async retryOperation(errorRecord, classification) {
    if (classification.recovery) {
      const result = await this.attemptRecovery(classification.recovery, {
        ...errorRecord.context,
        error: new Error(errorRecord.message),
        errorRecord: errorRecord,
        retryCount: (errorRecord.context.retryCount || 0) + 1
      })
      
      // Update notification with result
      // Implementation would update the notification UI
    }
  }

  async reloadPlugin(pluginId) {
    if (pluginId && window.PluginMarketplace) {
      // Implementation would reload the specific plugin
    }
  }

  async checkNetworkConnection() {
    try {
      const response = await fetch("/health", { method: "HEAD" })
      const status = response.ok ? "online" : "degraded"
      this.showTemporaryMessage(`Network status: ${status}`, "info")
    } catch (error) {
      this.showTemporaryMessage("Network appears to be offline", "error")
    }
  }

  openBugReport(errorRecord) {
    // Implementation would open a bug report modal or external link
    const bugReportUrl = `mailto:support@example.com?subject=Bug Report - ${errorRecord.id}&body=${encodeURIComponent(`
Error ID: ${errorRecord.id}
Time: ${errorRecord.timestamp}
Message: ${errorRecord.message}
Type: ${errorRecord.type}
Context: ${JSON.stringify(errorRecord.context, null, 2)}
    `)}`
    
    window.open(bugReportUrl)
  }

  showFallbackNotification(error) {
    alert(`An error occurred: ${error.message}. Please refresh the page and try again.`)
  }

  showTemporaryMessage(message, type = "info") {
    const temp = document.createElement("div")
    temp.className = `temp-notification ${type}`
    temp.textContent = message
    
    document.body.appendChild(temp)
    
    setTimeout(() => {
      temp.remove()
    }, 3000)
  }

  dismissNotification(notificationId) {
    const notification = this.errorNotifications.get(notificationId)
    if (notification) {
      notification.element.remove()
      this.errorNotifications.delete(notificationId)
    }
  }

  // Utility Methods
  generateErrorId() {
    return `error-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  }

  generateNotificationId() {
    return `notification-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  }

  // Public API
  getErrorLog() {
    return this.errorLog.slice() // Return copy
  }

  getErrorStats() {
    const stats = {
      total: this.errorLog.length,
      byType: {},
      bySeverity: {},
      byCategory: {},
      recentErrors: this.errorLog.slice(-10)
    }
    
    this.errorLog.forEach(error => {
      // Count by type
      stats.byType[error.type] = (stats.byType[error.type] || 0) + 1
      
      // Count by severity
      if (error.classification) {
        const severity = error.classification.severity
        stats.bySeverity[severity] = (stats.bySeverity[severity] || 0) + 1
        
        const category = error.classification.category
        stats.byCategory[category] = (stats.byCategory[category] || 0) + 1
      }
    })
    
    return stats
  }

  clearErrorLog() {
    this.errorLog = []
    this.emit("error-handler:log-cleared")
  }

  // Event System
  emit(eventName, detail = {}) {
    const event = new CustomEvent(eventName, { detail })
    this.eventEmitter.dispatchEvent(event)
  }

  on(eventName, callback) {
    this.eventEmitter.addEventListener(eventName, callback)
  }

  off(eventName, callback) {
    this.eventEmitter.removeEventListener(eventName, callback)
  }
}

// Export for module usage
export default ErrorHandler

// Create global instance
window.ErrorHandler = new ErrorHandler()