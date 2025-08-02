/**
 * PluginSandbox - Frontend service for safe plugin execution
 * Provides secure environment for running plugin code with resource monitoring
 */
export class PluginSandbox {
  constructor(options = {}) {
    this.options = {
      baseUrl: "/extensions",
      defaultTimeout: 30000, // 30 seconds
      maxMemoryUsage: 100 * 1024 * 1024, // 100MB
      maxExecutionTime: 60000, // 1 minute
      enableConsoleLogging: true,
      enableNetworkAccess: false,
      enableFileSystemAccess: false,
      enableDOMAccess: false,
      ...options
    }
    
    this.activeSandboxes = new Map()
    this.executionQueue = []
    this.isProcessingQueue = false
    this.eventEmitter = new EventTarget()
    this.performanceMonitor = new PerformanceMonitor()
    
    this.init()
  }

  async init() {
    try {
      // Initialize performance monitoring
      this.performanceMonitor.start()
      
      // Setup error handling
      this.setupErrorHandling()
      
      // Create sandbox iframe if needed
      await this.createSandboxEnvironment()
      
      this.emit("sandbox:initialized")
    } catch (error) {
      console.error("Failed to initialize PluginSandbox:", error)
      this.emit("sandbox:error", { error })
    }
  }

  async createSandboxEnvironment() {
    // Create isolated iframe for plugin execution
    this.sandboxFrame = document.createElement("iframe")
    this.sandboxFrame.style.display = "none"
    this.sandboxFrame.setAttribute("sandbox", "allow-scripts")
    this.sandboxFrame.src = "about:blank"
    
    document.body.appendChild(this.sandboxFrame)
    
    // Wait for iframe to load
    await new Promise((resolve) => {
      this.sandboxFrame.onload = resolve
    })
    
    // Initialize sandbox runtime
    await this.initializeSandboxRuntime()
  }

  async initializeSandboxRuntime() {
    const sandboxDoc = this.sandboxFrame.contentDocument
    const sandboxWindow = this.sandboxFrame.contentWindow
    
    // Inject sandbox runtime
    const script = sandboxDoc.createElement("script")
    script.textContent = this.getSandboxRuntime()
    sandboxDoc.head.appendChild(script)
    
    // Setup communication channel
    this.setupSandboxCommunication(sandboxWindow)
  }

  getSandboxRuntime() {
    return `
      // Plugin Sandbox Runtime
      window.PluginSandbox = {
        console: {
          log: (...args) => window.parent.postMessage({
            type: 'console.log',
            args: args.map(arg => typeof arg === 'object' ? JSON.stringify(arg) : String(arg))
          }, '*'),
          error: (...args) => window.parent.postMessage({
            type: 'console.error', 
            args: args.map(arg => typeof arg === 'object' ? JSON.stringify(arg) : String(arg))
          }, '*'),
          warn: (...args) => window.parent.postMessage({
            type: 'console.warn',
            args: args.map(arg => typeof arg === 'object' ? JSON.stringify(arg) : String(arg))
          }, '*')
        },
        
        // Safe globals
        setTimeout: window.setTimeout.bind(window),
        setInterval: window.setInterval.bind(window),
        clearTimeout: window.clearTimeout.bind(window),
        clearInterval: window.clearInterval.bind(window),
        
        // Plugin API
        api: {
          sendMessage: (data) => window.parent.postMessage({
            type: 'plugin.message',
            data: data
          }, '*'),
          
          requestPermission: (permission) => window.parent.postMessage({
            type: 'plugin.requestPermission',
            permission: permission
          }, '*'),
          
          getConfig: () => window.parent.postMessage({
            type: 'plugin.getConfig'
          }, '*')
        },
        
        // Execution context
        executePlugin: function(code, config) {
          try {
            // Create execution context
            const context = {
              console: this.console,
              setTimeout: this.setTimeout,
              setInterval: this.setInterval,
              clearTimeout: this.clearTimeout,
              clearInterval: this.clearInterval,
              api: this.api,
              config: config || {}
            }
            
            // Execute plugin code in controlled context
            const result = Function('context', 
              'with(context) { return (' + code + '); }'
            )(context)
            
            window.parent.postMessage({
              type: 'plugin.success',
              result: result
            }, '*')
            
          } catch (error) {
            window.parent.postMessage({
              type: 'plugin.error',
              error: {
                message: error.message,
                stack: error.stack,
                name: error.name
              }
            }, '*')
          }
        }
      }
      
      // Override dangerous globals
      delete window.fetch
      delete window.XMLHttpRequest
      delete window.document
      delete window.localStorage
      delete window.sessionStorage
      delete window.indexedDB
      
      // Report ready
      window.parent.postMessage({ type: 'sandbox.ready' }, '*')
    `
  }

