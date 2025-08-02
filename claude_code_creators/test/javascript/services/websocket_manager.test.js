/**
 * WebSocketManager Tests
 * Test suite for WebSocket connection management and reliability
 */

import { describe, test, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { WebSocketManager } from '../../../app/javascript/services/websocket_manager'

// Mock ActionCable consumer
const mockConsumer = {
  connection: {
    open: jest.fn(),
    close: jest.fn(),
    monitor: {
      connected: null,
      disconnected: null,
      onopen: null,
      onclose: null,
      onerror: null,
      ping: jest.fn(),
      getState: jest.fn(() => ({ lastPingAt: Date.now() }))
    }
  },
  subscriptions: {
    subscriptions: []
  }
}

jest.mock('../../../app/javascript/channels/consumer', () => mockConsumer)

describe('WebSocketManager', () => {
  let webSocketManager

  beforeEach(() => {
    jest.clearAllMocks()
    webSocketManager = new WebSocketManager({
      autoReconnect: true,
      reconnectDelay: 100, // Faster for testing
      maxReconnectAttempts: 3,
      heartbeatInterval: 500,
      connectionTimeout: 1000
    })
  })

  afterEach(() => {
    if (webSocketManager) {
      webSocketManager.destroy()
    }
  })

  describe('Initialization', () => {
    test('creates instance with default options', () => {
      const manager = new WebSocketManager()
      
      expect(manager.options.autoReconnect).toBe(true)
      expect(manager.options.maxReconnectAttempts).toBe(50)
      expect(manager.connectionState).toBe('disconnected')
      expect(manager.isConnected).toBe(false)
    })

    test('accepts custom options', () => {
      const customOptions = {
        autoReconnect: false,
        maxReconnectAttempts: 10,
        heartbeatInterval: 60000
      }

      const manager = new WebSocketManager(customOptions)
      
      expect(manager.options.autoReconnect).toBe(false)
      expect(manager.options.maxReconnectAttempts).toBe(10)
      expect(manager.options.heartbeatInterval).toBe(60000)
    })

    test('sets up consumer callbacks on initialization', () => {
      expect(mockConsumer.connection.monitor.connected).toBeDefined()
      expect(mockConsumer.connection.monitor.disconnected).toBeDefined()
    })
  })

  describe('Connection Management', () => {
    test('connect sets state to connecting', async () => {
      const connectPromise = webSocketManager.connect()
      
      expect(webSocketManager.connectionState).toBe('connecting')
      expect(mockConsumer.connection.open).toHaveBeenCalled()

      // Simulate successful connection
      webSocketManager.handleConnected()
      
      await connectPromise
      expect(webSocketManager.isConnected).toBe(true)
      expect(webSocketManager.connectionState).toBe('connected')
    })

    test('connect handles connection timeout', async () => {
      jest.useFakeTimers()
      
      const connectPromise = webSocketManager.connect()
      
      // Fast-forward past connection timeout
      jest.advanceTimersByTime(1100)
      
      await expect(connectPromise).rejects.toThrow('Connection timeout')
      expect(webSocketManager.connectionState).toBe('error')
      
      jest.useRealTimers()
    })

    test('disconnect closes connection and updates state', () => {
      webSocketManager.isConnected = true
      webSocketManager.connectionState = 'connected'
      
      webSocketManager.disconnect()
      
      expect(mockConsumer.connection.close).toHaveBeenCalled()
      expect(webSocketManager.isConnected).toBe(false)
      expect(webSocketManager.connectionState).toBe('disconnected')
    })

    test('handleConnected updates state and emits events', () => {
      const mockEmit = jest.spyOn(webSocketManager, 'emit')
      webSocketManager.connectionStartTime = Date.now() - 1000
      
      webSocketManager.handleConnected()
      
      expect(webSocketManager.isConnected).toBe(true)
      expect(webSocketManager.connectionState).toBe('connected')
      expect(mockEmit).toHaveBeenCalledWith('connection:established', expect.any(Object))
    })

    test('handleDisconnected triggers reconnection when enabled', () => {
      const mockScheduleReconnect = jest.spyOn(webSocketManager, 'scheduleReconnect')
      webSocketManager.isConnected = true
      webSocketManager.options.autoReconnect = true
      
      webSocketManager.handleDisconnected()
      
      expect(webSocketManager.isConnected).toBe(false)
      expect(mockScheduleReconnect).toHaveBeenCalled()
    })
  })

  describe('Reconnection Logic', () => {
    test('scheduleReconnect implements exponential backoff', () => {
      jest.useFakeTimers()
      const mockConnect = jest.spyOn(webSocketManager, 'connect').mockResolvedValue()
      
      webSocketManager.reconnectAttempts = 2
      webSocketManager.scheduleReconnect()
      
      const expectedDelay = webSocketManager.options.reconnectDelay * 
        Math.pow(webSocketManager.options.backoffMultiplier, 2)
      
      expect(webSocketManager.connectionState).toBe('reconnecting')
      
      jest.advanceTimersByTime(expectedDelay)
      expect(mockConnect).toHaveBeenCalled()
      
      jest.useRealTimers()
    })

    test('stops reconnecting after max attempts', () => {
      const mockEmit = jest.spyOn(webSocketManager, 'emit')
      webSocketManager.reconnectAttempts = 3
      
      webSocketManager.scheduleReconnect()
      
      expect(mockEmit).toHaveBeenCalledWith('connection:max_attempts_reached', {
        attempts: 3
      })
      expect(webSocketManager.connectionState).toBe('error')
    })

    test('forceReconnect resets attempts and reconnects', () => {
      jest.useFakeTimers()
      const mockConnect = jest.spyOn(webSocketManager, 'connect').mockResolvedValue()
      const mockDisconnect = jest.spyOn(webSocketManager, 'disconnect')
      
      webSocketManager.reconnectAttempts = 5
      webSocketManager.forceReconnect()
      
      expect(webSocketManager.reconnectAttempts).toBe(0)
      expect(mockDisconnect).toHaveBeenCalled()
      
      jest.advanceTimersByTime(1000)
      expect(mockConnect).toHaveBeenCalled()
      
      jest.useRealTimers()
    })
  })

  describe('Connection Health Monitoring', () => {
    test('startHeartbeat sets up periodic ping', () => {
      jest.useFakeTimers()
      const mockSendHeartbeat = jest.spyOn(webSocketManager, 'sendHeartbeat')
      
      webSocketManager.startHeartbeat()
      
      jest.advanceTimersByTime(500)
      expect(mockSendHeartbeat).toHaveBeenCalled()
      
      jest.useRealTimers()
    })

    test('sendHeartbeat calls consumer ping', () => {
      webSocketManager.isConnected = true
      
      webSocketManager.sendHeartbeat()
      
      expect(mockConsumer.connection.monitor.ping).toHaveBeenCalled()
    })

    test('checkConnectionHealth detects stale connections', () => {
      const mockForceReconnect = jest.spyOn(webSocketManager, 'forceReconnect')
      webSocketManager.isConnected = true
      
      // Mock stale connection
      mockConsumer.connection.monitor.getState.mockReturnValue({
        lastPingAt: Date.now() - 70000 // 70 seconds ago
      })
      
      webSocketManager.checkConnectionHealth()
      
      expect(mockForceReconnect).toHaveBeenCalled()
    })

    test('recordLatency updates latency history', () => {
      const latency = 150
      
      webSocketManager.recordLatency(latency)
      
      expect(webSocketManager.latencyHistory).toContain(latency)
    })

    test('updateConnectionQuality emits quality change events', () => {
      const mockEmit = jest.spyOn(webSocketManager, 'emit')
      
      webSocketManager.updateConnectionQuality('poor')
      
      expect(webSocketManager.connectionQuality).toBe('poor')
      expect(mockEmit).toHaveBeenCalledWith('connection:quality_changed', {
        quality: 'poor',
        previousQuality: 'good'
      })
    })
  })

  describe('Error Handling', () => {
    test('handleConnectionError updates state and emits error event', () => {
      const mockEmit = jest.spyOn(webSocketManager, 'emit')
      const errorEvent = { type: 'error', message: 'Connection failed' }
      
      webSocketManager.handleConnectionError(errorEvent)
      
      expect(webSocketManager.connectionState).toBe('error')
      expect(mockEmit).toHaveBeenCalledWith('connection:error', {
        type: 'websocket_error',
        event: errorEvent
      })
    })

    test('handleConnectionClose analyzes close codes', () => {
      const mockEmit = jest.spyOn(webSocketManager, 'emit')
      
      // Normal closure
      const normalCloseEvent = { code: 1000, reason: 'Normal closure', wasClean: true }
      webSocketManager.handleConnectionClose(normalCloseEvent)
      
      expect(mockEmit).toHaveBeenCalledWith('connection:close', {
        code: 1000,
        reason: 'Normal closure',
        wasClean: true
      })
      
      // Application error
      const appErrorEvent = { code: 4001, reason: 'App error', wasClean: false }
      webSocketManager.handleConnectionClose(appErrorEvent)
      
      expect(mockEmit).toHaveBeenCalledWith('connection:error', {
        type: 'application_error',
        code: 4001,
        reason: 'App error'
      })
    })

    test('handleConnectionTimeout triggers reconnection', () => {
      const mockScheduleReconnect = jest.spyOn(webSocketManager, 'scheduleReconnect')
      const mockEmit = jest.spyOn(webSocketManager, 'emit')
      
      webSocketManager.handleConnectionTimeout()
      
      expect(webSocketManager.connectionState).toBe('error')
      expect(mockEmit).toHaveBeenCalledWith('connection:timeout')
      expect(mockScheduleReconnect).toHaveBeenCalled()
    })
  })

  describe('Event System', () => {
    test('event listener registration and triggering', () => {
      const mockCallback = jest.fn()
      
      webSocketManager.on('test:event', mockCallback)
      webSocketManager.emit('test:event', { data: 'test' })
      
      expect(mockCallback).toHaveBeenCalledWith({ data: 'test' })
    })

    test('event listener removal', () => {
      const mockCallback = jest.fn()
      
      webSocketManager.on('test:event', mockCallback)
      webSocketManager.off('test:event', mockCallback)
      webSocketManager.emit('test:event', { data: 'test' })
      
      expect(mockCallback).not.toHaveBeenCalled()
    })

    test('handles errors in event listeners gracefully', () => {
      const mockConsoleError = jest.spyOn(console, 'error').mockImplementation()
      const faultyCallback = jest.fn(() => { throw new Error('Callback error') })
      
      webSocketManager.on('test:event', faultyCallback)
      
      expect(() => {
        webSocketManager.emit('test:event')
      }).not.toThrow()
      
      expect(mockConsoleError).toHaveBeenCalled()
      mockConsoleError.mockRestore()
    })
  })

  describe('Connection Information', () => {
    test('getConnectionInfo returns current state', () => {
      webSocketManager.isConnected = true
      webSocketManager.connectionState = 'connected'
      webSocketManager.reconnectAttempts = 2
      webSocketManager.connectionQuality = 'good'
      webSocketManager.latencyHistory = [100, 150, 120]
      webSocketManager.connectionStartTime = Date.now() - 5000
      
      const info = webSocketManager.getConnectionInfo()
      
      expect(info.isConnected).toBe(true)
      expect(info.connectionState).toBe('connected')
      expect(info.reconnectAttempts).toBe(2)
      expect(info.connectionQuality).toBe('good')
      expect(info.averageLatency).toBe(123) // Average of latency history
      expect(info.uptime).toBeGreaterThan(4000)
    })

    test('getSubscriptionCount returns current subscription count', () => {
      mockConsumer.subscriptions.subscriptions = [{}, {}, {}]
      
      const count = webSocketManager.getSubscriptionCount()
      
      expect(count).toBe(3)
    })
  })

  describe('Configuration Updates', () => {
    test('updateOptions merges new options', () => {
      const newOptions = {
        maxReconnectAttempts: 10,
        heartbeatInterval: 60000,
        newOption: 'test'
      }
      
      webSocketManager.updateOptions(newOptions)
      
      expect(webSocketManager.options.maxReconnectAttempts).toBe(10)
      expect(webSocketManager.options.heartbeatInterval).toBe(60000)
      expect(webSocketManager.options.newOption).toBe('test')
      expect(webSocketManager.options.autoReconnect).toBe(true) // Original value preserved
    })
  })

  describe('Cleanup and Memory Management', () => {
    test('stopHeartbeat clears heartbeat timer', () => {
      jest.useFakeTimers()
      
      webSocketManager.startHeartbeat()
      expect(webSocketManager.heartbeatTimer).toBeDefined()
      
      webSocketManager.stopHeartbeat()
      expect(webSocketManager.heartbeatTimer).toBeNull()
      
      jest.useRealTimers()
    })

    test('destroy cleans up all resources', () => {
      const mockStopReconnecting = jest.spyOn(webSocketManager, 'stopReconnecting')
      const mockStopHeartbeat = jest.spyOn(webSocketManager, 'stopHeartbeat')
      const mockDisconnect = jest.spyOn(webSocketManager, 'disconnect')
      
      webSocketManager.destroy()
      
      expect(mockStopReconnecting).toHaveBeenCalled()
      expect(mockStopHeartbeat).toHaveBeenCalled()
      expect(mockDisconnect).toHaveBeenCalled()
      expect(webSocketManager.eventListeners.size).toBe(0)
    })

    test('manages latency history size', () => {
      webSocketManager.maxLatencyHistory = 3
      
      webSocketManager.recordLatency(100)
      webSocketManager.recordLatency(150)
      webSocketManager.recordLatency(200)
      webSocketManager.recordLatency(250)
      
      expect(webSocketManager.latencyHistory).toHaveLength(3)
      expect(webSocketManager.latencyHistory).toEqual([150, 200, 250])
    })
  })

  describe('Integration with ActionCable', () => {
    test('setupConsumerCallbacks overrides original callbacks', () => {
      const originalConnected = jest.fn()
      const originalDisconnected = jest.fn()
      
      mockConsumer.connection.monitor.connected = originalConnected
      mockConsumer.connection.monitor.disconnected = originalDisconnected
      
      webSocketManager.setupConsumerCallbacks()
      
      // Call the overridden callbacks
      mockConsumer.connection.monitor.connected()
      mockConsumer.connection.monitor.disconnected()
      
      // Should call both original and new handlers
      expect(originalConnected).toHaveBeenCalled()
      expect(originalDisconnected).toHaveBeenCalled()
    })
  })

  describe('Edge Cases and Error Conditions', () => {
    test('handles missing consumer gracefully', () => {
      const managerWithoutConsumer = new WebSocketManager()
      // Mock consumer is undefined
      jest.doMock('../../../app/javascript/channels/consumer', () => undefined)
      
      expect(() => {
        managerWithoutConsumer.connect()
      }).not.toThrow()
    })

    test('handles rapid connect/disconnect cycles', async () => {
      const connectPromise1 = webSocketManager.connect()
      const connectPromise2 = webSocketManager.connect() // Should not create duplicate connection
      
      webSocketManager.handleConnected()
      
      await Promise.all([connectPromise1, connectPromise2])
      
      expect(webSocketManager.isConnected).toBe(true)
    })

    test('handles negative latency values', () => {
      webSocketManager.recordLatency(-10)
      
      expect(webSocketManager.latencyHistory).toContain(-10)
    })

    test('handles connection state changes during shutdown', () => {
      webSocketManager.destroy()
      
      // These should not throw errors
      webSocketManager.handleConnected()
      webSocketManager.handleDisconnected()
      webSocketManager.handleConnectionError(new Error('test'))
    })
  })
})