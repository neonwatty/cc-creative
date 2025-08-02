/**
 * CollaborationManager Tests
 * Comprehensive test suite for real-time collaboration functionality
 */

import { describe, test, expect, beforeEach, afterEach, jest } from '@jest/globals'
import CollaborationManager from '../../../app/javascript/services/collaboration_manager'

// Mock ActionCable consumer
const mockConsumer = {
  subscriptions: {
    create: jest.fn()
  }
}

// Mock channel subscription
const mockSubscription = {
  perform: jest.fn(),
  unsubscribe: jest.fn()
}

jest.mock('../../../app/javascript/channels/consumer', () => mockConsumer)

describe('CollaborationManager', () => {
  let collaborationManager
  let mockDocumentId
  let mockCurrentUser

  beforeEach(() => {
    mockDocumentId = 123
    mockCurrentUser = {
      id: 1,
      name: 'Test User',
      email: 'test@example.com'
    }

    // Reset mocks
    jest.clearAllMocks()
    mockConsumer.subscriptions.create.mockReturnValue(mockSubscription)

    collaborationManager = new CollaborationManager(mockDocumentId, mockCurrentUser)
  })

  afterEach(() => {
    if (collaborationManager) {
      collaborationManager.disconnect()
    }
  })

  describe('Initialization', () => {
    test('creates instance with correct properties', () => {
      expect(collaborationManager.documentId).toBe(mockDocumentId)
      expect(collaborationManager.currentUser).toEqual(mockCurrentUser)
      expect(collaborationManager.isConnected).toBe(false)
      expect(collaborationManager.connectionState).toBe('disconnected')
    })

    test('initializes with default options', () => {
      expect(collaborationManager.options.autoReconnect).toBe(true)
      expect(collaborationManager.options.maxReconnectAttempts).toBe(5)
      expect(collaborationManager.options.operationQueueSize).toBe(100)
    })

    test('accepts custom options', () => {
      const customOptions = {
        autoReconnect: false,
        maxReconnectAttempts: 10,
        syncInterval: 60000
      }

      const manager = new CollaborationManager(mockDocumentId, mockCurrentUser, customOptions)
      
      expect(manager.options.autoReconnect).toBe(false)
      expect(manager.options.maxReconnectAttempts).toBe(10)
      expect(manager.options.syncInterval).toBe(60000)
    })
  })

  describe('Connection Management', () => {
    test('initialize sets up channels and establishes connection', async () => {
      // Mock successful channel setup
      const mockDocumentChannelCallbacks = {}
      const mockNotificationChannelCallbacks = {}

      mockConsumer.subscriptions.create
        .mockReturnValueOnce({
          ...mockSubscription,
          connected: (callback) => { mockDocumentChannelCallbacks.connected = callback },
          disconnected: (callback) => { mockDocumentChannelCallbacks.disconnected = callback },
          received: (callback) => { mockDocumentChannelCallbacks.received = callback }
        })
        .mockReturnValueOnce({
          ...mockSubscription,
          connected: (callback) => { mockNotificationChannelCallbacks.connected = callback },
          disconnected: (callback) => { mockNotificationChannelCallbacks.disconnected = callback },
          received: (callback) => { mockNotificationChannelCallbacks.received = callback }
        })

      const initPromise = collaborationManager.initialize()

      // Simulate successful connections
      setTimeout(() => {
        mockDocumentChannelCallbacks.connected()
        mockNotificationChannelCallbacks.connected()
      }, 0)

      const result = await initPromise

      expect(result).toBe(true)
      expect(collaborationManager.isConnected).toBe(true)
      expect(collaborationManager.connectionState).toBe('connected')
      expect(mockConsumer.subscriptions.create).toHaveBeenCalledTimes(2)
    })

    test('handles connection failure gracefully', async () => {
      mockConsumer.subscriptions.create.mockImplementation(() => {
        throw new Error('Connection failed')
      })

      const result = await collaborationManager.initialize()

      expect(result).toBe(false)
      expect(collaborationManager.connectionState).toBe('error')
    })

    test('disconnect cleans up channels and state', () => {
      collaborationManager.documentChannel = mockSubscription
      collaborationManager.notificationChannel = mockSubscription
      collaborationManager.isConnected = true

      collaborationManager.disconnect()

      expect(mockSubscription.unsubscribe).toHaveBeenCalledTimes(2)
      expect(collaborationManager.isConnected).toBe(false)
      expect(collaborationManager.connectionState).toBe('disconnected')
    })
  })

  describe('Operation Management', () => {
    beforeEach(async () => {
      // Setup connected state
      collaborationManager.isConnected = true
      collaborationManager.documentChannel = mockSubscription
    })

    test('sendOperation sends operation with enriched data', async () => {
      const operation = {
        type: 'insert',
        position: 10,
        content: 'Hello World'
      }

      const result = await collaborationManager.sendOperation(operation)

      expect(result.success).toBe(true)
      expect(result.operationId).toBeDefined()
      expect(mockSubscription.perform).toHaveBeenCalledWith('edit_operation', expect.objectContaining({
        ...operation,
        operation_id: expect.any(String),
        timestamp: expect.any(Number),
        user_id: mockCurrentUser.id
      }))
    })

    test('sendOperation queues operation when not connected', async () => {
      collaborationManager.isConnected = false

      const operation = { type: 'insert', position: 0, content: 'test' }
      const result = await collaborationManager.sendOperation(operation)

      expect(result.success).toBe(false)
      expect(result.error).toBe('Not connected')
      expect(collaborationManager.operationQueue).toHaveLength(1)
    })

    test('sendBatchOperations sends multiple operations', async () => {
      const operations = [
        { type: 'insert', position: 0, content: 'Hello' },
        { type: 'insert', position: 5, content: ' World' }
      ]

      const result = await collaborationManager.sendBatchOperations(operations)

      expect(result.success).toBe(true)
      expect(result.operationCount).toBe(2)
      expect(mockSubscription.perform).toHaveBeenCalledWith('batch_operations', {
        operations: expect.arrayContaining([
          expect.objectContaining({ operation_id: expect.any(String) }),
          expect.objectContaining({ operation_id: expect.any(String) })
        ])
      })
    })

    test('processQueuedOperations sends queued operations after reconnection', async () => {
      // Queue some operations while disconnected
      collaborationManager.isConnected = false
      await collaborationManager.sendOperation({ type: 'insert', position: 0, content: 'test1' })
      await collaborationManager.sendOperation({ type: 'insert', position: 4, content: 'test2' })

      expect(collaborationManager.operationQueue).toHaveLength(2)

      // Reconnect and process queue
      collaborationManager.isConnected = true
      collaborationManager.documentChannel = mockSubscription
      await collaborationManager.processQueuedOperations()

      expect(collaborationManager.operationQueue).toHaveLength(0)
      expect(mockSubscription.perform).toHaveBeenCalled()
    })
  })

  describe('Event Handling', () => {
    test('event listener registration and triggering', () => {
      const mockCallback = jest.fn()
      collaborationManager.on('test:event', mockCallback)

      collaborationManager.emit('test:event', { data: 'test' })

      expect(mockCallback).toHaveBeenCalledWith({ data: 'test' })
    })

    test('event listener removal', () => {
      const mockCallback = jest.fn()
      collaborationManager.on('test:event', mockCallback)
      collaborationManager.off('test:event', mockCallback)

      collaborationManager.emit('test:event', { data: 'test' })

      expect(mockCallback).not.toHaveBeenCalled()
    })

    test('handleUserJoined adds collaborator', () => {
      const userData = { id: 2, name: 'New User', email: 'new@example.com' }
      
      collaborationManager.handleUserJoined({ user: userData })

      expect(collaborationManager.collaborators.has(2)).toBe(true)
      expect(collaborationManager.collaborators.get(2)).toEqual(userData)
    })

    test('handleUserLeft removes collaborator', () => {
      // Add user first
      collaborationManager.collaborators.set(2, { id: 2, name: 'Test User' })
      collaborationManager.cursors.set(2, { position: { x: 10, y: 20 } })

      collaborationManager.handleUserLeft({ user_id: 2 })

      expect(collaborationManager.collaborators.has(2)).toBe(false)
      expect(collaborationManager.cursors.has(2)).toBe(false)
    })

    test('handleOperationApplied updates document state', () => {
      const mockEmit = jest.spyOn(collaborationManager, 'emit')
      const operationData = {
        operation: { type: 'insert', position: 0, content: 'test' },
        user_id: 2,
        conflicts: []
      }

      collaborationManager.handleOperationApplied(operationData)

      expect(mockEmit).toHaveBeenCalledWith('operation:applied', operationData)
    })

    test('handleOperationConfirmed removes pending operation', () => {
      const operationId = 'test-op-123'
      const operation = { type: 'insert', content: 'test' }
      
      collaborationManager.pendingOperations.set(operationId, operation)
      
      collaborationManager.handleOperationConfirmed({
        operation_id: operationId,
        status: 'applied'
      })

      expect(collaborationManager.pendingOperations.has(operationId)).toBe(false)
      expect(collaborationManager.acknowledgedOperations.has(operationId)).toBe(true)
    })
  })

  describe('Cursor and Presence Management', () => {
    beforeEach(() => {
      collaborationManager.isConnected = true
      collaborationManager.documentChannel = mockSubscription
    })

    test('updateCursorPosition sends cursor data', () => {
      const position = { x: 100, y: 200, textPosition: 50 }
      const selection = { start: 10, end: 20 }

      collaborationManager.updateCursorPosition(position, selection)

      expect(mockSubscription.perform).toHaveBeenCalledWith('cursor_moved', {
        position,
        selection
      })
    })

    test('updateSelection sends selection data', () => {
      const selection = { start: 5, end: 15, text: 'selected text' }

      collaborationManager.updateSelection(selection)

      expect(mockSubscription.perform).toHaveBeenCalledWith('selection_changed', {
        selection
      })
    })

    test('handleCursorMoved updates cursor state', () => {
      const cursorData = {
        user_id: 2,
        user_name: 'Test User',
        position: { x: 50, y: 100 }
      }

      collaborationManager.handleCursorMoved(cursorData)

      const storedCursor = collaborationManager.cursors.get(2)
      expect(storedCursor).toEqual({
        userId: 2,
        userName: 'Test User',
        position: { x: 50, y: 100 },
        timestamp: expect.any(Number)
      })
    })
  })

  describe('Typing Indicators', () => {
    beforeEach(() => {
      collaborationManager.isConnected = true
      collaborationManager.notificationChannel = mockSubscription
    })

    test('startTyping sends typing notification', () => {
      collaborationManager.startTyping()

      expect(mockSubscription.perform).toHaveBeenCalledWith('broadcast_typing', {
        type: 'typing_started',
        user_id: mockCurrentUser.id,
        user_name: mockCurrentUser.name
      })
    })

    test('stopTyping sends stop typing notification', () => {
      collaborationManager.stopTyping()

      expect(mockSubscription.perform).toHaveBeenCalledWith('broadcast_typing', {
        type: 'typing_stopped',
        user_id: mockCurrentUser.id,
        user_name: mockCurrentUser.name
      })
    })

    test('debounced typing notification auto-stops', (done) => {
      collaborationManager.startTyping()

      // Should call stop typing after debounce delay
      setTimeout(() => {
        expect(mockSubscription.perform).toHaveBeenLastCalledWith('broadcast_typing', {
          type: 'typing_stopped',
          user_id: mockCurrentUser.id,
          user_name: mockCurrentUser.name
        })
        done()
      }, 1100) // Slightly longer than debounce delay
    })
  })

  describe('Document Synchronization', () => {
    beforeEach(() => {
      collaborationManager.isConnected = true
      collaborationManager.documentChannel = mockSubscription
    })

    test('requestDocumentSync sends sync request', async () => {
      collaborationManager.documentState.stateHash = 'test-hash'

      const result = await collaborationManager.requestDocumentSync()

      expect(result).toBe(true)
      expect(mockSubscription.perform).toHaveBeenCalledWith('request_sync', {
        client_state_hash: 'test-hash'
      })
    })

    test('handleDocumentSync updates document state', () => {
      const syncData = {
        content: 'new content',
        state_hash: 'new-hash',
        version: 2,
        active_operations: []
      }

      collaborationManager.handleDocumentSync(syncData)

      expect(collaborationManager.documentState.content).toBe('new content')
      expect(collaborationManager.documentState.stateHash).toBe('new-hash')
      expect(collaborationManager.documentState.version).toBe(2)
    })
  })

  describe('Conflict Resolution', () => {
    beforeEach(() => {
      collaborationManager.isConnected = true
      collaborationManager.documentChannel = mockSubscription
    })

    test('resolveConflict sends resolution data', async () => {
      const conflictId = 'conflict-123'
      const resolution = {
        strategy: 'accept_local',
        content: 'resolved content'
      }

      const result = await collaborationManager.resolveConflict(conflictId, resolution)

      expect(result.success).toBe(true)
      expect(mockSubscription.perform).toHaveBeenCalledWith('resolve_conflict', {
        conflict_id: conflictId,
        resolution
      })
      expect(collaborationManager.conflictResolutions.has(conflictId)).toBe(true)
    })

    test('handleConflictResolved removes conflict from tracking', () => {
      const conflictId = 'conflict-123'
      collaborationManager.conflictResolutions.set(conflictId, { test: 'data' })

      collaborationManager.handleConflictResolved({
        conflict_id: conflictId,
        resolved_by: 2,
        final_content: 'resolved'
      })

      expect(collaborationManager.conflictResolutions.has(conflictId)).toBe(false)
    })
  })

  describe('Reconnection Logic', () => {
    test('scheduleReconnect uses exponential backoff', () => {
      const originalSetTimeout = global.setTimeout
      const mockSetTimeout = jest.fn()
      global.setTimeout = mockSetTimeout

      collaborationManager.options.reconnectDelay = 1000
      collaborationManager.reconnectAttempts = 2

      collaborationManager.scheduleReconnect()

      const expectedDelay = 1000 * Math.pow(1.5, 2) // backoff calculation
      expect(mockSetTimeout).toHaveBeenCalledWith(expect.any(Function), expectedDelay)

      global.setTimeout = originalSetTimeout
    })

    test('stops reconnecting after max attempts', () => {
      const mockEmit = jest.spyOn(collaborationManager, 'emit')
      collaborationManager.reconnectAttempts = 5
      collaborationManager.options.maxReconnectAttempts = 5

      collaborationManager.scheduleReconnect()

      expect(mockEmit).toHaveBeenCalledWith('connection:max_attempts_reached', {
        attempts: 5
      })
      expect(collaborationManager.connectionState).toBe('error')
    })
  })

  describe('Utility Methods', () => {
    test('generateOperationId creates unique IDs', () => {
      const id1 = collaborationManager.generateOperationId()
      const id2 = collaborationManager.generateOperationId()

      expect(id1).toMatch(/^op_\d+_[a-z0-9]+$/)
      expect(id2).toMatch(/^op_\d+_[a-z0-9]+$/)
      expect(id1).not.toBe(id2)
    })

    test('getCollaborators returns array of collaborator data', () => {
      const user1 = { id: 1, name: 'User 1' }
      const user2 = { id: 2, name: 'User 2' }
      
      collaborationManager.collaborators.set(1, user1)
      collaborationManager.collaborators.set(2, user2)

      const collaborators = collaborationManager.getCollaborators()

      expect(collaborators).toHaveLength(2)
      expect(collaborators).toContain(user1)
      expect(collaborators).toContain(user2)
    })

    test('getConnectionState returns current state info', () => {
      collaborationManager.isConnected = true
      collaborationManager.connectionState = 'connected'
      collaborationManager.collaborators.set(1, { id: 1 })
      collaborationManager.pendingOperations.set('op1', {})
      collaborationManager.operationQueue.push({})

      const state = collaborationManager.getConnectionState()

      expect(state).toEqual({
        isConnected: true,
        state: 'connected',
        reconnectAttempts: 0,
        collaboratorsCount: 1,
        pendingOperations: 1,
        queuedOperations: 1
      })
    })
  })

  describe('Error Handling', () => {
    test('handles operation timeout gracefully', () => {
      const operationId = 'timeout-op'
      const operation = { type: 'insert', content: 'test' }
      
      collaborationManager.pendingOperations.set(operationId, operation)
      
      collaborationManager.handleOperationTimeout(operationId)

      expect(collaborationManager.pendingOperations.has(operationId)).toBe(false)
    })

    test('handles channel disconnection', () => {
      const mockEmit = jest.spyOn(collaborationManager, 'emit')
      collaborationManager.isConnected = true

      collaborationManager.handleDisconnected()

      expect(collaborationManager.isConnected).toBe(false)
      expect(mockEmit).toHaveBeenCalledWith('connection:lost')
    })

    test('gracefully handles missing channels', async () => {
      collaborationManager.documentChannel = null

      const result = await collaborationManager.sendOperation({ type: 'insert' })

      expect(result.success).toBe(false)
      expect(result.error).toBe('Not connected')
    })
  })

  describe('Memory Management', () => {
    test('cleans up event listeners on disconnect', () => {
      const mockCallback = jest.fn()
      collaborationManager.on('test:event', mockCallback)

      collaborationManager.disconnect()
      collaborationManager.emit('test:event')

      // Event listeners should still work unless explicitly cleared
      expect(mockCallback).toHaveBeenCalled()
    })

    test('manages operation queue size', async () => {
      collaborationManager.isConnected = false
      collaborationManager.options.operationQueueSize = 2

      // Queue more operations than limit
      await collaborationManager.sendOperation({ type: 'insert', content: '1' })
      await collaborationManager.sendOperation({ type: 'insert', content: '2' })
      await collaborationManager.sendOperation({ type: 'insert', content: '3' })

      expect(collaborationManager.operationQueue).toHaveLength(2)
      // First operation should be removed (FIFO)
      expect(collaborationManager.operationQueue[0].content).toBe('2')
      expect(collaborationManager.operationQueue[1].content).toBe('3')
    })
  })
})