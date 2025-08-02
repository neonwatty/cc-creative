/**
 * Plugin Marketplace Test Suite
 * Comprehensive tests for PluginMarketplace functionality
 */

import PluginMarketplace from '../../app/javascript/services/plugin_marketplace.js'

describe('PluginMarketplace', () => {
  let marketplace
  let mockFetch

  beforeEach(() => {
    // Mock fetch
    mockFetch = jest.fn()
    global.fetch = mockFetch

    // Mock DOM methods
    document.body.innerHTML = ''
    document.createElement = jest.fn(document.createElement.bind(document))
    document.querySelector = jest.fn(document.querySelector.bind(document))

    // Mock CSRF token
    document.querySelector.mockImplementation((selector) => {
      if (selector === 'meta[name="csrf-token"]') {
        return { content: 'mock-csrf-token' }
      }
      return document.querySelector.bind(document)(selector)
    })

    // Initialize marketplace
    marketplace = new PluginMarketplace({
      baseUrl: '/extensions',
      autoRefresh: false,
      cacheTimeout: 1000
    })
  })

  afterEach(() => {
    if (marketplace && marketplace.container) {
      marketplace.container.remove()
    }
    jest.clearAllMocks()
  })

  describe('Initialization', () => {
    test('should initialize with default options', () => {
      expect(marketplace.options.baseUrl).toBe('/extensions')
      expect(marketplace.plugins).toBeInstanceOf(Map)
      expect(marketplace.installedPlugins).toBeInstanceOf(Map)
      expect(marketplace.categories).toBeInstanceOf(Set)
    })

    test('should create marketplace UI elements', () => {
      expect(marketplace.container).toBeTruthy()
      expect(marketplace.container.className).toBe('plugin-marketplace')
      
      const header = marketplace.container.querySelector('.marketplace-header')
      const nav = marketplace.container.querySelector('.marketplace-nav')
      const toolbar = marketplace.container.querySelector('.marketplace-toolbar')
      const body = marketplace.container.querySelector('.marketplace-body')
      
      expect(header).toBeTruthy()
      expect(nav).toBeTruthy()
      expect(toolbar).toBeTruthy()
      expect(body).toBeTruthy()
    })

    test('should be hidden initially', () => {
      expect(marketplace.container.style.display).toBe('none')
      expect(marketplace.isOpen).toBe(false)
    })
  })

  describe('Data Loading', () => {
    test('should load marketplace data', async () => {
      const mockData = {
        featured: [
          { id: '1', name: 'Featured Plugin', category: 'tools' }
        ],
        recent: [
          { id: '2', name: 'Recent Plugin', category: 'widgets' }
        ],
        categories: { tools: 5, widgets: 3 }
      }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockData)
      })

      await marketplace.loadMarketplaceData()

      expect(mockFetch).toHaveBeenCalledWith('/extensions/marketplace')
      expect(marketplace.plugins.size).toBe(2)
      expect(marketplace.categories.has('tools')).toBe(true)
      expect(marketplace.categories.has('widgets')).toBe(true)
    })

    test('should load installed plugins', async () => {
      const mockData = {
        plugins: [
          { id: '1', name: 'Installed Plugin', status: 'active' }
        ]
      }

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockData)
      })

      await marketplace.loadInstalledPlugins()

      expect(mockFetch).toHaveBeenCalledWith('/extensions/installed')
      expect(marketplace.installedPlugins.size).toBe(1)
    })

    test('should handle API errors gracefully', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      await expect(marketplace.loadMarketplaceData()).rejects.toThrow('Network error')
    })

    test('should use cache when available', async () => {
      const mockData = { featured: [], recent: [] }
      
      // Set cache
      marketplace.setCache('marketplace_data', mockData)
      
      await marketplace.loadMarketplaceData()
      
      // Should not make fetch call if cache is valid
      expect(mockFetch).not.toHaveBeenCalled()
    })

    test('should refresh stale cache', async () => {
      const mockData = { featured: [], recent: [] }
      
      // Set stale cache
      marketplace.cache.set('marketplace_data', {
        data: mockData,
        timestamp: Date.now() - 10000 // 10 seconds ago, older than 1 second timeout
      })

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockData)
      })
      
      await marketplace.loadMarketplaceData()
      
      expect(mockFetch).toHaveBeenCalled()
    })
  })

  describe('UI Interactions', () => {
    beforeEach(async () => {
      // Setup test data
      marketplace.plugins.set('1', {
        id: '1',
        name: 'Test Plugin',
        description: 'Test Description',
        author: 'Test Author',
        category: 'tools',
        featured: true
      })
    })

    test('should open marketplace', async () => {
      await marketplace.open()

      expect(marketplace.isOpen).toBe(true)
      expect(marketplace.container.style.display).toBe('flex')
    })

    test('should close marketplace', () => {
      marketplace.isOpen = true
      marketplace.container.style.display = 'flex'

      marketplace.close()

      expect(marketplace.isOpen).toBe(false)
      expect(marketplace.container.style.display).toBe('none')
    })

    test('should switch views', () => {
      marketplace.switchView('installed')

      const navButtons = marketplace.container.querySelectorAll('.nav-btn')
      const installedButton = Array.from(navButtons).find(btn => btn.dataset.view === 'installed')
      
      expect(installedButton.classList.contains('active')).toBe(true)
      expect(marketplace.currentView).toBe('installed')
    })

    test('should render marketplace view', () => {
      const renderSpy = jest.spyOn(marketplace, 'createPluginCard')
      
      marketplace.renderMarketplaceView()

      expect(renderSpy).toHaveBeenCalled()
    })

    test('should render installed view', () => {
      marketplace.installedPlugins.set('1', {
        id: '1',
        name: 'Installed Plugin',
        status: 'active'
      })

      const renderSpy = jest.spyOn(marketplace, 'createInstalledPluginCard')
      
      marketplace.renderInstalledView()

      expect(renderSpy).toHaveBeenCalled()
    })
  })

  describe('Plugin Management', () => {
    beforeEach(() => {
      marketplace.plugins.set('1', {
        id: '1',
        name: 'Test Plugin',
        description: 'Test Description'
      })
    })

    test('should install plugin', async () => {
      const plugin = marketplace.plugins.get('1')
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ success: true, message: 'Installed successfully' })
      })

      const result = await marketplace.installPlugin(plugin)

      expect(mockFetch).toHaveBeenCalledWith('/extensions/1/install', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      })
      expect(result).toEqual({ success: true, message: 'Installed successfully' })
    })

    test('should handle install failure', async () => {
      const plugin = marketplace.plugins.get('1')
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ success: false, error: 'Installation failed' })
      })

      await expect(marketplace.installPlugin(plugin))
        .rejects.toThrow('Installation failed')
    })

    test('should enable plugin', async () => {
      const installation = { id: '1', name: 'Test Plugin' }
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ success: true })
      })

      await marketplace.enablePlugin(installation)

      expect(mockFetch).toHaveBeenCalledWith('/extensions/1/enable', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      })
    })

    test('should disable plugin', async () => {
      const installation = { id: '1', name: 'Test Plugin' }
      
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ success: true })
      })

      await marketplace.disablePlugin(installation)

      expect(mockFetch).toHaveBeenCalledWith('/extensions/1/disable', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      })
    })

    test('should uninstall plugin with confirmation', async () => {
      const installation = { id: '1', name: 'Test Plugin' }
      
      global.confirm = jest.fn(() => true)
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ success: true })
      })

      await marketplace.uninstallPlugin(installation)

      expect(global.confirm).toHaveBeenCalledWith('Are you sure you want to uninstall Test Plugin?')
      expect(mockFetch).toHaveBeenCalledWith('/extensions/1/uninstall', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'mock-csrf-token'
        }
      })
    })

    test('should not uninstall plugin without confirmation', async () => {
      const installation = { id: '1', name: 'Test Plugin' }
      
      global.confirm = jest.fn(() => false)

      await marketplace.uninstallPlugin(installation)

      expect(mockFetch).not.toHaveBeenCalled()
    })
  })

  describe('Filtering and Search', () => {
    beforeEach(() => {
      marketplace.plugins.set('1', {
        id: '1',
        name: 'Text Editor',
        description: 'A text editing plugin',
        author: 'John Doe',
        category: 'editor',
        keywords: 'text,editing',
        featured: true
      })

      marketplace.plugins.set('2', {
        id: '2',
        name: 'Code Formatter',
        description: 'Formats your code',
        author: 'Jane Smith',
        category: 'tools',
        keywords: 'code,formatting',
        featured: false
      })
    })

    test('should filter plugins by search term', () => {
      // Mock search input
      const searchInput = document.createElement('input')
      searchInput.className = 'search-input'
      searchInput.value = 'text'
      marketplace.container.appendChild(searchInput)

      const { featured, regular } = marketplace.getFilteredPlugins()

      expect(featured).toHaveLength(1)
      expect(featured[0].name).toBe('Text Editor')
      expect(regular).toHaveLength(0)
    })

    test('should filter plugins by category', () => {
      // Mock category filter
      const categoryFilter = document.createElement('select')
      categoryFilter.className = 'category-filter'
      categoryFilter.value = 'tools'
      marketplace.container.appendChild(categoryFilter)

      // Mock search input
      const searchInput = document.createElement('input')
      searchInput.className = 'search-input'
      searchInput.value = ''
      marketplace.container.appendChild(searchInput)

      const { featured, regular } = marketplace.getFilteredPlugins()

      expect(featured).toHaveLength(0)
      expect(regular).toHaveLength(1)
      expect(regular[0].name).toBe('Code Formatter')
    })

    test('should sort plugins by name', () => {
      // Mock sort filter
      const sortFilter = document.createElement('select')
      sortFilter.className = 'sort-filter'
      sortFilter.value = 'name'
      marketplace.container.appendChild(sortFilter)

      // Mock other filters
      const searchInput = document.createElement('input')
      searchInput.className = 'search-input'
      searchInput.value = ''
      marketplace.container.appendChild(searchInput)

      const categoryFilter = document.createElement('select')
      categoryFilter.className = 'category-filter'
      categoryFilter.value = ''
      marketplace.container.appendChild(categoryFilter)

      const { featured, regular } = marketplace.getFilteredPlugins()
      const allPlugins = [...featured, ...regular]

      expect(allPlugins[0].name).toBe('Code Formatter')
      expect(allPlugins[1].name).toBe('Text Editor')
    })

    test('should debounce search input', () => {
      jest.useFakeTimers()
      
      const renderSpy = jest.spyOn(marketplace, 'renderMarketplaceView')
      
      marketplace.debounceSearch()
      marketplace.debounceSearch()
      marketplace.debounceSearch()

      // Should not have called render yet
      expect(renderSpy).not.toHaveBeenCalled()

      // Fast-forward time
      jest.advanceTimersByTime(300)

      // Should have called render once
      expect(renderSpy).toHaveBeenCalledTimes(1)

      jest.useRealTimers()
    })
  })

  describe('Widget Integration', () => {
    let mockWidgetFramework

    beforeEach(() => {
      mockWidgetFramework = {
        createWidget: jest.fn(),
        focusWidget: jest.fn(),
        showWidgetSettings: jest.fn(),
        closeWidget: jest.fn()
      }

      marketplace.registerWidgetFramework(mockWidgetFramework)
    })

    test('should register widget framework', () => {
      expect(marketplace.widgetFramework).toBe(mockWidgetFramework)
    })

    test('should create plugin widget', async () => {
      const plugin = { id: '1', name: 'Test Plugin' }
      
      marketplace.installedPlugins.set('1', { id: '1', status: 'active' })
      mockWidgetFramework.createWidget.mockResolvedValue({ id: 'widget-1' })

      await marketplace.createPluginWidget(plugin)

      expect(mockWidgetFramework.createWidget).toHaveBeenCalledWith('plugin', {
        title: 'Test Plugin Widget',
        pluginId: '1'
      })
    })

    test('should install plugin before creating widget if not installed', async () => {
      const plugin = { id: '1', name: 'Test Plugin' }
      
      global.confirm = jest.fn(() => true)
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ success: true })
      })

      const installSpy = jest.spyOn(marketplace, 'installPlugin').mockResolvedValue()
      mockWidgetFramework.createWidget.mockResolvedValue({ id: 'widget-1' })

      await marketplace.createPluginWidget(plugin)

      expect(installSpy).toHaveBeenCalledWith(plugin)
      expect(mockWidgetFramework.createWidget).toHaveBeenCalled()
    })

    test('should not create widget if installation declined', async () => {
      const plugin = { id: '1', name: 'Test Plugin' }
      
      global.confirm = jest.fn(() => false)

      await marketplace.createPluginWidget(plugin)

      expect(mockWidgetFramework.createWidget).not.toHaveBeenCalled()
    })
  })

  describe('Error Handling', () => {
    test('should handle network errors', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      const showStatusSpy = jest.spyOn(marketplace, 'showStatus')
      
      await marketplace.refreshData()

      expect(showStatusSpy).toHaveBeenCalledWith('Failed to load marketplace data', 'error')
    })

    test('should handle plugin action errors', async () => {
      const plugin = { id: '1', name: 'Test Plugin' }
      
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error'
      })

      await expect(marketplace.installPlugin(plugin))
        .rejects.toThrow('HTTP 500: Internal Server Error')
    })

    test('should show fallback message for unavailable features', async () => {
      marketplace.widgetFramework = null
      
      global.alert = jest.fn()
      
      await marketplace.createPluginWidget({ id: '1', name: 'Test Plugin' })

      expect(global.alert).toHaveBeenCalledWith('Widget framework is not available')
    })
  })

  describe('Status and Loading', () => {
    test('should show status messages', () => {
      const statusEl = document.createElement('div')
      statusEl.className = 'status-text'
      marketplace.container.appendChild(statusEl)

      marketplace.showStatus('Test message', 'success')

      expect(statusEl.textContent).toBe('Test message')
      expect(statusEl.className).toBe('status-text success')
    })

    test('should show and hide loading indicator', () => {
      const loadingEl = document.createElement('div')
      loadingEl.className = 'loading-indicator'
      loadingEl.style.display = 'none'
      marketplace.container.appendChild(loadingEl)

      marketplace.showLoading('Loading test...')
      expect(loadingEl.style.display).toBe('block')
      expect(loadingEl.textContent).toBe('Loading test...')

      marketplace.hideLoading()
      expect(loadingEl.style.display).toBe('none')
    })

    test('should auto-clear success messages', () => {
      jest.useFakeTimers()
      
      const statusEl = document.createElement('div')
      statusEl.className = 'status-text'
      marketplace.container.appendChild(statusEl)

      marketplace.showStatus('Success message', 'success')
      
      expect(statusEl.textContent).toBe('Success message')
      
      jest.advanceTimersByTime(3000)
      
      expect(statusEl.textContent).toBe('')

      jest.useRealTimers()
    })
  })

  describe('Cache Management', () => {
    test('should set and get cache with timestamp', () => {
      const data = { test: 'data' }
      marketplace.setCache('test-key', data)

      const cached = marketplace.getFromCache('test-key')
      expect(cached).toEqual(data)
    })

    test('should return null for expired cache', () => {
      const data = { test: 'data' }
      
      // Manually set expired cache
      marketplace.cache.set('test-key', {
        data: data,
        timestamp: Date.now() - 2000 // 2 seconds ago, older than 1 second timeout
      })

      const cached = marketplace.getFromCache('test-key')
      expect(cached).toBeNull()
      expect(marketplace.cache.has('test-key')).toBe(false)
    })

    test('should return valid cache within timeout', () => {
      const data = { test: 'data' }
      
      marketplace.cache.set('test-key', {
        data: data,
        timestamp: Date.now() - 500 // 0.5 seconds ago, within 1 second timeout
      })

      const cached = marketplace.getFromCache('test-key')
      expect(cached).toEqual(data)
    })
  })

  describe('Event System', () => {
    test('should emit events', () => {
      const mockCallback = jest.fn()
      marketplace.on('test-event', mockCallback)

      marketplace.emit('test-event', { data: 'test' })

      expect(mockCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: { data: 'test' }
        })
      )
    })

    test('should remove event listeners', () => {
      const mockCallback = jest.fn()
      marketplace.on('test-event', mockCallback)
      marketplace.off('test-event', mockCallback)

      marketplace.emit('test-event', { data: 'test' })

      expect(mockCallback).not.toHaveBeenCalled()
    })
  })
})