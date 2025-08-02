import { Controller } from "@hotwired/stimulus"

/**
 * WidgetFramework - Core service for managing dynamic widgets and plugins
 * Provides widget lifecycle management, layout persistence, and plugin integration
 */
export class WidgetFramework {
  constructor(container, options = {}) {
    this.container = container
    this.options = {
      persistenceKey: "widget-layout",
      defaultLayout: "grid",
      maxWidgets: 20,
      enableDragDrop: true,
      enableResize: true,
      autoSave: true,
      ...options
    }
    
    this.widgets = new Map()
    this.layout = null
    this.eventEmitter = new EventTarget()
    this.pluginManager = null
    this.isDragging = false
    this.currentDragWidget = null
    
    this.init()
  }

  async init() {
    try {
      // Initialize container
      this.setupContainer()
      
      // Load saved layout or create default
      await this.loadLayout()
      
      // Setup drag and drop if enabled
      if (this.options.enableDragDrop) {
        this.initializeDragDrop()
      }
      
      // Setup auto-save if enabled
      if (this.options.autoSave) {
        this.initializeAutoSave()
      }
      
      // Connect to plugin manager
      await this.connectPluginManager()
      
      this.emit("framework:initialized")
    } catch (error) {
      console.error("Failed to initialize WidgetFramework:", error)
      this.emit("framework:error", { error })
    }
  }

  setupContainer() {
    this.container.classList.add("widget-framework")
    this.container.setAttribute("data-framework", "active")
    
    // Create layout container
    this.layoutContainer = document.createElement("div")
    this.layoutContainer.className = "widget-layout"
    this.layoutContainer.setAttribute("data-layout", this.options.defaultLayout)
    this.container.appendChild(this.layoutContainer)
    
    // Create widget toolbar
    this.toolbar = this.createToolbar()
    this.container.appendChild(this.toolbar)
  }

  createToolbar() {
    const toolbar = document.createElement("div")
    toolbar.className = "widget-toolbar"
    toolbar.innerHTML = `
      <div class="toolbar-section">
        <button type="button" class="btn btn-sm" data-action="add-widget">
          <span class="icon">+</span> Add Widget
        </button>
        <button type="button" class="btn btn-sm" data-action="layout-toggle">
          <span class="icon">⊞</span> Layout
        </button>
      </div>
      <div class="toolbar-section">
        <button type="button" class="btn btn-sm" data-action="save-layout">
          <span class="icon">💾</span> Save
        </button>
        <button type="button" class="btn btn-sm" data-action="reset-layout">
          <span class="icon">🗑</span> Reset
        </button>
      </div>
      <div class="toolbar-section">
        <button type="button" class="btn btn-sm" data-action="open-marketplace">
          <span class="icon">🏪</span> Marketplace
        </button>
      </div>
    `
    
    // Bind toolbar events
    toolbar.addEventListener("click", this.handleToolbarClick.bind(this))
    
    return toolbar
  }

  async handleToolbarClick(event) {
    const action = event.target.closest("[data-action]")?.dataset.action
    if (!action) return
    
    event.preventDefault()
    
    try {
      switch (action) {
      case "add-widget":
        await this.showWidgetCreator()
        break
      case "layout-toggle":
        await this.toggleLayout()
        break
      case "save-layout":
        await this.saveLayout()
        break
      case "reset-layout":
        await this.resetLayout()
        break
      case "open-marketplace":
        await this.openPluginMarketplace()
        break
      }
    } catch (error) {
      console.error(`Toolbar action '${action}' failed:`, error)
      this.emit("framework:error", { error, action })
    }
  }

