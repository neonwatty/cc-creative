/**
 * Widget Framework Test Suite
 * Comprehensive tests for WidgetFramework functionality
 */

import { WidgetFramework } from '../../app/javascript/services/widget_framework.js'

describe('WidgetFramework', () => {
  let container
  let framework
  let mockOptions

  beforeEach(() => {
    // Create test container
    container = document.createElement('div')
    container.id = 'test-widget-container'
    document.body.appendChild(container)

    // Mock options
    mockOptions = {
      persistenceKey: 'test-widget-layout',
      defaultLayout: 'grid',
      maxWidgets: 5,
      enableDragDrop: true,
      enableResize: true,
      autoSave: false // Disable for testing
    }

    // Mock localStorage
    global.localStorage = {
      store: {},
      getItem: jest.fn((key) => global.localStorage.store[key] || null),
      setItem: jest.fn((key, value) => {
        global.localStorage.store[key] = value
      }),
      removeItem: jest.fn((key) => {
        delete global.localStorage.store[key]
      })
    }
  })

  afterEach(() => {
    if (framework) {
      framework.clearAllWidgets()
    }
    container.remove()
    global.localStorage.store = {}
    jest.clearAllMocks()
  })

  describe('Initialization', () => {
    test('should initialize with default options', async () => {
      framework = new WidgetFramework(container)
      
      expect(framework.container).toBe(container)
      expect(framework.widgets).toBeInstanceOf(Map)
      expect(framework.widgets.size).toBe(0)
      expect(container.classList.contains('widget-framework')).toBe(true)
    })

    test('should initialize with custom options', async () => {
      framework = new WidgetFramework(container, mockOptions)
      
      expect(framework.options.maxWidgets).toBe(5)
      expect(framework.options.enableDragDrop).toBe(true)
      expect(framework.options.autoSave).toBe(false)
    })

    test('should create toolbar and layout container', async () => {
      framework = new WidgetFramework(container, mockOptions)
      
      const toolbar = container.querySelector('.widget-toolbar')
      const layoutContainer = container.querySelector('.widget-layout')
      
      expect(toolbar).toBeTruthy()
      expect(layoutContainer).toBeTruthy()
      expect(layoutContainer.getAttribute('data-layout')).toBe('grid')
    })
  })

  describe('Widget Creation', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
    })

    test('should create a widget with default properties', async () => {
      const widget = await framework.createWidget('text', {
        title: 'Test Widget',
        content: '<p>Test content</p>'
      })

      expect(widget).toBeTruthy()
      expect(widget.id).toBeTruthy()
      expect(widget.type).toBe('text')
      expect(widget.title).toBe('Test Widget')
      expect(framework.widgets.has(widget.id)).toBe(true)
    })

    test('should create widget element with correct structure', async () => {
      const widget = await framework.createWidget('text', {
        title: 'Test Widget',
        content: '<p>Test content</p>'
      })

      const element = widget.element
      expect(element.classList.contains('widget')).toBe(true)
      expect(element.getAttribute('data-widget-id')).toBe(widget.id)
      expect(element.getAttribute('data-widget-type')).toBe('text')
      
      const titleElement = element.querySelector('.widget-title')
      expect(titleElement.textContent).toBe('Test Widget')
      
      const contentElement = element.querySelector('.widget-content')
      expect(contentElement.innerHTML).toBe('<p>Test content</p>')
    })

    test('should position widget correctly', async () => {
      const widget = await framework.createWidget('text', {
        position: { x: 100, y: 200 },
        size: { width: 300, height: 250 }
      })

      const element = widget.element
      expect(element.style.left).toBe('100px')
      expect(element.style.top).toBe('200px')
      expect(element.style.width).toBe('300px')
      expect(element.style.height).toBe('250px')
    })

    test('should respect max widgets limit', async () => {
      // Create max number of widgets
      for (let i = 0; i < mockOptions.maxWidgets; i++) {
        await framework.createWidget('text', { title: `Widget ${i}` })
      }

      expect(framework.widgets.size).toBe(mockOptions.maxWidgets)

      // Attempting to create another should not work
      try {
        await framework.createWidget('text', { title: 'Extra Widget' })
        fail('Should have thrown an error for exceeding max widgets')
      } catch (error) {
        expect(error.message).toContain('maximum number of widgets')
      }
    })
  })

  describe('Widget Management', () => {
    let widget

    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
      widget = await framework.createWidget('text', {
        title: 'Test Widget',
        content: '<p>Test content</p>'
      })
    })

    test('should close a widget', async () => {
      const widgetId = widget.id
      
      await framework.closeWidget(widget)
      
      expect(framework.widgets.has(widgetId)).toBe(false)
      expect(container.querySelector(`[data-widget-id="${widgetId}"]`)).toBe(null)
    })

    test('should focus a widget', async () => {
      framework.focusWidget(widget)
      
      expect(widget.element.classList.contains('focused')).toBe(true)
      expect(widget.lastUsed).toBeTruthy()
    })

    test('should minimize and restore widget', async () => {
      const originalHeight = widget.size.height

      await framework.toggleMinimizeWidget(widget)
      
      expect(widget.minimized).toBe(true)
      expect(widget.element.classList.contains('minimized')).toBe(true)
      expect(widget.element.style.height).toBe('30px')

      await framework.toggleMinimizeWidget(widget)
      
      expect(widget.minimized).toBe(false)
      expect(widget.element.classList.contains('minimized')).toBe(false)
      expect(widget.element.style.height).toBe(`${originalHeight}px`)
    })
  })

  describe('Drag and Drop', () => {
    let widget

    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
      widget = await framework.createWidget('text', {
        title: 'Test Widget',
        position: { x: 50, y: 50 }
      })
    })

    test('should start drag operation', () => {
      const mockEvent = {
        clientX: 100,
        clientY: 100,
        target: widget.element.querySelector('.widget-header'),
        preventDefault: jest.fn()
      }

      framework.startDragWidget(mockEvent, widget)

      expect(framework.isDragging).toBe(true)
      expect(framework.currentDragWidget).toBe(widget)
      expect(widget.element.classList.contains('dragging')).toBe(true)
    })

    test('should handle drag move', () => {
      // Start drag first
      framework.isDragging = true
      framework.currentDragWidget = widget
      framework.dragStartPosition = { x: 50, y: 50 }

      const mockEvent = {
        clientX: 150,
        clientY: 150
      }

      framework.handleDragMove(mockEvent)

      expect(widget.position.x).toBe(100) // 150 - 50
      expect(widget.position.y).toBe(100) // 150 - 50
      expect(widget.element.style.left).toBe('100px')
      expect(widget.element.style.top).toBe('100px')
    })

    test('should end drag operation', () => {
      framework.isDragging = true
      framework.currentDragWidget = widget
      widget.element.classList.add('dragging')

      framework.handleDragEnd()

      expect(framework.isDragging).toBe(false)
      expect(framework.currentDragWidget).toBe(null)
      expect(widget.element.classList.contains('dragging')).toBe(false)
    })

    test('should constrain widget position to container bounds', () => {
      // Mock container bounds
      jest.spyOn(framework.layoutContainer, 'getBoundingClientRect').mockReturnValue({
        width: 800,
        height: 600
      })

      const constrained = framework.getConstrainedPosition(-50, -50, widget)

      expect(constrained.x).toBe(0) // Constrained to minimum
      expect(constrained.y).toBe(0) // Constrained to minimum

      const constrainedMax = framework.getConstrainedPosition(1000, 1000, widget)
      
      expect(constrainedMax.x).toBeLessThanOrEqual(800 - widget.size.width)
      expect(constrainedMax.y).toBeLessThanOrEqual(600 - widget.size.height)
    })
  })

  describe('Layout Management', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
    })

    test('should save layout to localStorage', async () => {
      await framework.createWidget('text', { title: 'Widget 1' })
      await framework.createWidget('notes', { title: 'Widget 2' })

      await framework.saveLayout()

      expect(global.localStorage.setItem).toHaveBeenCalledWith(
        'test-widget-layout',
        expect.stringContaining('"version":"1.0"')
      )
    })

    test('should serialize layout correctly', async () => {
      const widget1 = await framework.createWidget('text', { title: 'Widget 1' })
      const widget2 = await framework.createWidget('notes', { title: 'Widget 2' })

      const layout = framework.serializeLayout()

      expect(layout.version).toBe('1.0')
      expect(layout.layout).toBe('grid')
      expect(layout.widgets).toHaveLength(2)
      expect(layout.widgets[0].id).toBe(widget1.id)
      expect(layout.widgets[1].id).toBe(widget2.id)
    })

    test('should restore layout from data', async () => {
      const layoutData = {
        version: '1.0',
        layout: 'grid',
        widgets: [
          {
            id: 'widget-1',
            type: 'text',
            title: 'Restored Widget',
            position: { x: 100, y: 100 },
            size: { width: 300, height: 200 }
          }
        ]
      }

      await framework.restoreLayout(layoutData)

      expect(framework.widgets.size).toBe(1)
      const widget = Array.from(framework.widgets.values())[0]
      expect(widget.title).toBe('Restored Widget')
      expect(widget.position.x).toBe(100)
      expect(widget.position.y).toBe(100)
    })

    test('should clear all widgets', () => {
      // Add some widgets first
      framework.widgets.set('widget-1', { 
        element: document.createElement('div'),
        id: 'widget-1'
      })
      framework.widgets.set('widget-2', { 
        element: document.createElement('div'),
        id: 'widget-2'
      })

      framework.clearAllWidgets()

      expect(framework.widgets.size).toBe(0)
    })

    test('should reset layout', async () => {
      await framework.createWidget('text', { title: 'Widget 1' })
      await framework.createWidget('notes', { title: 'Widget 2' })

      // Mock confirm dialog
      global.confirm = jest.fn(() => true)

      await framework.resetLayout()

      expect(framework.widgets.size).toBe(0)
      expect(global.localStorage.removeItem).toHaveBeenCalledWith('test-widget-layout')
    })
  })

  describe('Event System', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
    })

    test('should emit events', () => {
      const mockCallback = jest.fn()
      framework.on('test-event', mockCallback)

      framework.emit('test-event', { data: 'test' })

      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { data: 'test' }
        })
      )
    })

    test('should remove event listeners', () => {
      const mockCallback = jest.fn()
      framework.on('test-event', mockCallback)
      framework.off('test-event', mockCallback)

      framework.emit('test-event', { data: 'test' })

      expect(mockCallback).not.toHaveBeenCalled()
    })

    test('should emit widget lifecycle events', async () => {
      const createdCallback = jest.fn()
      const closedCallback = jest.fn()
      
      framework.on('widget:created', createdCallback)
      framework.on('widget:closed', closedCallback)

      const widget = await framework.createWidget('text', { title: 'Test Widget' })
      expect(createdCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { widget }
        })
      )

      await framework.closeWidget(widget)
      expect(closedCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { widget }
        })
      )
    })
  })

  describe('Utility Methods', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
    })

    test('should generate unique widget IDs', () => {
      const id1 = framework.generateWidgetId()
      const id2 = framework.generateWidgetId()

      expect(id1).toBeTruthy()
      expect(id2).toBeTruthy()
      expect(id1).not.toBe(id2)
      expect(id1).toMatch(/^widget-\d+-[a-z0-9]+$/)
    })

    test('should calculate next position for widgets', () => {
      const position1 = framework.getNextPosition()
      expect(position1).toEqual({ x: 50, y: 50 })

      // Add a widget to increase offset
      framework.widgets.set('widget-1', {})
      const position2 = framework.getNextPosition()
      expect(position2).toEqual({ x: 80, y: 80 })
    })

    test('should escape HTML properly', () => {
      const input = '<script>alert("xss")</script>'
      const escaped = framework.escapeHtml(input)
      
      expect(escaped).toBe('&lt;script&gt;alert("xss")&lt;/script&gt;')
    })
  })

  describe('Plugin Integration', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
    })

    test('should register with plugin manager', async () => {
      const mockPluginManager = {
        registerWidgetFramework: jest.fn()
      }
      global.window.PluginMarketplace = mockPluginManager

      await framework.connectPluginManager()

      expect(mockPluginManager.registerWidgetFramework).toHaveBeenCalledWith(framework)
    })

    test('should initialize plugin widget', async () => {
      const widget = await framework.createWidget('plugin', {
        title: 'Plugin Widget',
        pluginId: 'test-plugin'
      })

      expect(widget.type).toBe('plugin')
      expect(widget.pluginId).toBe('test-plugin')
    })
  })

  describe('Auto-save Functionality', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, {
        ...mockOptions,
        autoSave: true
      })
    })

    test('should auto-save on widget creation', async () => {
      const saveLayoutSpy = jest.spyOn(framework, 'saveLayout')

      await framework.createWidget('text', { title: 'Test Widget' })

      expect(saveLayoutSpy).toHaveBeenCalled()
    })

    test('should auto-save on widget close', async () => {
      const widget = await framework.createWidget('text', { title: 'Test Widget' })
      const saveLayoutSpy = jest.spyOn(framework, 'saveLayout')

      await framework.closeWidget(widget)

      expect(saveLayoutSpy).toHaveBeenCalled()
    })
  })

  describe('Error Handling', () => {
    beforeEach(async () => {
      framework = new WidgetFramework(container, mockOptions)
    })

    test('should handle widget creation errors gracefully', async () => {
      // Mock an error in widget element creation
      jest.spyOn(framework, 'createWidgetElement').mockRejectedValue(new Error('Creation failed'))

      await expect(framework.createWidget('text', { title: 'Test Widget' }))
        .rejects.toThrow('Creation failed')
    })

    test('should emit error events', async () => {
      const errorCallback = jest.fn()
      framework.on('framework:error', errorCallback)

      // Simulate an error
      framework.emit('framework:error', { error: new Error('Test error') })

      expect(errorCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { error: expect.any(Error) }
        })
      )
    })
  })
})