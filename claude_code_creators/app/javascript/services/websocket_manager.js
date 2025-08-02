/**
 * WebSocketManager - Manages WebSocket connections with automatic reconnection and error handling
 * Provides a reliable foundation for real-time collaboration features
 */

import consumer from "../channels/consumer"

class WebSocketManager {
  constructor(options = {}) {
    this.options = {
      autoReconnect: true,
      reconnectDelay: 1000,
      maxReconnectDelay: 30000,
      maxReconnectAttempts: 50,
      backoffMultiplier: 1.5,
      connectionTimeout: 10000,
      heartbeatInterval: 30000,
      pingTimeout: 5000,
      ...options
    }

    // Connection state
    this.isConnected = false
    this.connectionState = "disconnected" // 'connecting', 'connected', 'disconnected', 'error', 'reconnecting'
    this.reconnectAttempts = 0
    this.lastDisconnectTime = null
    this.connectionStartTime = null

    // Event listeners
    this.eventListeners = new Map()

    // Timers
    this.reconnectTimer = null
    this.heartbeatTimer = null
    this.connectionTimer = null
    this.pingTimer = null

    // Connection monitoring
    this.connectionQuality = "good" // 'good', 'poor', 'bad'
    this.latencyHistory = []
    this.maxLatencyHistory = 20

    this.initialize()
  }

  initialize() {
    this.setupConsumerCallbacks()
    this.startMonitoring()
    
    // Initial connection attempt
    this.connect()
  }

  // Setup ActionCable consumer callbacks
  setupConsumerCallbacks() {
    // Override consumer connection callbacks
    const originalConnected = consumer.connection.monitor.connected
    const originalDisconnected = consumer.connection.monitor.disconnected

    consumer.connection.monitor.connected = () => {
      this.handleConnected()
      if (originalConnected) originalConnected.call(consumer.connection.monitor)
    }

    consumer.connection.monitor.disconnected = () => {
      this.handleDisconnected()
      if (originalDisconnected) originalDisconnected.call(consumer.connection.monitor)
    }

    // Monitor connection state changes
    consumer.connection.monitor.onopen = (event) => {
      this.handleConnectionOpen(event)
    }

    consumer.connection.monitor.onclose = (event) => {
      this.handleConnectionClose(event)
    }

    consumer.connection.monitor.onerror = (event) => {
      this.handleConnectionError(event)
    }
  }

  // Connection management
  connect() {
    if (this.isConnected || this.connectionState === "connecting") {
      return Promise.resolve()
    }

    return new Promise((resolve, reject) => {
      this.connectionState = "connecting"
      this.connectionStartTime = Date.now()
      this.emit("connection:attempt", { attempt: this.reconnectAttempts + 1 })

      // Set connection timeout
      this.connectionTimer = setTimeout(() => {
        if (this.connectionState === "connecting") {
          this.handleConnectionTimeout()
          reject(new Error("Connection timeout"))
        }
      }, this.options.connectionTimeout)

      // Store resolve/reject for later use
      this._connectionResolve = resolve
      this._connectionReject = reject

      // Trigger ActionCable connection
      consumer.connection.open()
    })
  }

  disconnect() {
    this.stopReconnecting()
    this.stopHeartbeat()
    this.clearConnectionTimer()

    this.isConnected = false
    this.connectionState = "disconnected"
    this.emit("connection:disconnected", { manual: true })

    consumer.connection.close()
  }

  // Connection event handlers
  handleConnected() {
    const connectionTime = Date.now() - (this.connectionStartTime || Date.now())
    
    this.isConnected = true
    this.connectionState = "connected"
    this.lastDisconnectTime = null
    this.clearConnectionTimer()

    // Reset reconnect attempts on successful connection
    if (this.reconnectAttempts > 0) {
      console.log(`WebSocket reconnected after ${this.reconnectAttempts} attempts`)
      this.reconnectAttempts = 0
    }

    this.emit("connection:established", { 
      connectionTime,
      reconnectAttempts: this.reconnectAttempts
    })

    this.startHeartbeat()
    this.updateConnectionQuality("good")

    // Resolve connection promise if pending
    if (this._connectionResolve) {
      this._connectionResolve()
      this._connectionResolve = null
      this._connectionReject = null
    }
  }

  handleDisconnected() {
    const wasConnected = this.isConnected
    
    this.isConnected = false
    this.lastDisconnectTime = Date.now()
    this.stopHeartbeat()

    if (wasConnected) {
      this.emit("connection:lost")
    }

    if (this.options.autoReconnect && this.connectionState !== "disconnected") {
      this.scheduleReconnect()
    } else {
      this.connectionState = "disconnected"
      this.emit("connection:disconnected", { manual: false })
    }
  }

  handleConnectionOpen(event) {
    console.log("WebSocket connection opened")
    this.emit("connection:open", { event })
  }

  handleConnectionClose(event) {
    console.log("WebSocket connection closed", event.code, event.reason)
    this.emit("connection:close", { 
      code: event.code, 
      reason: event.reason,
      wasClean: event.wasClean
    })

    // Analyze close code for reconnection strategy
    if (event.code === 1000 || event.code === 1001) {
      // Normal closure or going away - don't auto-reconnect aggressively
      this.options.reconnectDelay = Math.max(this.options.reconnectDelay, 5000)
    } else if (event.code >= 4000) {
      // Application-specific error - might be authorization or other issues
      this.emit("connection:error", { 
        type: "application_error",
        code: event.code,
        reason: event.reason
      })
    }
  }