  // Widget Management
  async createWidget(type, options = {}) {
    const widgetId = this.generateWidgetId()
    
    const widget = {
      id: widgetId,
      type: type,
      title: options.title || `${type} Widget`,
      content: options.content || "",
      position: options.position || this.getNextPosition(),
      size: options.size || { width: 300, height: 200 },
      minimized: false,
      settings: options.settings || {},
      pluginId: options.pluginId || null,
      element: null,
      controller: null,
      created: new Date().toISOString(),
      lastUsed: new Date().toISOString()
    }
    
    // Create DOM element
    widget.element = await this.createWidgetElement(widget)
    
    // Initialize widget controller if needed
    if (type === "plugin" && widget.pluginId) {
      await this.initializePluginWidget(widget)
    }
    
    // Add to layout
    this.layoutContainer.appendChild(widget.element)
    this.widgets.set(widgetId, widget)
    
    // Auto-save if enabled
    if (this.options.autoSave) {
      await this.saveLayout()
    }
    
    this.emit("widget:created", { widget })
    return widget
  }

  async createWidgetElement(widget) {
    const element = document.createElement("div")
    element.className = "widget"
    element.setAttribute("data-widget-id", widget.id)
    element.setAttribute("data-widget-type", widget.type)
    element.style.left = `${widget.position.x}px`
    element.style.top = `${widget.position.y}px`
    element.style.width = `${widget.size.width}px`
    element.style.height = `${widget.size.height}px`
    
    element.innerHTML = `
      <div class="widget-header">
        <div class="widget-title">${this.escapeHtml(widget.title)}</div>
        <div class="widget-controls">
          <button type="button" class="widget-btn" data-action="minimize" title="Minimize">
            <span class="icon">−</span>
          </button>
          <button type="button" class="widget-btn" data-action="settings" title="Settings">
            <span class="icon">⚙</span>
          </button>
          <button type="button" class="widget-btn" data-action="close" title="Close">
            <span class="icon">×</span>
          </button>
        </div>
      </div>
      <div class="widget-content">
        ${widget.content}
      </div>
      <div class="widget-footer">
        <div class="resize-handle"></div>
      </div>
    `
    
    // Bind widget events
    this.bindWidgetEvents(element, widget)
    
    return element
  }

  bindWidgetEvents(element, widget) {
    const header = element.querySelector(".widget-header")
    const controls = element.querySelector(".widget-controls")
    const resizeHandle = element.querySelector(".resize-handle")
    
    // Header drag for moving
    if (this.options.enableDragDrop) {
      header.addEventListener("mousedown", (e) => this.startDragWidget(e, widget))
    }
    
    // Control buttons
    controls.addEventListener("click", (e) => this.handleWidgetControl(e, widget))
    
    // Resize handle
    if (this.options.enableResize) {
      resizeHandle.addEventListener("mousedown", (e) => this.startResizeWidget(e, widget))
    }
    
    // Focus tracking
    element.addEventListener("mousedown", () => this.focusWidget(widget))
  }

  async handleWidgetControl(event, widget) {
    const action = event.target.closest("[data-action]")?.dataset.action
    if (!action) return
    
    event.preventDefault()
    event.stopPropagation()
    
    try {
      switch (action) {
      case "minimize":
        await this.toggleMinimizeWidget(widget)
        break
      case "settings":
        await this.showWidgetSettings(widget)
        break
      case "close":
        await this.closeWidget(widget)
        break
      }
    } catch (error) {
      console.error(`Widget control '${action}' failed:`, error)
      this.emit("widget:error", { widget, error, action })
    }
  }

  async closeWidget(widget) {
    // Emit event for confirmation
    const closeEvent = new CustomEvent("widget:before-close", { 
      detail: { widget },
      cancelable: true 
    })
    this.eventEmitter.dispatchEvent(closeEvent)
    
    if (closeEvent.defaultPrevented) {
      return
    }
    
    // Cleanup plugin if needed
    if (widget.pluginId && this.pluginManager) {
      await this.pluginManager.cleanupWidgetPlugin(widget)
    }
    
    // Remove from DOM and registry
    if (widget.element) {
      widget.element.remove()
    }
    this.widgets.delete(widget.id)
    
    // Auto-save if enabled
    if (this.options.autoSave) {
      await this.saveLayout()
    }
    
    this.emit("widget:closed", { widget })
  }