  setupSandboxCommunication(sandboxWindow) {
    window.addEventListener("message", (event) => {
      if (event.source !== sandboxWindow) return
      
      this.handleSandboxMessage(event.data)
    })
  }

  handleSandboxMessage(message) {
    switch (message.type) {
    case "sandbox.ready":
      this.emit("sandbox:ready")
      break
        
    case "console.log":
    case "console.error":
    case "console.warn":
      this.handleConsoleMessage(message)
      break
        
    case "plugin.success":
      this.handlePluginSuccess(message)
      break
        
    case "plugin.error":
      this.handlePluginError(message)
      break
        
    case "plugin.message":
      this.handlePluginMessage(message)
      break
        
    case "plugin.requestPermission":
      this.handlePermissionRequest(message)
      break
        
    case "plugin.getConfig":
      this.handleConfigRequest(message)
      break
    }
  }

  handleConsoleMessage(message) {
    if (this.options.enableConsoleLogging) {
      const method = message.type.split(".")[1]
      console[method]("[Plugin]", ...message.args)
    }
    
    this.emit("sandbox:console", {
      level: message.type.split(".")[1],
      args: message.args
    })
  }

  handlePluginSuccess(message) {
    this.emit("sandbox:success", {
      result: message.result
    })
  }

  handlePluginError(message) {
    this.emit("sandbox:error", {
      error: message.error
    })
  }

  handlePluginMessage(message) {
    this.emit("sandbox:message", {
      data: message.data
    })
  }

  handlePermissionRequest(message) {
    this.emit("sandbox:permission-request", {
      permission: message.permission
    })
  }

  handleConfigRequest(message) {
    this.emit("sandbox:config-request")
  }

  setupErrorHandling() {
    window.addEventListener("error", (event) => {
      if (event.filename && event.filename.includes("sandbox")) {
        this.emit("sandbox:runtime-error", {
          error: {
            message: event.message,
            filename: event.filename,
            lineno: event.lineno,
            colno: event.colno
          }
        })
      }
    })
  }

  // Public API
  async executePlugin(pluginId, code, config = {}) {
    const executionId = this.generateExecutionId()
    
    try {
      // Validate plugin before execution
      this.validatePluginCode(code)
      
      // Check permissions
      await this.checkPluginPermissions(pluginId, config)
      
      // Create execution context
      const context = {
        id: executionId,
        pluginId: pluginId,
        code: code,
        config: config,
        startTime: Date.now(),
        timeout: config.timeout || this.options.defaultTimeout
      }
      
      // Add to active sandboxes
      this.activeSandboxes.set(executionId, context)
      
      // Execute with monitoring
      const result = await this.executeWithMonitoring(context)
      
      // Cleanup
      this.activeSandboxes.delete(executionId)
      
      return {
        success: true,
        result: result,
        executionTime: Date.now() - context.startTime,
        memoryUsage: this.performanceMonitor.getCurrentMemoryUsage()
      }
      
    } catch (error) {
      this.activeSandboxes.delete(executionId)
      throw error
    }
  }

