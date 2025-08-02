/**
 * Plugin Sandbox Test Suite
 * Comprehensive tests for PluginSandbox functionality
 */

import PluginSandbox from '../../app/javascript/services/plugin_sandbox.js'

describe('PluginSandbox', () => {
  let sandbox
  let mockFetch

  beforeEach(() => {
    // Mock fetch
    mockFetch = jest.fn()
    global.fetch = mockFetch

    // Mock iframe creation
    global.document.createElement = jest.fn((tagName) => {
      if (tagName === 'iframe') {
        const iframe = {
          style: {},
          setAttribute: jest.fn(),
          contentDocument: {
            createElement: jest.fn(() => ({
              textContent: '',
              head: { appendChild: jest.fn() }
            })),
            head: { appendChild: jest.fn() }
          },
          contentWindow: {
            postMessage: jest.fn(),
            PluginSandbox: {
              executePlugin: jest.fn()
            }
          },
          remove: jest.fn()
        }
        return iframe
      }
      return document.createElement.bind(document)(tagName)
    })

    // Mock document.body
    global.document.body = {
      appendChild: jest.fn()
    }

    // Mock performance.memory
    global.performance = {
      memory: {
        usedJSHeapSize: 1000000,
        totalJSHeapSize: 2000000,
        jsHeapSizeLimit: 4000000
      }
    }

    sandbox = new PluginSandbox({
      enableConsoleLogging: false,
      logToServer: false
    })
  })

  afterEach(() => {
    if (sandbox) {
      sandbox.cleanup()
    }
    jest.clearAllMocks()
  })

  describe('Initialization', () => {
    test('should initialize with default options', () => {
      expect(sandbox.options.defaultTimeout).toBe(30000)
      expect(sandbox.options.maxMemoryUsage).toBe(100 * 1024 * 1024)
      expect(sandbox.activeSandboxes).toBeInstanceOf(Map)
      expect(sandbox.executionQueue).toBeInstanceOf(Array)
      expect(sandbox.performanceMonitor).toBeTruthy()
    })

    test('should create sandbox iframe', async () => {
      expect(sandbox.sandboxFrame).toBeTruthy()
      expect(sandbox.sandboxFrame.setAttribute).toHaveBeenCalledWith('sandbox', 'allow-scripts')
      expect(sandbox.sandboxFrame.src).toBe('about:blank')
    })

    test('should initialize performance monitoring', () => {
      expect(sandbox.performanceMonitor.isMonitoring).toBe(true)
    })
  })

  describe('Code Validation', () => {
    test('should validate safe code', () => {
      const safeCode = 'function add(a, b) { return a + b; }'
      
      expect(() => sandbox.validatePluginCode(safeCode)).not.toThrow()
    })

    test('should reject dangerous eval usage', () => {
      const dangerousCode = 'eval("malicious code")'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should reject document access', () => {
      const dangerousCode = 'document.createElement("script")'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should reject window access', () => {
      const dangerousCode = 'window.location.href = "http://evil.com"'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should reject localStorage access', () => {
      const dangerousCode = 'localStorage.setItem("key", "value")'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should reject XMLHttpRequest usage', () => {
      const dangerousCode = 'new XMLHttpRequest()'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should reject fetch usage', () => {
      const dangerousCode = 'fetch("http://api.example.com")'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should reject code exceeding size limit', () => {
      const largeCode = 'a'.repeat(100001) // Exceeds 100KB limit
      
      expect(() => sandbox.validatePluginCode(largeCode))
        .toThrow('Plugin code exceeds size limit')
    })
  })

  describe('Permission Checking', () => {
    beforeEach(() => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({
          permissions: ['api_access', 'clipboard_access']
        })
      })
    })

    test('should check plugin permissions', async () => {
      await sandbox.checkPluginPermissions('test-plugin', {
        permissions: ['api_access']
      })
      
      expect(mockFetch).toHaveBeenCalledWith('/extensions/test-plugin/status')
    })

    test('should allow granted permissions', async () => {
      await expect(
        sandbox.checkPluginPermissions('test-plugin', {
          permissions: ['api_access']
        })
      ).resolves.not.toThrow()
    })

    test('should reject unauthorized permissions', async () => {
      await expect(
        sandbox.checkPluginPermissions('test-plugin', {
          permissions: ['system_access']
        })
      ).rejects.toThrow('Permission denied: system_access')
    })

    test('should handle permission check failures gracefully', async () => {
      mockFetch.mockRejectedValue(new Error('Network error'))
      
      // Should not throw, just log warning
      await expect(
        sandbox.checkPluginPermissions('test-plugin', {})
      ).resolves.not.toThrow()
    })
  })

  describe('Plugin Execution', () => {
    beforeEach(() => {
      // Mock successful permission check
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ permissions: [] })
      })
    })

    test('should execute simple plugin code', async () => {
      const code = 'return "Hello World"'
      
      // Mock sandbox communication
      setTimeout(() => {
        sandbox.handleSandboxMessage({
          type: 'plugin.success',
          result: 'Hello World'
        })
      }, 10)

      const result = await sandbox.executePlugin('test-plugin', code)
      
      expect(result.success).toBe(true)
      expect(result.result).toBe('Hello World')
      expect(result.executionTime).toBeGreaterThan(0)
    })

    test('should handle plugin errors', async () => {
      const code = 'throw new Error("Plugin error")'
      
      // Mock sandbox communication
      setTimeout(() => {
        sandbox.handleSandboxMessage({
          type: 'plugin.error',
          error: {
            message: 'Plugin error',
            name: 'Error'
          }
        })
      }, 10)

      await expect(sandbox.executePlugin('test-plugin', code))
        .rejects.toThrow('Plugin error')
    })

    test('should timeout long-running plugins', async () => {
      const code = 'while(true) {}'
      
      const result = sandbox.executePlugin('test-plugin', code, { timeout: 100 })
      
      await expect(result).rejects.toThrow('Plugin execution timeout')
    })

    test('should track active executions', async () => {
      const code = 'return "test"'
      
      const executionPromise = sandbox.executePlugin('test-plugin', code)
      
      expect(sandbox.activeSandboxes.size).toBe(1)
      
      // Complete execution
      setTimeout(() => {
        sandbox.handleSandboxMessage({
          type: 'plugin.success',
          result: 'test'
        })
      }, 10)

      await executionPromise
      
      expect(sandbox.activeSandboxes.size).toBe(0)
    })
  })

  describe('Sandbox Communication', () => {
    test('should handle console messages', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation()
      
      sandbox.options.enableConsoleLogging = true
      sandbox.handleSandboxMessage({
        type: 'console.log',
        args: ['Test message', 'arg2']
      })
      
      expect(consoleSpy).toHaveBeenCalledWith('[Plugin]', 'Test message', 'arg2')
      
      consoleSpy.mockRestore()
    })

    test('should emit console events', () => {
      const mockCallback = jest.fn()
      sandbox.on('sandbox:console', mockCallback)
      
      sandbox.handleSandboxMessage({
        type: 'console.error',
        args: ['Error message']
      })
      
      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: {
            level: 'error',
            args: ['Error message']
          }
        })
      )
    })

    test('should handle plugin messages', () => {
      const mockCallback = jest.fn()
      sandbox.on('sandbox:message', mockCallback)
      
      sandbox.handleSandboxMessage({
        type: 'plugin.message',
        data: { action: 'test' }
      })
      
      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { data: { action: 'test' } }
        })
      )
    })

    test('should handle permission requests', () => {
      const mockCallback = jest.fn()
      sandbox.on('sandbox:permission-request', mockCallback)
      
      sandbox.handleSandboxMessage({
        type: 'plugin.requestPermission',
        permission: 'api_access'
      })
      
      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { permission: 'api_access' }
        })
      )
    })
  })

  describe('Execution Queue', () => {
    test('should queue multiple executions', async () => {
      const code1 = 'return "first"'
      const code2 = 'return "second"'
      
      const promise1 = sandbox.queueExecution('plugin1', code1)
      const promise2 = sandbox.queueExecution('plugin2', code2)
      
      expect(sandbox.executionQueue.length).toBe(2)
      
      // Mock completion
      setTimeout(() => {
        sandbox.handleSandboxMessage({ type: 'plugin.success', result: 'first' })
      }, 10)
      setTimeout(() => {
        sandbox.handleSandboxMessage({ type: 'plugin.success', result: 'second' })
      }, 20)

      const [result1, result2] = await Promise.all([promise1, promise2])
      
      expect(result1.result).toBe('first')
      expect(result2.result).toBe('second')
    })

    test('should process queue sequentially', async () => {
      const executeSpy = jest.spyOn(sandbox, 'executePlugin')
      
      sandbox.queueExecution('plugin1', 'return 1')
      sandbox.queueExecution('plugin2', 'return 2')
      
      await sandbox.processQueue()
      
      expect(executeSpy).toHaveBeenCalledTimes(2)
    })
  })

  describe('Resource Monitoring', () => {
    test('should track resource usage', () => {
      const usage = sandbox.getResourceUsage()
      
      expect(usage).toHaveProperty('activeExecutions')
      expect(usage).toHaveProperty('queueLength')
      expect(usage).toHaveProperty('memoryUsage')
      expect(usage).toHaveProperty('executionHistory')
    })

    test('should monitor execution performance', () => {
      const monitor = sandbox.performanceMonitor.startExecution('test-exec')
      
      expect(sandbox.performanceMonitor.activeExecutions.has('test-exec')).toBe(true)
      
      monitor.checkpoint('checkpoint1')
      const summary = monitor.stop()
      
      expect(summary.id).toBe('test-exec')
      expect(summary.duration).toBeGreaterThan(0)
      expect(summary.checkpoints).toHaveLength(1)
      expect(summary.checkpoints[0].name).toBe('checkpoint1')
    })

    test('should maintain execution history', () => {
      sandbox.performanceMonitor.startExecution('exec1').stop()
      sandbox.performanceMonitor.startExecution('exec2').stop()
      
      const history = sandbox.performanceMonitor.getExecutionHistory()
      expect(history).toHaveLength(2)
    })

    test('should limit execution history size', () => {
      // Add more than 100 executions
      for (let i = 0; i < 102; i++) {
        sandbox.performanceMonitor.startExecution(`exec${i}`).stop()
      }
      
      expect(sandbox.performanceMonitor.executionHistory.length).toBe(100)
    })
  })

  describe('Error Handling', () => {
    test('should handle sandbox runtime errors', () => {
      const mockCallback = jest.fn()
      sandbox.on('sandbox:runtime-error', mockCallback)
      
      // Simulate error event
      const errorEvent = {
        message: 'Script error',
        filename: 'sandbox.js',
        lineno: 10,
        colno: 5
      }
      
      window.dispatchEvent(new ErrorEvent('error', errorEvent))
      
      // Note: This test might need adjustment based on actual implementation
    })

    test('should handle validation errors', () => {
      const dangerousCode = 'eval("malicious")'
      
      expect(() => sandbox.validatePluginCode(dangerousCode))
        .toThrow('Potentially dangerous code detected')
    })

    test('should handle execution errors gracefully', async () => {
      const code = 'return "test"'
      
      // Mock permission check failure
      mockFetch.mockRejectedValue(new Error('Permission check failed'))
      
      await expect(sandbox.executePlugin('test-plugin', code))
        .rejects.toThrow()
    })
  })

  describe('Cleanup', () => {
    test('should terminate specific execution', () => {
      const context = { id: 'test-exec', startTime: Date.now() }
      sandbox.activeSandboxes.set('test-exec', context)
      
      sandbox.terminateExecution('test-exec')
      
      expect(sandbox.activeSandboxes.has('test-exec')).toBe(false)
    })

    test('should terminate all executions', () => {
      sandbox.activeSandboxes.set('exec1', { id: 'exec1' })
      sandbox.activeSandboxes.set('exec2', { id: 'exec2' })
      
      sandbox.terminateAllExecutions()
      
      expect(sandbox.activeSandboxes.size).toBe(0)
    })

    test('should cleanup resources on destruction', () => {
      const removeSpy = jest.spyOn(sandbox.sandboxFrame, 'remove')
      const stopSpy = jest.spyOn(sandbox.performanceMonitor, 'stop')
      
      sandbox.cleanup()
      
      expect(removeSpy).toHaveBeenCalled()
      expect(stopSpy).toHaveBeenCalled()
      expect(sandbox.sandboxFrame).toBeNull()
    })
  })

  describe('Security Features', () => {
    test('should create secure execution context', async () => {
      const context = await sandbox.createSecureContext('test-plugin', ['api_access'])
      
      expect(context.pluginId).toBe('test-plugin')
      expect(context.permissions).toEqual(['api_access'])
      expect(context.memoryLimit).toBe(sandbox.options.maxMemoryUsage)
      expect(context.timeLimit).toBe(sandbox.options.maxExecutionTime)
    })

    test('should validate plugin signatures', async () => {
      const isValid = await sandbox.validatePluginSignature('test-plugin', 'code')
      
      // Currently always returns true, but structure is in place
      expect(isValid).toBe(true)
    })

    test('should generate unique execution IDs', () => {
      const id1 = sandbox.generateExecutionId()
      const id2 = sandbox.generateExecutionId()
      
      expect(id1).toBeTruthy()
      expect(id2).toBeTruthy()
      expect(id1).not.toBe(id2)
      expect(id1).toMatch(/^exec-\d+-[a-z0-9]+$/)
    })
  })

  describe('Event System', () => {
    test('should emit events', () => {
      const mockCallback = jest.fn()
      sandbox.on('test-event', mockCallback)
      
      sandbox.emit('test-event', { data: 'test' })
      
      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { data: 'test' }
        })
      )
    })

    test('should remove event listeners', () => {
      const mockCallback = jest.fn()
      sandbox.on('test-event', mockCallback)
      sandbox.off('test-event', mockCallback)
      
      sandbox.emit('test-event', { data: 'test' })
      
      expect(mockCallback).not.toHaveBeenCalled()
    })
  })

  describe('Performance Monitor', () => {
    let monitor

    beforeEach(() => {
      monitor = sandbox.performanceMonitor
    })

    test('should start and stop monitoring', () => {
      expect(monitor.isMonitoring).toBe(true)
      
      monitor.stop()
      expect(monitor.isMonitoring).toBe(false)
      
      monitor.start()
      expect(monitor.isMonitoring).toBe(true)
    })

    test('should get current memory usage', () => {
      const usage = monitor.getCurrentMemoryUsage()
      
      expect(usage).toHaveProperty('used')
      expect(usage).toHaveProperty('total')
      expect(usage).toHaveProperty('limit')
      expect(usage.used).toBe(1000000)
    })

    test('should calculate average execution time', () => {
      // Add some execution history
      monitor.executionHistory.push({ duration: 100 })
      monitor.executionHistory.push({ duration: 200 })
      monitor.executionHistory.push({ duration: 300 })
      
      const average = monitor.getAverageExecutionTime()
      expect(average).toBe(200)
    })

    test('should return 0 for empty execution history', () => {
      monitor.executionHistory = []
      
      const average = monitor.getAverageExecutionTime()
      expect(average).toBe(0)
    })
  })
})