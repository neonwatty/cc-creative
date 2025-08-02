/**
 * Widget Manager Controller Test Suite
 * Tests for Stimulus controller integration with WidgetFramework
 */

import { Application } from "@hotwired/stimulus"
import WidgetManagerController from '../../app/javascript/controllers/widget_manager_controller.js'

// Mock WidgetFramework
jest.mock('../../app/javascript/services/widget_framework.js', () => ({
  WidgetFramework: jest.fn().mockImplementation(() => ({
    on: jest.fn(),
    createWidget: jest.fn(),
    saveLayout: jest.fn(),
    resetLayout: jest.fn(),
    clearAllWidgets: jest.fn(),
    widgets: new Map(),
    options: { autoSave: true }
  }))
}))

describe('WidgetManagerController', () => {
  let application
  let controller
  let element

  beforeEach(() => {
    // Setup Stimulus application
    application = Application.start()
    application.register("widget-manager", WidgetManagerController)

    // Create test element
    element = document.createElement('div')
    element.setAttribute('data-controller', 'widget-manager')
    element.setAttribute('data-widget-manager-document-id-value', '123')
    element.setAttribute('data-widget-manager-user-id-value', '456')

    // Add required targets
    const container = document.createElement('div')
    container.setAttribute('data-widget-manager-target', 'container')
    element.appendChild(container)

    const status = document.createElement('div')
    status.setAttribute('data-widget-manager-target', 'status')
    element.appendChild(status)

    document.body.appendChild(element)

    // Get controller instance
    controller = application.getControllerForElementAndIdentifier(element, 'widget-manager')
  })

  afterEach(() => {
    element.remove()
    application.stop()
    jest.clearAllMocks()
  })

  describe('Initialization', () => {
    test('should initialize controller with framework', () => {
      expect(controller.framework).toBeTruthy()
      expect(controller.widgetTypes).toBeTruthy()
      expect(controller.documentIdValue).toBe(123)
      expect(controller.userIdValue).toBe(456)
    })

    test('should setup widget types registry', () => {
      expect(controller.widgetTypes).toHaveProperty('text')
      expect(controller.widgetTypes).toHaveProperty('notes')
      expect(controller.widgetTypes).toHaveProperty('todo')
      expect(controller.widgetTypes).toHaveProperty('timer')
      expect(controller.widgetTypes).toHaveProperty('plugin')
      expect(controller.widgetTypes).toHaveProperty('ai-review')
      expect(controller.widgetTypes).toHaveProperty('console')
    })

    test('should register global event listeners', () => {
      const addEventListenerSpy = jest.spyOn(document, 'addEventListener')
      
      controller.bindGlobalEvents()
      
      expect(addEventListenerSpy).toHaveBeenCalledWith('create-widget', expect.any(Function))
      expect(addEventListenerSpy).toHaveBeenCalledWith('create-plugin-widget', expect.any(Function))
      expect(addEventListenerSpy).toHaveBeenCalledWith('create-ai-review-widget', expect.any(Function))
    })
  })

  describe('Widget Creation', () => {
    beforeEach(() => {
      controller.framework.createWidget.mockResolvedValue({
        id: 'widget-1',
        title: 'Test Widget',
        element: document.createElement('div')
      })
    })

    test('should create AI review widget', async () => {
      const widget = await controller.createAIReviewWidget({
        title: 'Test Review',
        code: 'function test() {}'
      })

      expect(controller.framework.createWidget).toHaveBeenCalledWith('ai-review', {
        title: 'Test Review',
        content: expect.stringContaining('ai-review-widget'),
        size: { width: 600, height: 500 },
        settings: { reviewType: 'review' },
        code: 'function test() {}'
      })
    })

    test('should create plugin widget', async () => {
      const widget = await controller.createPluginWidget({
        pluginId: 'test-plugin',
        title: 'Test Plugin Widget'
      })

      expect(controller.framework.createWidget).toHaveBeenCalledWith('plugin', {
        title: 'Test Plugin Widget',
        content: expect.stringContaining('plugin-widget'),
        size: { width: 400, height: 300 },
        pluginId: 'test-plugin'
      })
    })

    test('should require plugin ID for plugin widgets', async () => {
      await expect(controller.createPluginWidget({}))
        .rejects.toThrow('Plugin ID is required for plugin widgets')
    })

    test('should handle external widget creation events', async () => {
      const createSpy = jest.spyOn(controller.widgetTypes.text, 'creator')
      
      await controller.handleExternalWidgetCreation({
        type: 'text',
        options: { title: 'External Widget' }
      })

      expect(createSpy).toHaveBeenCalledWith({ title: 'External Widget' })
    })

    test('should handle unknown widget types', async () => {
      await expect(controller.handleExternalWidgetCreation({
        type: 'unknown',
        options: {}
      })).rejects.toThrow('Unknown widget type: unknown')
    })
  })

  describe('AI Review Integration', () => {
    let widget

    beforeEach(() => {
      widget = {
        id: 'widget-1',
        element: document.createElement('div'),
        settings: {}
      }

      // Setup mock DOM elements
      widget.element.innerHTML = `
        <div class="ai-review-widget">
          <div class="review-toolbar">
            <select class="review-type">
              <option value="review">Code Review</option>
            </select>
            <button data-action="start-review">Start Review</button>
          </div>
          <textarea class="review-code">test code</textarea>
          <div class="review-results"></div>
          <div class="status-text"></div>
        </div>
      `
    })

    test('should bind AI review events', () => {
      const startBtn = widget.element.querySelector('[data-action="start-review"]')
      const reviewType = widget.element.querySelector('.review-type')

      controller.bindAIReviewEvents(widget)

      // Simulate type change
      reviewType.value = 'suggest'
      reviewType.dispatchEvent(new Event('change'))

      expect(widget.settings.reviewType).toBe('suggest')
    })

    test('should perform AI review', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({
          status: 'success',
          result: { content: 'Review completed' }
        })
      })

      const resultsArea = widget.element.querySelector('.review-results')
      const statusArea = widget.element.querySelector('.status-text')

      await controller.performAIReview(widget, 'review', 'test code', resultsArea, statusArea)

      expect(global.fetch).toHaveBeenCalledWith('/documents/123/commands', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': null
        },
        body: JSON.stringify({
          command: 'review',
          parameters: [],
          selected_content: 'test code'
        })
      })

      expect(statusArea.textContent).toBe('review completed')
    })

    test('should handle AI review errors', async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error('Network error'))

      const resultsArea = widget.element.querySelector('.review-results')
      const statusArea = widget.element.querySelector('.status-text')

      await controller.performAIReview(widget, 'review', 'test code', resultsArea, statusArea)

      expect(statusArea.textContent).toContain('review failed: Network error')
    })

    test('should display review results', () => {
      const resultsArea = widget.element.querySelector('.review-results')
      const results = { content: 'Code looks good!' }

      controller.displayReviewResults(resultsArea, results)

      expect(resultsArea.innerHTML).toContain('Code looks good!')
    })

    test('should format review content', () => {
      const stringContent = 'Line 1\nLine 2'
      const formatted = controller.formatReviewContent(stringContent)
      expect(formatted).toBe('Line 1<br>Line 2')

      const objectContent = { key: 'value' }
      const formattedObject = controller.formatReviewContent(objectContent)
      expect(formattedObject).toContain('"key": "value"')
    })
  })

  describe('Plugin Widget Integration', () => {
    let widget

    beforeEach(() => {
      widget = {
        id: 'widget-1',
        pluginId: 'test-plugin',
        element: document.createElement('div')
      }

      widget.element.innerHTML = `
        <div class="plugin-widget">
          <div class="plugin-loading"></div>
          <div class="plugin-content" style="display: none;"></div>
          <div class="plugin-error" style="display: none;">
            <button data-action="retry-plugin">Retry</button>
          </div>
        </div>
      `
    })

    test('should initialize plugin widget', async () => {
      const loadingDiv = widget.element.querySelector('.plugin-loading')
      const contentDiv = widget.element.querySelector('.plugin-content')

      await controller.initializePluginWidget(widget)

      expect(loadingDiv.style.display).toBe('none')
      expect(contentDiv.style.display).toBe('block')
      expect(contentDiv.innerHTML).toContain('test-plugin')
    })

    test('should execute plugin action', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ success: true })
      })

      await controller.executePluginAction(widget)

      expect(global.fetch).toHaveBeenCalledWith('/extensions/test-plugin/execute', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': null
        },
        body: JSON.stringify({
          command: { action: 'widget-action' }
        })
      })
    })

    test('should handle plugin action errors', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ success: false, error: 'Plugin error' })
      })

      const showStatusSpy = jest.spyOn(controller, 'showStatus')

      await controller.executePluginAction(widget)

      expect(showStatusSpy).toHaveBeenCalledWith(
        'Plugin action failed: Plugin error',
        'error'
      )
    })
  })

  describe('Action Handlers', () => {
    test('should open marketplace', async () => {
      global.window.PluginMarketplace = {
        open: jest.fn()
      }

      const event = { preventDefault: jest.fn() }
      await controller.openMarketplace(event)

      expect(event.preventDefault).toHaveBeenCalled()
      expect(global.window.PluginMarketplace.open).toHaveBeenCalled()
    })

    test('should handle missing marketplace', async () => {
      global.window.PluginMarketplace = null

      const event = { preventDefault: jest.fn() }
      const showStatusSpy = jest.spyOn(controller, 'showStatus')

      await controller.openMarketplace(event)

      expect(showStatusSpy).toHaveBeenCalledWith(
        'Plugin marketplace not available',
        'error'
      )
    })

    test('should save layout', async () => {
      const event = { preventDefault: jest.fn() }
      await controller.saveLayout(event)

      expect(event.preventDefault).toHaveBeenCalled()
      expect(controller.framework.saveLayout).toHaveBeenCalled()
    })

    test('should reset layout', async () => {
      const event = { preventDefault: jest.fn() }
      await controller.resetLayout(event)

      expect(event.preventDefault).toHaveBeenCalled()
      expect(controller.framework.resetLayout).toHaveBeenCalled()
    })
  })

  describe('Status Management', () => {
    test('should show status messages', () => {
      controller.showStatus('Test message', 'success')

      const statusEl = element.querySelector('[data-widget-manager-target="status"]')
      expect(statusEl.textContent).toBe('Test message')
      expect(statusEl.className).toBe('widget-status success')
    })

    test('should auto-clear success messages', () => {
      jest.useFakeTimers()

      controller.showStatus('Success message', 'success')

      const statusEl = element.querySelector('[data-widget-manager-target="status"]')
      expect(statusEl.textContent).toBe('Success message')

      jest.advanceTimersByTime(3000)

      expect(statusEl.textContent).toBe('')

      jest.useRealTimers()
    })

    test('should show widget-specific status', () => {
      const statusElement = document.createElement('div')
      controller.showWidgetStatus(statusElement, 'Widget message', 'error')

      expect(statusElement.textContent).toBe('Widget message')
      expect(statusElement.className).toBe('status-text error')
    })
  })

  describe('Utility Methods', () => {
    test('should escape HTML', () => {
      const input = '<script>alert("xss")</script>'
      const escaped = controller.escapeHtml(input)

      expect(escaped).toBe('&lt;script&gt;alert("xss")&lt;/script&gt;')
    })

    test('should emit custom events', () => {
      const mockCallback = jest.fn()
      element.addEventListener('test-event', mockCallback)

      controller.emit('test-event', { data: 'test' })

      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: {
            data: 'test',
            controller: controller
          }
        })
      )
    })
  })

  describe('Cleanup', () => {
    test('should cleanup framework on disconnect', () => {
      controller.cleanup()

      expect(controller.framework).toBeNull()
    })

    test('should remove from global registry', () => {
      global.window.widgetFrameworks = new Map()
      global.window.widgetFrameworks.set(123, controller.framework)

      controller.cleanup()

      expect(global.window.widgetFrameworks.has(123)).toBe(false)
    })
  })

  describe('Framework Event Handling', () => {
    test('should setup framework event listeners', () => {
      const mockFramework = {
        on: jest.fn()
      }
      controller.framework = mockFramework

      controller.setupFrameworkEvents()

      expect(mockFramework.on).toHaveBeenCalledWith('framework:initialized', expect.any(Function))
      expect(mockFramework.on).toHaveBeenCalledWith('framework:error', expect.any(Function))
      expect(mockFramework.on).toHaveBeenCalledWith('widget:created', expect.any(Function))
      expect(mockFramework.on).toHaveBeenCalledWith('widget:closed', expect.any(Function))
      expect(mockFramework.on).toHaveBeenCalledWith('layout:saved', expect.any(Function))
    })

    test('should handle framework initialization', () => {
      const showStatusSpy = jest.spyOn(controller, 'showStatus')

      controller.setupFrameworkEvents()
      const initCallback = controller.framework.on.mock.calls
        .find(call => call[0] === 'framework:initialized')[1]

      initCallback()

      expect(showStatusSpy).toHaveBeenCalledWith('Widget framework ready', 'success')
    })

    test('should handle widget creation events', () => {
      const showStatusSpy = jest.spyOn(controller, 'showStatus')
      const updateCountSpy = jest.spyOn(controller, 'updateWidgetCount')
      const emitSpy = jest.spyOn(controller, 'emit')

      controller.setupFrameworkEvents()
      const createdCallback = controller.framework.on.mock.calls
        .find(call => call[0] === 'widget:created')[1]

      const mockEvent = {
        detail: {
          widget: { id: 'widget-1', title: 'Test Widget' }
        }
      }

      createdCallback(mockEvent)

      expect(showStatusSpy).toHaveBeenCalledWith('Widget "Test Widget" created', 'success')
      expect(updateCountSpy).toHaveBeenCalled()
      expect(emitSpy).toHaveBeenCalledWith('widget:created', {
        widget: mockEvent.detail.widget
      })
    })
  })

  describe('Fallback Behavior', () => {
    test('should fallback to legacy widget management without container', () => {
      // Remove container target
      element.querySelector('[data-widget-manager-target="container"]').remove()

      const loadWidgetsSpy = jest.spyOn(controller, 'loadWidgets')

      // Reconnect controller
      controller.disconnect()
      controller.connect()

      expect(loadWidgetsSpy).toHaveBeenCalled()
      expect(controller.framework).toBeUndefined()
    })
  })
})