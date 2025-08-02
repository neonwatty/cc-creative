/**
 * CollaborationController Tests
 * Test suite for Stimulus collaboration controller
 */

import { describe, test, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { Application } from '@hotwired/stimulus'
import CollaborationController from '../../../app/javascript/controllers/collaboration_controller'

// Mock dependencies
jest.mock('../../../app/javascript/services/collaboration_manager')
jest.mock('../../../app/javascript/services/websocket_manager')

const MockCollaborationManager = jest.fn().mockImplementation(() => ({
  initialize: jest.fn().mockResolvedValue(true),
  disconnect: jest.fn(),
  sendOperation: jest.fn().mockResolvedValue({ success: true, operationId: 'test-op' }),
  sendBatchOperations: jest.fn().mockResolvedValue({ success: true, operationCount: 2 }),
  updateCursorPosition: jest.fn(),
  updateSelection: jest.fn(),
  startTyping: jest.fn(),
  stopTyping: jest.fn(),
  requestDocumentSync: jest.fn(),
  resolveConflict: jest.fn().mockResolvedValue({ success: true }),
  createVersion: jest.fn().mockResolvedValue({ success: true }),
  on: jest.fn(),
  off: jest.fn(),
  emit: jest.fn(),
  getConnectionState: jest.fn().mockReturnValue({
    isConnected: true,
    state: 'connected',
    reconnectAttempts: 0,
    collaboratorsCount: 1,
    pendingOperations: 0,
    queuedOperations: 0
  })
}))

jest.doMock('../../../app/javascript/services/collaboration_manager', () => ({
  default: MockCollaborationManager
}))

const mockWebSocketManager = {
  on: jest.fn(),
  off: jest.fn(),
  emit: jest.fn()
}

jest.doMock('../../../app/javascript/services/websocket_manager', () => ({
  default: mockWebSocketManager
}))

describe('CollaborationController', () => {
  let application
  let controller
  let element
  let mockCollaborationManager

  beforeEach(() => {
    // Setup DOM
    document.body.innerHTML = `
      <div data-controller="collaboration"
           data-collaboration-document-id-value="123"
           data-collaboration-current-user-value='{"id": 1, "name": "Test User", "email": "test@example.com"}'
           data-collaboration-auto-save-value="true"
           data-collaboration-enable-cursors-value="true"
           data-collaboration-enable-typing-value="true">
        
        <textarea data-collaboration-target="editor" id="editor">Initial content</textarea>
        
        <div data-collaboration-target="collaboratorsList" id="collaborators"></div>
        <div data-collaboration-target="typingIndicators" id="typing"></div>
        <div data-collaboration-target="connectionStatus" id="status"></div>
        <div data-collaboration-target="notifications" id="notifications"></div>
        
        <div data-collaboration-target="conflictDialog" id="conflict-dialog" style="display: none;">
          <div class="conflict-description"></div>
          <button class="btn-accept-local">Accept Local</button>
          <button class="btn-accept-remote">Accept Remote</button>
        </div>
      </div>
    `

    element = document.querySelector('[data-controller="collaboration"]')

    // Setup Stimulus application
    application = Application.start()
    application.register('collaboration', CollaborationController)

    // Get controller instance
    controller = application.getControllerForElementAndIdentifier(element, 'collaboration')

    // Mock the collaboration manager instance
    mockCollaborationManager = new MockCollaborationManager()
    controller.collaborationManager = mockCollaborationManager

    jest.clearAllMocks()
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ''
  })

  describe('Initialization', () => {
    test('connects with required values', () => {
      expect(controller.documentIdValue).toBe(123)
      expect(controller.currentUserValue).toEqual({
        id: 1,
        name: 'Test User',
        email: 'test@example.com'
      })
      expect(controller.autoSaveValue).toBe(true)
      expect(controller.enableCursorsValue).toBe(true)
      expect(controller.enableTypingValue).toBe(true)
    })

    test('initializes collaboration state', () => {
      expect(controller.collaborators).toBeInstanceOf(Map)
      expect(controller.typingUsers).toBeInstanceOf(Set)
      expect(controller.pendingOperations).toEqual([])
      expect(controller.conflictQueue).toEqual([])
    })

    test('sets up event listeners', () => {
      const editorTarget = controller.editorTarget
      
      // Check that event listeners are attached
      expect(editorTarget.onkeydown).toBeDefined()
    })
  })

  describe('Editor Event Handling', () => {
    test('handleEditorInput creates and queues operations', () => {
      const mockQueueOperation = jest.spyOn(controller, 'queueOperation').mockImplementation()
      const mockExtractOperation = jest.spyOn(controller, 'extractOperationFromInput')
        .mockReturnValue({ type: 'insert', position: 0, content: 'test' })

      controller.isInitialized = true
      const inputEvent = new Event('input')
      inputEvent.data = 'test'

      controller.handleEditorInput(inputEvent)

      expect(mockExtractOperation).toHaveBeenCalledWith(inputEvent)
      expect(mockQueueOperation).toHaveBeenCalledWith({ type: 'insert', position: 0, content: 'test' })
    })

    test('handleKeyDown triggers typing indicators', () => {
      controller.isInitialized = true
      controller.enableTypingValue = true
      
      const mockStartTyping = jest.spyOn(controller, 'startTyping').mockImplementation()
      
      const keyEvent = new KeyboardEvent('keydown', { key: 'a' })
      controller.handleKeyDown(keyEvent)

      expect(mockStartTyping).toHaveBeenCalled()
    })

    test('handleKeyDown handles save shortcut', () => {
      controller.isInitialized = true
      const mockSaveDocument = jest.spyOn(controller, 'saveDocument').mockImplementation()
      
      const keyEvent = new KeyboardEvent('keydown', { 
        key: 's', 
        ctrlKey: true, 
        preventDefault: jest.fn() 
      })
      
      controller.handleKeyDown(keyEvent)

      expect(keyEvent.preventDefault).toHaveBeenCalled()
      expect(mockSaveDocument).toHaveBeenCalled()
    })

    test('handlePaste creates paste operation', () => {
      controller.isInitialized = true
      const mockQueueOperation = jest.spyOn(controller, 'queueOperation').mockImplementation()
      
      const pasteEvent = new Event('paste')
      pasteEvent.clipboardData = {
        getData: jest.fn().mockReturnValue('pasted text')
      }

      controller.editorTarget.selectionStart = 10
      controller.handlePaste(pasteEvent)

      expect(mockQueueOperation).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'insert',
          position: 10,
          content: 'pasted text'
        })
      )
    })
  })

  describe('Collaboration Event Handling', () => {
    test('handleCollaboratorJoined updates collaborators list', () => {
      const user = { id: 2, name: 'New User', email: 'new@example.com' }
      const mockUpdateCollaboratorsList = jest.spyOn(controller, 'updateCollaboratorsList').mockImplementation()
      const mockShowNotification = jest.spyOn(controller, 'showNotification').mockImplementation()

      controller.handleCollaboratorJoined(user)

      expect(controller.collaborators.get(2)).toEqual(user)
      expect(mockUpdateCollaboratorsList).toHaveBeenCalled()
      expect(mockShowNotification).toHaveBeenCalledWith('New User joined the collaboration', 'info')
    })

    test('handleCollaboratorLeft removes user and updates display', () => {
      const user = { id: 2, name: 'Test User' }
      controller.collaborators.set(2, user)
      controller.typingUsers.add(2)

      const mockUpdateCollaboratorsList = jest.spyOn(controller, 'updateCollaboratorsList').mockImplementation()
      const mockUpdateTypingIndicators = jest.spyOn(controller, 'updateTypingIndicators').mockImplementation()

      controller.handleCollaboratorLeft(2)

      expect(controller.collaborators.has(2)).toBe(false)
      expect(controller.typingUsers.has(2)).toBe(false)
      expect(mockUpdateCollaboratorsList).toHaveBeenCalled()
      expect(mockUpdateTypingIndicators).toHaveBeenCalled()
    })

    test('handleOperationApplied applies remote operations', () => {
      const mockApplyOperationToEditor = jest.spyOn(controller, 'applyOperationToEditor').mockImplementation()
      const operationData = {
        operation: { type: 'insert', position: 5, content: 'hello' },
        userId: 2,
        conflicts: []
      }

      controller.handleOperationApplied(operationData)

      expect(mockApplyOperationToEditor).toHaveBeenCalledWith(operationData.operation)
    })

    test('handleOperationConfirmed removes pending operation', () => {
      const operationId = 'test-op-123'
      controller.pendingOperations = [{ operation_id: operationId, type: 'insert' }]
      
      const mockRemovePendingOperation = jest.spyOn(controller, 'removePendingOperation').mockImplementation()

      controller.handleOperationConfirmed({ operationId, status: 'applied' })

      expect(mockRemovePendingOperation).toHaveBeenCalledWith(operationId)
    })

    test('handleOperationError shows error notification', () => {
      const mockShowNotification = jest.spyOn(controller, 'showNotification').mockImplementation()
      const errorData = {
        error: 'Operation failed',
        operation: { type: 'insert' }
      }

      controller.handleOperationError(errorData)

      expect(mockShowNotification).toHaveBeenCalledWith('Operation failed: Operation failed', 'error')
    })
  })

  describe('Operation Management', () => {
    test('queueOperation adds to pending operations', () => {
      const operation = { type: 'insert', position: 0, content: 'test' }
      controller.operationBatchSizeValue = 5

      controller.queueOperation(operation)

      expect(controller.pendingOperations).toContain(operation)
    })

    test('queueOperation flushes when batch size reached', () => {
      const mockFlushPendingOperations = jest.spyOn(controller, 'flushPendingOperations').mockImplementation()
      controller.operationBatchSizeValue = 2

      controller.queueOperation({ type: 'insert', content: '1' })
      controller.queueOperation({ type: 'insert', content: '2' })

      expect(mockFlushPendingOperations).toHaveBeenCalled()
    })

    test('sendOperation calls collaboration manager for single operation', () => {
      controller.pendingOperations = [{ type: 'insert', content: 'test' }]

      controller.sendOperation()

      expect(mockCollaborationManager.sendOperation).toHaveBeenCalledWith({ type: 'insert', content: 'test' })
    })

    test('sendOperation calls collaboration manager for batch operations', () => {
      controller.pendingOperations = [
        { type: 'insert', content: '1' },
        { type: 'insert', content: '2' }
      ]
      controller.operationBatchSizeValue = 2

      controller.sendOperation()

      expect(mockCollaborationManager.sendBatchOperations).toHaveBeenCalledWith([
        { type: 'insert', content: '1' },
        { type: 'insert', content: '2' }
      ])
    })

    test('applyOperationToEditor modifies editor content', () => {
      const mockInsertTextAtPosition = jest.spyOn(controller, 'insertTextAtPosition').mockImplementation()
      const operation = { type: 'insert', position: 5, content: 'hello' }

      controller.applyOperationToEditor(operation)

      expect(mockInsertTextAtPosition).toHaveBeenCalledWith(controller.editorTarget, 5, 'hello')
    })
  })

  describe('Cursor and Selection Management', () => {
    test('getCursorPosition returns position relative to editor', () => {
      controller.editorTarget.selectionStart = 15
      controller.editorTarget.getBoundingClientRect = jest.fn().mockReturnValue({
        left: 100,
        top: 200
      })

      const mockEvent = { clientX: 150, clientY: 250 }
      const position = controller.getCursorPosition(mockEvent)

      expect(position).toEqual({
        x: 50,
        y: 50,
        textPosition: 15
      })
    })

    test('getSelectionData returns selection info', () => {
      controller.editorTarget.selectionStart = 5
      controller.editorTarget.selectionEnd = 15
      controller.editorTarget.value = 'Hello world, this is a test'

      const selection = controller.getSelectionData()

      expect(selection).toEqual({
        start: 5,
        end: 15,
        text: ' world, th'
      })
    })

    test('updateCursorPosition calls collaboration manager', () => {
      const position = { x: 100, y: 200 }
      const selection = { start: 5, end: 10 }

      controller.updateCursorPosition(position, selection)

      expect(mockCollaborationManager.updateCursorPosition).toHaveBeenCalledWith(position, selection)
    })
  })

  describe('Typing Indicators', () => {
    test('startTyping calls collaboration manager', () => {
      controller.startTyping()

      expect(mockCollaborationManager.startTyping).toHaveBeenCalled()
    })

    test('stopTyping calls collaboration manager', () => {
      controller.stopTyping()

      expect(mockCollaborationManager.stopTyping).toHaveBeenCalled()
    })

    test('updateTypingIndicators updates display with typing users', () => {
      controller.collaborators.set(2, { id: 2, name: 'User Two' })
      controller.collaborators.set(3, { id: 3, name: 'User Three' })
      controller.typingUsers.add(2)
      controller.typingUsers.add(3)

      controller.updateTypingIndicators()

      const indicator = controller.typingIndicatorsTarget
      expect(indicator.textContent).toContain('User Two and User Three are typing...')
      expect(indicator.style.display).toBe('block')
    })

    test('updateTypingIndicators hides indicator when no typing users', () => {
      controller.updateTypingIndicators()

      const indicator = controller.typingIndicatorsTarget
      expect(indicator.textContent).toBe('')
      expect(indicator.style.display).toBe('none')
    })
  })

  describe('Conflict Handling', () => {
    test('handleConflicts adds conflicts to queue', () => {
      const conflicts = [
        { id: 'conflict-1', description: 'Conflict 1' },
        { id: 'conflict-2', description: 'Conflict 2' }
      ]
      const mockShowConflictDialog = jest.spyOn(controller, 'showConflictDialog').mockImplementation()

      controller.handleConflicts(conflicts)

      expect(controller.conflictQueue).toHaveLength(2)
      expect(mockShowConflictDialog).toHaveBeenCalled()
    })

    test('resolveConflict calls collaboration manager', () => {
      const conflictId = 'conflict-123'
      const resolution = { strategy: 'accept_local', content: 'resolved' }

      controller.resolveConflict(conflictId, resolution)

      expect(mockCollaborationManager.resolveConflict).toHaveBeenCalledWith(conflictId, resolution)
    })

    test('showConflictDialog displays conflict information', () => {
      controller.conflictQueue = [{ description: 'Test conflict' }]

      controller.showConflictDialog()

      const dialog = controller.conflictDialogTarget
      expect(dialog.style.display).toBe('block')
      expect(dialog.querySelector('.conflict-description').textContent).toBe('Test conflict')
    })
  })

  describe('UI Updates', () => {
    test('updateConnectionStatus updates display and classes', () => {
      controller.updateConnectionStatus('connected')

      const status = controller.connectionStatusTarget
      expect(status.textContent).toBe('Connected')
      expect(status.classList.contains(controller.connectionGoodClass)).toBe(true)
    })

    test('updateCollaboratorsList displays active collaborators', () => {
      controller.collaborators.set(1, { id: 1, name: 'User One' })
      controller.collaborators.set(2, { id: 2, name: 'User Two' })
      controller.typingUsers.add(2)

      controller.updateCollaboratorsList()

      const list = controller.collaboratorsListTarget
      const collaboratorElements = list.querySelectorAll('.collaborator')
      
      expect(collaboratorElements).toHaveLength(2)
      expect(collaboratorElements[1].classList.contains(controller.collaboratorTypingClass)).toBe(true)
    })

    test('showNotification creates notification element', () => {
      controller.showNotification('Test message', 'info')

      const notifications = controller.notificationsTarget
      const notification = notifications.querySelector('.notification')
      
      expect(notification.textContent).toBe('Test message')
      expect(notification.classList.contains('notification-info')).toBe(true)
    })

    test('displayNotification auto-removes after delay', (done) => {
      jest.useFakeTimers()

      controller.displayNotification({
        id: 'test-notif',
        message: 'Test message',
        type: 'info'
      })

      const notifications = controller.notificationsTarget
      expect(notifications.children).toHaveLength(1)

      jest.advanceTimersByTime(5000)

      setTimeout(() => {
        expect(notifications.children).toHaveLength(0)
        jest.useRealTimers()
        done()
      }, 0)
    })
  })

  describe('Document Operations', () => {
    test('saveDocument flushes operations and creates version', () => {
      const mockFlushPendingOperations = jest.spyOn(controller, 'flushPendingOperations').mockImplementation()

      controller.saveDocument()

      expect(mockFlushPendingOperations).toHaveBeenCalled()
      expect(mockCollaborationManager.createVersion).toHaveBeenCalledWith(
        expect.objectContaining({
          notes: 'Manual save during collaboration'
        })
      )
    })

    test('forceSync requests document synchronization', () => {
      const mockShowNotification = jest.spyOn(controller, 'showNotification').mockImplementation()

      controller.forceSync()

      expect(mockCollaborationManager.requestDocumentSync).toHaveBeenCalled()
      expect(mockShowNotification).toHaveBeenCalledWith('Synchronization requested', 'info')
    })
  })

  describe('Text Manipulation Helpers', () => {
    test('insertTextAtPosition inserts text correctly', () => {
      const target = { value: 'Hello world' }
      
      controller.insertTextAtPosition(target, 5, ' beautiful')

      expect(target.value).toBe('Hello beautiful world')
    })

    test('deleteTextAtPosition removes text correctly', () => {
      const target = { value: 'Hello beautiful world' }
      
      controller.deleteTextAtPosition(target, 5, 10)

      expect(target.value).toBe('Hello world')
    })

    test('replaceTextAtPosition replaces text correctly', () => {
      const target = { value: 'Hello world' }
      
      controller.replaceTextAtPosition(target, 6, 5, 'universe')

      expect(target.value).toBe('Hello universe')
    })
  })

  describe('Public API', () => {
    test('getCollaborationInfo returns current state', () => {
      controller.collaborators.set(1, { id: 1, name: 'User One' })
      controller.typingUsers.add(1)
      controller.conflictQueue = [{ id: 'conflict-1' }]

      const info = controller.getCollaborationInfo()

      expect(info).toEqual(
        expect.objectContaining({
          isConnected: true,
          state: 'connected',
          collaborators: [{ id: 1, name: 'User One' }],
          typingUsers: [1],
          conflictQueue: 1
        })
      )
    })
  })

  describe('Cleanup', () => {
    test('disconnect cleans up resources', () => {
      controller.collaborators.set(1, { id: 1 })
      controller.typingUsers.add(1)
      controller.pendingOperations = [{ test: 'op' }]
      controller.conflictQueue = [{ test: 'conflict' }]

      controller.disconnect()

      expect(mockCollaborationManager.disconnect).toHaveBeenCalled()
      expect(controller.collaborators.size).toBe(0)
      expect(controller.typingUsers.size).toBe(0)
      expect(controller.pendingOperations).toHaveLength(0)
      expect(controller.conflictQueue).toHaveLength(0)
    })

    test('cleanup method resets all state', () => {
      controller.collaborators.set(1, { id: 1 })
      controller.isInitialized = true

      controller.cleanup()

      expect(controller.collaborationManager).toBeNull()
      expect(controller.collaborators.size).toBe(0)
      expect(controller.isInitialized).toBe(false)
    })
  })

  describe('Error Conditions', () => {
    test('handles missing documentId gracefully', () => {
      const elementWithoutDocId = document.createElement('div')
      elementWithoutDocId.setAttribute('data-controller', 'collaboration')
      elementWithoutDocId.setAttribute('data-collaboration-current-user-value', '{"id": 1}')
      
      const consoleError = jest.spyOn(console, 'error').mockImplementation()
      
      const testController = new CollaborationController()
      testController.element = elementWithoutDocId
      
      expect(() => testController.connect()).not.toThrow()
      expect(consoleError).toHaveBeenCalledWith(
        expect.stringContaining('requires documentId and currentUser values')
      )
      
      consoleError.mockRestore()
    })

    test('handles collaboration manager initialization failure', async () => {
      mockCollaborationManager.initialize.mockResolvedValue(false)
      const mockUpdateConnectionStatus = jest.spyOn(controller, 'updateConnectionStatus').mockImplementation()

      await controller.initializeCollaboration()

      expect(mockUpdateConnectionStatus).toHaveBeenCalledWith('error')
    })

    test('handles events when not initialized', () => {
      controller.isInitialized = false
      
      expect(() => {
        controller.handleEditorInput(new Event('input'))
        controller.handleKeyDown(new KeyboardEvent('keydown'))
        controller.handleSelectionChange(new Event('selectionchange'))
      }).not.toThrow()
    })
  })
})