  async toggleMinimizeWidget(widget) {
    widget.minimized = !widget.minimized
    widget.element.classList.toggle("minimized", widget.minimized)
    
    if (widget.minimized) {
      widget.element.style.height = "30px"
    } else {
      widget.element.style.height = `${widget.size.height}px`
    }
    
    this.emit("widget:minimized", { widget, minimized: widget.minimized })
  }

  focusWidget(widget) {
    // Remove focus from other widgets
    this.widgets.forEach((w) => {
      if (w.element) {
        w.element.classList.remove("focused")
      }
    })
    
    // Focus current widget
    widget.element.classList.add("focused")
    widget.lastUsed = new Date().toISOString()
    
    this.emit("widget:focused", { widget })
  }

  // Drag and Drop Implementation
  initializeDragDrop() {
    document.addEventListener("mousemove", this.handleDragMove.bind(this))
    document.addEventListener("mouseup", this.handleDragEnd.bind(this))
  }

  startDragWidget(event, widget) {
    if (event.target.closest(".widget-controls")) return
    
    this.isDragging = true
    this.currentDragWidget = widget
    this.dragStartPosition = {
      x: event.clientX - widget.position.x,
      y: event.clientY - widget.position.y
    }
    
    widget.element.classList.add("dragging")
    document.body.classList.add("widget-dragging")
    
    event.preventDefault()
    this.emit("widget:drag-start", { widget })
  }

  handleDragMove(event) {
    if (!this.isDragging || !this.currentDragWidget) return
    
    const widget = this.currentDragWidget
    const newX = event.clientX - this.dragStartPosition.x
    const newY = event.clientY - this.dragStartPosition.y
    
    // Constrain to container bounds
    const bounds = this.getConstrainedPosition(newX, newY, widget)
    
    widget.position.x = bounds.x
    widget.position.y = bounds.y
    widget.element.style.left = `${bounds.x}px`
    widget.element.style.top = `${bounds.y}px`
    
    this.emit("widget:drag-move", { widget, position: bounds })
  }

  handleDragEnd() {
    if (!this.isDragging) return
    
    const widget = this.currentDragWidget
    
    this.isDragging = false
    this.currentDragWidget = null
    this.dragStartPosition = null
    
    if (widget) {
      widget.element.classList.remove("dragging")
      this.emit("widget:drag-end", { widget })
    }
    
    document.body.classList.remove("widget-dragging")
    
    // Auto-save if enabled
    if (this.options.autoSave) {
      this.saveLayout()
    }
  }

  getConstrainedPosition(x, y, widget) {
    const containerRect = this.layoutContainer.getBoundingClientRect()
    const minX = 0
    const minY = 0
    const maxX = containerRect.width - widget.size.width
    const maxY = containerRect.height - widget.size.height
    
    return {
      x: Math.max(minX, Math.min(maxX, x)),
      y: Math.max(minY, Math.min(maxY, y))
    }
  }

  // Layout Management
  async loadLayout() {
    try {
      const savedLayout = localStorage.getItem(this.options.persistenceKey)
      if (savedLayout) {
        const layout = JSON.parse(savedLayout)
        await this.restoreLayout(layout)
      }
    } catch (error) {
      console.warn("Failed to load saved layout:", error)
      await this.createDefaultLayout()
    }
  }

  async saveLayout() {
    try {
      const layout = this.serializeLayout()
      localStorage.setItem(this.options.persistenceKey, JSON.stringify(layout))
      this.emit("layout:saved", { layout })
    } catch (error) {
      console.error("Failed to save layout:", error)
      this.emit("layout:save-error", { error })
    }
  }

  serializeLayout() {
    const widgets = Array.from(this.widgets.values()).map(widget => ({
      id: widget.id,
      type: widget.type,
      title: widget.title,
      position: widget.position,
      size: widget.size,
      minimized: widget.minimized,
      settings: widget.settings,
      pluginId: widget.pluginId,
      created: widget.created,
      lastUsed: widget.lastUsed
    }))
    
    return {
      version: "1.0",
      layout: this.options.defaultLayout,
      widgets: widgets,
      saved: new Date().toISOString()
    }
  }