  async executeWithMonitoring(context) {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error("Plugin execution timeout"))
      }, context.timeout)
      
      // Start resource monitoring
      const monitor = this.performanceMonitor.startExecution(context.id)
      
      // Setup event listeners for this execution
      const successHandler = (event) => {
        if (event.detail.executionId === context.id) {
          clearTimeout(timeout)
          monitor.stop()
          this.off("sandbox:success", successHandler)
          this.off("sandbox:error", errorHandler)
          resolve(event.detail.result)
        }
      }
      
      const errorHandler = (event) => {
        if (event.detail.executionId === context.id) {
          clearTimeout(timeout)
          monitor.stop()
          this.off("sandbox:success", successHandler)
          this.off("sandbox:error", errorHandler)
          reject(new Error(event.detail.error.message))
        }
      }
      
      this.on("sandbox:success", successHandler)
      this.on("sandbox:error", errorHandler)
      
      // Execute in sandbox
      this.sandboxFrame.contentWindow.PluginSandbox.executePlugin(
        context.code, 
        context.config
      )
    })
  }

  validatePluginCode(code) {
    // Basic security checks
    const dangerousPatterns = [
      /eval\s*\(/,
      /Function\s*\(/,
      /document\./,
      /window\./,
      /parent\./,
      /top\./,
      /self\./,
      /frames/,
      /location\./,
      /history\./,
      /navigator\./,
      /screen\./,
      /localStorage/,
      /sessionStorage/,
      /indexedDB/,
      /webkitIndexedDB/,
      /mozIndexedDB/,
      /msIndexedDB/,
      /XMLHttpRequest/,
      /fetch\s*\(/,
      /import\s*\(/,
      /require\s*\(/
    ]
    
    for (const pattern of dangerousPatterns) {
      if (pattern.test(code)) {
        throw new SecurityError(`Potentially dangerous code detected: ${pattern}`)
      }
    }
    
    // Check code size
    if (code.length > 100000) { // 100KB limit
      throw new Error("Plugin code exceeds size limit")
    }
  }

  async checkPluginPermissions(pluginId, config) {
    // Fetch plugin permissions from backend
    try {
      const response = await fetch(`${this.options.baseUrl}/${pluginId}/status`)
      if (!response.ok) {
        throw new Error("Failed to fetch plugin permissions")
      }
      
      const data = await response.json()
      
      // Validate requested permissions against allowed permissions
      if (config.permissions) {
        for (const permission of config.permissions) {
          if (!data.permissions.includes(permission)) {
            throw new SecurityError(`Permission denied: ${permission}`)
          }
        }
      }
      
    } catch (error) {
      if (error instanceof SecurityError) {
        throw error
      }
      console.warn("Could not verify plugin permissions:", error)
    }
  }

  // Queue Management
  async queueExecution(pluginId, code, config) {
    return new Promise((resolve, reject) => {
      this.executionQueue.push({
        pluginId,
        code,
        config,
        resolve,
        reject
      })
      
      this.processQueue()
    })
  }

  async processQueue() {
    if (this.isProcessingQueue || this.executionQueue.length === 0) {
      return
    }
    
    this.isProcessingQueue = true
    
    while (this.executionQueue.length > 0) {
      const execution = this.executionQueue.shift()
      
      try {
        const result = await this.executePlugin(
          execution.pluginId,
          execution.code,
          execution.config
        )
        execution.resolve(result)
      } catch (error) {
        execution.reject(error)
      }
      
      // Small delay between executions
      await new Promise(resolve => setTimeout(resolve, 100))
    }
    
    this.isProcessingQueue = false
  }

  // Resource Monitoring
  getResourceUsage() {
    return {
      activeExecutions: this.activeSandboxes.size,
      queueLength: this.executionQueue.length,
      memoryUsage: this.performanceMonitor.getCurrentMemoryUsage(),
      executionHistory: this.performanceMonitor.getExecutionHistory()
    }
  }

  // Security Methods
  async createSecureContext(pluginId, permissions = []) {
    const context = {
      pluginId: pluginId,
      permissions: permissions,
      startTime: Date.now(),
      memoryLimit: this.options.maxMemoryUsage,
      timeLimit: this.options.maxExecutionTime
    }
    
    return context
  }

  async validatePluginSignature(pluginId, code) {
    // In production, this would verify plugin signature
    return true
  }

  // Cleanup
  terminateExecution(executionId) {
    const context = this.activeSandboxes.get(executionId)
    if (context) {
      this.activeSandboxes.delete(executionId)
      this.emit("sandbox:terminated", { executionId, context })
    }
  }

  terminateAllExecutions() {
    const executionIds = Array.from(this.activeSandboxes.keys())
    executionIds.forEach(id => this.terminateExecution(id))
  }

  cleanup() {
    this.terminateAllExecutions()
    
    if (this.sandboxFrame) {
      this.sandboxFrame.remove()
      this.sandboxFrame = null
    }
    
    this.performanceMonitor.stop()
  }

  // Utility Methods
  generateExecutionId() {
    return `exec-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
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

/**
 * Performance Monitor for tracking plugin execution metrics
 */
class PerformanceMonitor {
  constructor() {
    this.isMonitoring = false
    this.executionHistory = []
    this.activeExecutions = new Map()
    this.memoryBaseline = 0
  }

  start() {
    this.isMonitoring = true
    this.memoryBaseline = this.getCurrentMemoryUsage()
  }

  stop() {
    this.isMonitoring = false
    this.activeExecutions.clear()
  }

  startExecution(executionId) {
    const monitor = {
      id: executionId,
      startTime: Date.now(),
      startMemory: this.getCurrentMemoryUsage(),
      checkpoints: []
    }
    
    this.activeExecutions.set(executionId, monitor)
    
    return {
      checkpoint: (name) => this.addCheckpoint(executionId, name),
      stop: () => this.stopExecution(executionId)
    }
  }

  stopExecution(executionId) {
    const monitor = this.activeExecutions.get(executionId)
    if (!monitor) return
    
    const endTime = Date.now()
    const endMemory = this.getCurrentMemoryUsage()
    
    const summary = {
      id: executionId,
      duration: endTime - monitor.startTime,
      memoryDelta: endMemory - monitor.startMemory,
      checkpoints: monitor.checkpoints,
      timestamp: new Date().toISOString()
    }
    
    this.executionHistory.push(summary)
    this.activeExecutions.delete(executionId)
    
    // Keep only last 100 executions
    if (this.executionHistory.length > 100) {
      this.executionHistory.shift()
    }
    
    return summary
  }

  addCheckpoint(executionId, name) {
    const monitor = this.activeExecutions.get(executionId)
    if (!monitor) return
    
    monitor.checkpoints.push({
      name: name,
      timestamp: Date.now(),
      memory: this.getCurrentMemoryUsage()
    })
  }

  getCurrentMemoryUsage() {
    if (performance.memory) {
      return {
        used: performance.memory.usedJSHeapSize,
        total: performance.memory.totalJSHeapSize,
        limit: performance.memory.jsHeapSizeLimit
      }
    }
    return { used: 0, total: 0, limit: 0 }
  }

  getExecutionHistory() {
    return this.executionHistory.slice(-10) // Last 10 executions
  }

  getAverageExecutionTime() {
    if (this.executionHistory.length === 0) return 0
    
    const total = this.executionHistory.reduce((sum, exec) => sum + exec.duration, 0)
    return total / this.executionHistory.length
  }
}

/**
 * Security Error class for plugin security violations
 */
class SecurityError extends Error {
  constructor(message) {
    super(message)
    this.name = "SecurityError"
  }
}

// Export for module usage
export { PerformanceMonitor, SecurityError }
export default PluginSandbox

// Create global instance
window.PluginSandbox = new PluginSandbox()