  handleConnectionError(event) {
    console.error("WebSocket connection error:", event)
    this.connectionState = "error"
    this.updateConnectionQuality("bad")
    
    this.emit("connection:error", { 
      type: "websocket_error",
      event
    })

    // Reject connection promise if pending
    if (this._connectionReject) {
      this._connectionReject(new Error("WebSocket connection error"))
      this._connectionResolve = null
      this._connectionReject = null
    }
  }

  handleConnectionTimeout() {
    console.warn("WebSocket connection timeout")
    this.connectionState = "error"
    this.clearConnectionTimer()
    
    this.emit("connection:timeout")
    
    if (this.options.autoReconnect) {
      this.scheduleReconnect()
    }
  }

  // Reconnection logic
  scheduleReconnect() {
    if (this.reconnectAttempts >= this.options.maxReconnectAttempts) {
      this.connectionState = "error"
      this.emit("connection:max_attempts_reached", {
        attempts: this.reconnectAttempts
      })
      return
    }

    this.connectionState = "reconnecting"
    this.reconnectAttempts++

    const delay = Math.min(
      this.options.reconnectDelay * Math.pow(this.options.backoffMultiplier, this.reconnectAttempts - 1),
      this.options.maxReconnectDelay
    )

    console.log(`Scheduling reconnect attempt ${this.reconnectAttempts} in ${delay}ms`)
    
    this.emit("connection:reconnect_scheduled", {
      attempt: this.reconnectAttempts,
      delay,
      maxAttempts: this.options.maxReconnectAttempts
    })

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null
      this.connect().catch(error => {
        console.error("Reconnection attempt failed:", error)
        this.scheduleReconnect()
      })
    }, delay)
  }

  stopReconnecting() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
  }

  forceReconnect() {
    this.stopReconnecting()
    this.reconnectAttempts = 0
    this.disconnect()
    
    setTimeout(() => {
      this.connect()
    }, 1000)
  }

  // Connection monitoring and heartbeat
  startMonitoring() {
    // Monitor ActionCable connection state
    setInterval(() => {
      this.checkConnectionHealth()
    }, 5000)
  }

  checkConnectionHealth() {
    if (!this.isConnected) return

    const now = Date.now()
    
    // Check if we haven't received any messages recently
    const lastActivity = consumer.connection.monitor.getState().lastPingAt
    if (lastActivity && (now - lastActivity) > this.options.heartbeatInterval * 2) {
      console.warn("Connection appears stale, forcing reconnect")
      this.updateConnectionQuality("poor")
      this.forceReconnect()
    }
  }

  startHeartbeat() {
    this.stopHeartbeat()
    
    this.heartbeatTimer = setInterval(() => {
      this.sendHeartbeat()
    }, this.options.heartbeatInterval)
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = null
    }
  }

  sendHeartbeat() {
    if (!this.isConnected) return

    const startTime = Date.now()
    
    // Use ActionCable's ping mechanism
    consumer.connection.monitor.ping()
    
    // Measure response time
    this.pingTimer = setTimeout(() => {
      const latency = Date.now() - startTime
      this.recordLatency(latency)
      
      if (latency > 2000) {
        this.updateConnectionQuality("poor")
      } else if (latency > 5000) {
        this.updateConnectionQuality("bad")
      } else {
        this.updateConnectionQuality("good")
      }
    }, this.options.pingTimeout)
  }

  recordLatency(latency) {
    this.latencyHistory.push(latency)
    if (this.latencyHistory.length > this.maxLatencyHistory) {
      this.latencyHistory.shift()
    }

    this.emit("connection:latency", { latency })
  }

  updateConnectionQuality(quality) {
    if (this.connectionQuality !== quality) {
      const previousQuality = this.connectionQuality
      this.connectionQuality = quality
      
      this.emit("connection:quality_changed", {
        quality,
        previousQuality
      })
    }
  }

  // Utility methods
  clearConnectionTimer() {
    if (this.connectionTimer) {
      clearTimeout(this.connectionTimer)
      this.connectionTimer = null
    }
  }

  getConnectionInfo() {
    const avgLatency = this.latencyHistory.length > 0 
      ? this.latencyHistory.reduce((a, b) => a + b, 0) / this.latencyHistory.length 
      : 0

    return {
      isConnected: this.isConnected,
      connectionState: this.connectionState,
      reconnectAttempts: this.reconnectAttempts,
      connectionQuality: this.connectionQuality,
      averageLatency: Math.round(avgLatency),
      latencyHistory: [...this.latencyHistory],
      lastDisconnectTime: this.lastDisconnectTime,
      uptime: this.isConnected && this.connectionStartTime 
        ? Date.now() - this.connectionStartTime 
        : 0
    }
  }

  getSubscriptionCount() {
    return consumer.subscriptions.subscriptions.length
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
          console.error(`Error in WebSocketManager event listener for ${event}:`, error)
        }
      })
    }
  }

  // Configuration updates
  updateOptions(newOptions) {
    this.options = { ...this.options, ...newOptions }
  }

  // Cleanup
  destroy() {
    this.stopReconnecting()
    this.stopHeartbeat()
    this.clearConnectionTimer()
    
    if (this.pingTimer) {
      clearTimeout(this.pingTimer)
      this.pingTimer = null
    }

    this.eventListeners.clear()
    this.disconnect()
  }
}

// Export singleton instance
const webSocketManager = new WebSocketManager()
export default webSocketManager

// Also export the class for testing
export { WebSocketManager }