  async restoreLayout(layout) {
    // Clear existing widgets
    this.clearAllWidgets()
    
    // Restore widgets
    for (const widgetData of layout.widgets || []) {
      await this.createWidget(widgetData.type, {
        title: widgetData.title,
        position: widgetData.position,
        size: widgetData.size,
        settings: widgetData.settings,
        pluginId: widgetData.pluginId
      })
    }
    
    this.emit("layout:restored", { layout })
  }

  clearAllWidgets() {
    this.widgets.forEach(widget => {
      if (widget.element) {
        widget.element.remove()
      }
    })
    this.widgets.clear()
  }

  async resetLayout() {
    const confirmed = confirm("Reset all widgets to default layout? This action cannot be undone.")
    if (!confirmed) return
    
    this.clearAllWidgets()
    localStorage.removeItem(this.options.persistenceKey)
    await this.createDefaultLayout()
    
    this.emit("layout:reset")
  }

  async createDefaultLayout() {
    // Create some default widgets
    await this.createWidget("welcome", {
      title: "Welcome",
      content: "<p>Welcome to the Widget Framework!</p>",
      position: { x: 20, y: 20 },
      size: { width: 300, height: 200 }
    })
  }

  // Plugin Integration
  async connectPluginManager() {
    if (window.PluginMarketplace) {
      this.pluginManager = window.PluginMarketplace
      this.pluginManager.registerWidgetFramework(this)
    }
  }

  async initializePluginWidget(widget) {
    if (!this.pluginManager) return
    
    try {
      const result = await this.pluginManager.loadWidgetPlugin(widget.pluginId, widget)
      widget.controller = result.controller
      this.emit("widget:plugin-loaded", { widget, result })
    } catch (error) {
      console.error("Failed to initialize plugin widget:", error)
      this.emit("widget:plugin-error", { widget, error })
    }
  }

  // Utility Methods
  generateWidgetId() {
    return `widget-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  }

  getNextPosition() {
    const existing = Array.from(this.widgets.values())
    const offset = existing.length * 30
    return { x: 50 + offset, y: 50 + offset }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
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

  // Widget Creation UI
  async showWidgetCreator() {
    const modal = this.createWidgetCreatorModal()
    document.body.appendChild(modal)
    
    // Focus first input
    const firstInput = modal.querySelector("input, select")
    if (firstInput) firstInput.focus()
  }

  createWidgetCreatorModal() {
    const modal = document.createElement("div")
    modal.className = "widget-modal"
    modal.innerHTML = `
      <div class="modal-backdrop"></div>
      <div class="modal-content">
        <div class="modal-header">
          <h3>Create New Widget</h3>
          <button type="button" class="btn-close" data-action="close">&times;</button>
        </div>
        <div class="modal-body">
          <form class="widget-creator-form">
            <div class="form-group">
              <label for="widget-type">Widget Type</label>
              <select id="widget-type" name="type" required>
                <option value="">Select type...</option>
                <option value="text">Text Widget</option>
                <option value="notes">Notes Widget</option>
                <option value="todo">Todo List</option>
                <option value="timer">Timer Widget</option>
                <option value="plugin">Plugin Widget</option>
              </select>
            </div>
            <div class="form-group">
              <label for="widget-title">Title</label>
              <input type="text" id="widget-title" name="title" required>
            </div>
            <div class="form-group plugin-only" style="display: none;">
              <label for="plugin-select">Plugin</label>
              <select id="plugin-select" name="pluginId">
                <option value="">Select plugin...</option>
              </select>
            </div>
          </form>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-action="close">Cancel</button>
          <button type="button" class="btn btn-primary" data-action="create">Create Widget</button>
        </div>
      </div>
    `
    
    // Bind modal events
    modal.addEventListener("click", async (e) => {
      const action = e.target.dataset.action
      if (action === "close") {
        modal.remove()
      } else if (action === "create") {
        await this.handleCreateWidget(modal)
      }
    })
    
    // Handle type change
    const typeSelect = modal.querySelector("#widget-type")
    const pluginGroup = modal.querySelector(".plugin-only")
    typeSelect.addEventListener("change", () => {
      pluginGroup.style.display = typeSelect.value === "plugin" ? "block" : "none"
    })
    
    return modal
  }

  async handleCreateWidget(modal) {
    const form = modal.querySelector(".widget-creator-form")
    const formData = new FormData(form)
    
    const type = formData.get("type")
    const title = formData.get("title")
    const pluginId = formData.get("pluginId")
    
    if (!type || !title) {
      alert("Please fill in all required fields")
      return
    }
    
    try {
      await this.createWidget(type, {
        title: title,
        pluginId: pluginId || null
      })
      modal.remove()
    } catch (error) {
      console.error("Failed to create widget:", error)
      alert("Failed to create widget. Please try again.")
    }
  }

  async toggleLayout() {
    const layouts = ["grid", "column", "row"]
    const currentLayout = this.layoutContainer.dataset.layout
    const currentIndex = layouts.indexOf(currentLayout)
    const nextLayout = layouts[(currentIndex + 1) % layouts.length]
    
    this.layoutContainer.dataset.layout = nextLayout
    this.emit("layout:changed", { layout: nextLayout })
  }

  async openPluginMarketplace() {
    if (window.PluginMarketplace) {
      window.PluginMarketplace.open()
    } else {
      alert("Plugin Marketplace is not available")
    }
  }

  async showWidgetSettings(widget) {
    const modal = this.createWidgetSettingsModal(widget)
    document.body.appendChild(modal)
  }

  createWidgetSettingsModal(widget) {
    const modal = document.createElement("div")
    modal.className = "widget-modal"
    modal.innerHTML = `
      <div class="modal-backdrop"></div>
      <div class="modal-content">
        <div class="modal-header">
          <h3>Widget Settings</h3>
          <button type="button" class="btn-close" data-action="close">&times;</button>
        </div>
        <div class="modal-body">
          <form class="widget-settings-form">
            <div class="form-group">
              <label for="setting-title">Title</label>
              <input type="text" id="setting-title" name="title" value="${this.escapeHtml(widget.title)}">
            </div>
            <div class="form-group">
              <label for="setting-width">Width (px)</label>
              <input type="number" id="setting-width" name="width" value="${widget.size.width}" min="200">
            </div>
            <div class="form-group">
              <label for="setting-height">Height (px)</label>
              <input type="number" id="setting-height" name="height" value="${widget.size.height}" min="100">
            </div>
          </form>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-action="close">Cancel</button>
          <button type="button" class="btn btn-primary" data-action="save">Save Settings</button>
        </div>
      </div>
    `
    
    // Bind modal events
    modal.addEventListener("click", async (e) => {
      const action = e.target.dataset.action
      if (action === "close") {
        modal.remove()
      } else if (action === "save") {
        await this.handleSaveWidgetSettings(modal, widget)
      }
    })
    
    return modal
  }

  async handleSaveWidgetSettings(modal, widget) {
    const form = modal.querySelector(".widget-settings-form")
    const formData = new FormData(form)
    
    const title = formData.get("title")
    const width = parseInt(formData.get("width"))
    const height = parseInt(formData.get("height"))
    
    // Update widget
    widget.title = title
    widget.size.width = width
    widget.size.height = height
    
    // Update DOM
    widget.element.querySelector(".widget-title").textContent = title
    widget.element.style.width = `${width}px`
    widget.element.style.height = `${height}px`
    
    // Auto-save if enabled
    if (this.options.autoSave) {
      await this.saveLayout()
    }
    
    modal.remove()
    this.emit("widget:settings-saved", { widget })
  }

  // Auto-save initialization
  initializeAutoSave() {
    // Save layout on widget changes
    this.on("widget:created", () => this.saveLayout())
    this.on("widget:closed", () => this.saveLayout())
    this.on("widget:settings-saved", () => this.saveLayout())
    
    // Debounced save on position changes
    let saveTimeout
    this.on("widget:drag-end", () => {
      clearTimeout(saveTimeout)
      saveTimeout = setTimeout(() => this.saveLayout(), 1000)
    })
  }
}

// Export for global access
window.WidgetFramework = WidgetFramework