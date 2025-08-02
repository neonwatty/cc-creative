import { Controller } from "@hotwired/stimulus"
import { WidgetFramework } from "../services/widget_framework"

// Connects to data-controller="widget-container"
export default class extends Controller {
  static targets = [
    "widgetArea", "widgetContent", "emptyState", "dockingZone", "snapGrid",
    "guidelines", "verticalGuideline", "horizontalGuideline", "customGuidelines",
    "layoutSwitcher", "quickAddButton", "statusBar", "statusIndicator", 
    "statusMessage", "currentLayout", "autoSaveStatus", "snapStatus",
    "performanceMonitor", "widgetCount", "fpsCounter", "memoryUsage",
    "shortcutsHelp"
  ]

  static values = {
    documentId: Number,
    userId: Number,
    layoutMode: { type: String, default: "grid" },
    enableDocking: { type: Boolean, default: true },
    showGuidelines: { type: Boolean, default: true },
    autoSave: { type: Boolean, default: true },
    maxWidgets: { type: Number, default: 20 },
    enableResize: { type: Boolean, default: true },
    enableSnap: { type: Boolean, default: true },
    snapGrid: { type: Number, default: 20 }
  }

  static classes = [
    "dockingZoneActive", "snapGridVisible", "guidelinesVisible",
    "statusBarVisible", "performanceMonitorVisible", "emptyStateHidden"
  ]

  connect() {
    this.widgets = new Map()
    this.isDragging = false
    this.isResizing = false
    this.selectedWidgets = new Set()
    this.dragStartPos = null
    this.lastFrameTime = performance.now()
    this.frameCount = 0
    
    // Initialize widget framework
    this.initializeFramework()
    
    // Setup event listeners
    this.setupEventListeners()
    this.setupKeyboardShortcuts()
    
    // Initialize performance monitoring
    if (this.hasPerformanceMonitorTarget) {
      this.initializePerformanceMonitoring()
    }
    
    // Update UI state
    this.updateLayoutDisplay()
    this.updateStatusBar()
    
    // Auto-hide status bar after initial load
    setTimeout(() => this.hideStatusBar(), 3000)
  }

  disconnect() {
    this.cleanup()
  }

  // === FRAMEWORK INITIALIZATION ===

  async initializeFramework() {
    try {
      this.framework = new WidgetFramework(this.widgetContentTarget, {
        persistenceKey: `widget-layout-${this.documentIdValue}`,
        defaultLayout: this.layoutModeValue,
        maxWidgets: this.maxWidgetsValue,
        enableDragDrop: true,
        enableResize: this.enableResizeValue,
        autoSave: this.autoSaveValue
      })

      // Setup framework event handlers
      this.setupFrameworkEvents()
      
      // Register globally
      if (!window.widgetFrameworks) {
        window.widgetFrameworks = new Map()
      }
      window.widgetFrameworks.set(this.documentIdValue, this.framework)
      
      // Connect to plugin marketplace
      if (window.PluginMarketplace) {
        window.PluginMarketplace.registerWidgetFramework(this.framework)
      }
      
      this.showStatusMessage("Widget framework initialized", "success")
    } catch (error) {
      console.error("Failed to initialize widget framework:", error)
      this.showStatusMessage("Failed to initialize framework", "error")
    }
  }

  setupFrameworkEvents() {
    if (!this.framework) return

    this.framework.on("widget:created", (event) => {
      this.handleWidgetCreated(event.detail)
    })

    this.framework.on("widget:closed", (event) => {
      this.handleWidgetClosed(event.detail)
    })

    this.framework.on("widget:drag-start", () => {
      this.handleDragStart()
    })

    this.framework.on("widget:drag-move", (event) => {
      this.handleDragMove(event.detail)
    })

    this.framework.on("widget:drag-end", () => {
      this.handleDragEnd()
    })

    this.framework.on("layout:saved", () => {
      this.showStatusMessage("Layout saved", "success")
    })

    this.framework.on("framework:error", (event) => {
      this.showStatusMessage(`Error: ${event.detail.error.message}`, "error")
    })
  }

  // === EVENT LISTENERS ===

  setupEventListeners() {
    // Window resize
    window.addEventListener("resize", this.debounce(this.handleWindowResize.bind(this), 250))
    
    // Visibility change
    document.addEventListener("visibilitychange", this.handleVisibilityChange.bind(this))
    
    // Custom events
    document.addEventListener("widget-container:show-guidelines", () => this.showGuidelines())
    document.addEventListener("widget-container:hide-guidelines", () => this.hideGuidelines())
    document.addEventListener("widget-container:toggle-snap", () => this.toggleSnap())
  }

  setupKeyboardShortcuts() {
    document.addEventListener("keydown", (event) => {
      // Only handle shortcuts when container is focused or no input is active
      if (this.isInputFocused() && !this.element.contains(document.activeElement)) return

      const { metaKey, ctrlKey, key, shiftKey } = event
      const cmdKey = metaKey || ctrlKey

      switch (key) {
      case "n":
      case "N":
        if (cmdKey) {
          event.preventDefault()
          this.openWidgetCreator()
        }
        break
      
      case "s":
      case "S":
        if (cmdKey) {
          event.preventDefault()
          this.saveLayout()
        }
        break
      
      case "a":
      case "A":
        if (cmdKey) {
          event.preventDefault()
          this.selectAllWidgets()
        }
        break
      
      case "Delete":
      case "Backspace":
        if (this.selectedWidgets.size > 0) {
          event.preventDefault()
          this.deleteSelectedWidgets()
        }
        break
      
      case "g":
      case "G":
        if (!cmdKey) {
          event.preventDefault()
          this.toggleSnap()
        }
        break
      
      case "h":
      case "H":
        if (!cmdKey) {
          event.preventDefault()
          this.toggleGuidelines()
        }
        break
      
      case "?":
        if (!cmdKey) {
          event.preventDefault()
          this.showShortcuts()
        }
        break
      
      case "Escape":
        this.clearSelection()
        this.hideShortcuts()
        break
      }
    })
  }

  // === WIDGET MANAGEMENT ===

  async createQuickWidget(event) {
    const widgetType = event.currentTarget.dataset.widgetType
    
    try {
      await this.framework.createWidget(widgetType, {
        title: `${widgetType.charAt(0).toUpperCase() + widgetType.slice(1)} Widget`,
        position: this.getOptimalPosition()
      })
      
      this.hideEmptyState()
      this.showStatusMessage(`${widgetType} widget created`, "success")
    } catch (error) {
      console.error("Failed to create widget:", error)
      this.showStatusMessage("Failed to create widget", "error")
    }
  }

  async openWidgetCreator() {
    // Dispatch event for widget creation wizard
    this.dispatch("show-widget-creator", { 
      detail: { 
        position: this.getOptimalPosition(),
        availableTypes: this.getAvailableWidgetTypes()
      }
    })
  }

  async openMarketplace() {
    if (window.PluginMarketplace) {
      window.PluginMarketplace.open()
    } else {
      this.showStatusMessage("Plugin marketplace not available", "error")
    }
  }

  showQuickAdd() {
    // Show quick add menu at button position
    const button = this.quickAddButtonTarget
    const rect = button.getBoundingClientRect()
    
    this.dispatch("show-quick-add", {
      detail: {
        x: rect.left,
        y: rect.top,
        widgetTypes: this.getAvailableWidgetTypes()
      }
    })
  }

  getOptimalPosition() {
    // Find an optimal position for new widgets
    const containerRect = this.widgetContentTarget.getBoundingClientRect()
    const existingWidgets = Array.from(this.widgets.values())
    
    // Simple positioning algorithm - place widgets in a grid pattern
    const cols = Math.floor(containerRect.width / 320) // Assuming 300px widget width + 20px margin
    const row = Math.floor(existingWidgets.length / cols)
    const col = existingWidgets.length % cols
    
    return {
      x: col * 320 + 20,
      y: row * 240 + 20 // Assuming 200px widget height + 40px margin
    }
  }

  getAvailableWidgetTypes() {
    return [
      { type: "text", name: "Text Widget", icon: "📄" },
      { type: "notes", name: "Notes", icon: "📝" },
      { type: "todo", name: "Todo List", icon: "✅" },
      { type: "timer", name: "Timer", icon: "⏰" },
      { type: "ai-review", name: "AI Review", icon: "🤖" },
      { type: "console", name: "Console", icon: "💻" }
    ]
  }

  // === LAYOUT MANAGEMENT ===

  switchLayoutMode(event) {
    const newMode = event.currentTarget.dataset.layoutMode
    if (newMode === this.layoutModeValue) return

    this.layoutModeValue = newMode
    this.updateLayoutDisplay()
    
    // Update framework layout
    if (this.framework) {
      this.framework.toggleLayout()
    }
    
    this.showStatusMessage(`Switched to ${newMode} layout`, "info")
    
    // Save layout preference
    if (this.autoSaveValue) {
      this.saveLayoutPreference()
    }
  }

  updateLayoutDisplay() {
    if (this.hasCurrentLayoutTarget) {
      this.currentLayoutTarget.textContent = this.layoutModeValue
    }
    
    // Update layout switcher buttons
    this.layoutSwitcherTarget.querySelectorAll(".layout-button").forEach(btn => {
      const isActive = btn.dataset.layoutMode === this.layoutModeValue
      btn.classList.toggle("bg-blue-100", isActive)
      btn.classList.toggle("dark:bg-blue-900", isActive)
      btn.classList.toggle("text-blue-600", isActive)
      btn.classList.toggle("dark:text-blue-400", isActive)
    })
  }

  async saveLayout() {
    if (this.framework) {
      await this.framework.saveLayout()
    }
  }

  async saveLayoutPreference() {
    try {
      await fetch(`/documents/${this.documentIdValue}/layout_preference`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          layout_mode: this.layoutModeValue
        })
      })
    } catch (error) {
      console.error("Failed to save layout preference:", error)
    }
  }

  // === DRAG AND DROP ===

  handleDragOver(event) {
    event.preventDefault()
    
    if (this.enableDockingValue) {
      this.updateDockingZones(event)
    }
    
    if (this.enableSnapValue) {
      this.showSnapGrid()
    }
  }

  handleDrop(event) {
    event.preventDefault()
    
    this.hideDockingZones()
    this.hideSnapGrid()
    
    // Handle external drops (from marketplace, file system, etc.)
    const data = event.dataTransfer.getData("application/json")
    if (data) {
      try {
        const dropData = JSON.parse(data)
        this.handleExternalDrop(dropData, event)
      } catch (error) {
        console.error("Failed to parse drop data:", error)
      }
    }
  }

  async handleExternalDrop(data, event) {
    const rect = this.widgetContentTarget.getBoundingClientRect()
    const position = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    }
    
    switch (data.type) {
    case "plugin":
      await this.createPluginWidget(data.pluginId, position)
      break
    case "template":
      await this.createTemplateWidget(data.template, position)
      break
    case "file":
      await this.createFileWidget(data.file, position)
      break
    default:
      console.warn("Unknown drop type:", data.type)
    }
  }

  updateDockingZones(event) {
    if (!this.hasDockingZoneTargets) return
    
    const rect = this.widgetAreaTarget.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    const threshold = 100
    
    this.dockingZoneTargets.forEach(zone => {
      const zoneType = zone.dataset.zone
      let isActive = false
      
      switch (zoneType) {
      case "left":
        isActive = x < threshold
        break
      case "right":
        isActive = x > rect.width - threshold
        break
      case "top":
        isActive = y < threshold
        break
      case "bottom":
        isActive = y > rect.height - threshold
        break
      case "center":
        const centerX = rect.width / 2
        const centerY = rect.height / 2
        const distance = Math.sqrt(Math.pow(x - centerX, 2) + Math.pow(y - centerY, 2))
        isActive = distance < threshold
        break
      }
      
      zone.classList.toggle(...this.dockingZoneActiveClasses, isActive)
    })
  }

  hideDockingZones() {
    if (!this.hasDockingZoneTargets) return
    
    this.dockingZoneTargets.forEach(zone => {
      zone.classList.remove(...this.dockingZoneActiveClasses)
    })
  }

  // === GUIDELINES AND SNAPPING ===

  showSnapGrid() {
    if (this.hasSnapGridTarget && this.enableSnapValue) {
      this.snapGridTarget.classList.add(...this.snapGridVisibleClasses)
    }
  }

  hideSnapGrid() {
    if (this.hasSnapGridTarget) {
      this.snapGridTarget.classList.remove(...this.snapGridVisibleClasses)
    }
  }

  showGuidelines() {
    if (this.hasGuidelinesTarget && this.showGuidelinesValue) {
      this.guidelinesTarget.classList.add(...this.guidelinesVisibleClasses)
    }
  }

  hideGuidelines() {
    if (this.hasGuidelinesTarget) {
      this.guidelinesTarget.classList.remove(...this.guidelinesVisibleClasses)
    }
  }

  toggleSnap() {
    this.enableSnapValue = !this.enableSnapValue
    this.updateStatusBar()
    this.showStatusMessage(`Snap ${this.enableSnapValue ? "enabled" : "disabled"}`, "info")
  }

  toggleGuidelines() {
    this.showGuidelinesValue = !this.showGuidelinesValue
    this.updateStatusBar()
    
    if (this.showGuidelinesValue) {
      this.showGuidelines()
    } else {
      this.hideGuidelines()
    }
    
    this.showStatusMessage(`Guidelines ${this.showGuidelinesValue ? "enabled" : "disabled"}`, "info")
  }

  // === WIDGET EVENTS ===

  handleWidgetCreated(detail) {
    const { widget } = detail
    this.widgets.set(widget.id, widget)
    this.updateWidgetCount()
    this.hideEmptyState()
    
    // Trigger entrance animation
    this.animateWidgetEntrance(widget.element)
  }

  handleWidgetClosed(detail) {
    const { widget } = detail
    this.widgets.delete(widget.id)
    this.selectedWidgets.delete(widget.id)
    this.updateWidgetCount()
    
    if (this.widgets.size === 0) {
      this.showEmptyState()
    }
  }

  handleWidgetMoved(detail) {
    const { widget } = detail
    // Update internal tracking if needed
  }

  handleWidgetResized(detail) {
    const { widget } = detail
    // Update internal tracking if needed
  }

  handleDragStart() {
    this.isDragging = true
    document.body.classList.add("widget-dragging")
    
    if (this.showGuidelinesValue) {
      this.showGuidelines()
    }
    
    if (this.enableSnapValue) {
      this.showSnapGrid()
    }
  }

  handleDragMove(detail) {
    // Update guidelines based on widget position
    this.updateAlignmentGuidelines(detail.widget)
  }

  handleDragEnd() {
    this.isDragging = false
    document.body.classList.remove("widget-dragging")
    
    this.hideGuidelines()
    this.hideSnapGrid()
    this.hideDockingZones()
  }

  updateAlignmentGuidelines(widget) {
    if (!this.showGuidelinesValue) return
    
    const widgetRect = widget.element.getBoundingClientRect()
    const containerRect = this.widgetContentTarget.getBoundingClientRect()
    
    // Check for alignment with other widgets
    const otherWidgets = Array.from(this.widgets.values()).filter(w => w.id !== widget.id)
    
    let showVertical = false
    let showHorizontal = false
    let verticalPos = 0
    let horizontalPos = 0
    
    otherWidgets.forEach(otherWidget => {
      const otherRect = otherWidget.element.getBoundingClientRect()
      const threshold = 5
      
      // Vertical alignment
      const centerX = widgetRect.left + widgetRect.width / 2
      const otherCenterX = otherRect.left + otherRect.width / 2
      
      if (Math.abs(centerX - otherCenterX) < threshold) {
        showVertical = true
        verticalPos = otherCenterX - containerRect.left
      }
      
      // Horizontal alignment
      const centerY = widgetRect.top + widgetRect.height / 2
      const otherCenterY = otherRect.top + otherRect.height / 2
      
      if (Math.abs(centerY - otherCenterY) < threshold) {
        showHorizontal = true
        horizontalPos = otherCenterY - containerRect.top
      }
    })
    
    // Update guideline visibility and position
    if (this.hasVerticalGuidelineTarget) {
      this.verticalGuidelineTarget.style.display = showVertical ? "block" : "none"
      if (showVertical) {
        this.verticalGuidelineTarget.style.left = `${verticalPos}px`
      }
    }
    
    if (this.hasHorizontalGuidelineTarget) {
      this.horizontalGuidelineTarget.style.display = showHorizontal ? "block" : "none"
      if (showHorizontal) {
        this.horizontalGuidelineTarget.style.top = `${horizontalPos}px`
      }
    }
  }

  // === WIDGET SELECTION ===

  selectAllWidgets() {
    this.widgets.forEach((widget, id) => {
      this.selectedWidgets.add(id)
      widget.element.classList.add("selected")
    })
    
    this.showStatusMessage(`${this.selectedWidgets.size} widgets selected`, "info")
  }

  clearSelection() {
    this.selectedWidgets.forEach(id => {
      const widget = this.widgets.get(id)
      if (widget) {
        widget.element.classList.remove("selected")
      }
    })
    this.selectedWidgets.clear()
  }

  async deleteSelectedWidgets() {
    if (this.selectedWidgets.size === 0) return
    
    const count = this.selectedWidgets.size
    const confirmed = confirm(`Delete ${count} selected widget(s)?`)
    
    if (!confirmed) return
    
    // Delete widgets
    const deletePromises = Array.from(this.selectedWidgets).map(id => {
      const widget = this.widgets.get(id)
      return widget ? this.framework.closeWidget(widget) : Promise.resolve()
    })
    
    try {
      await Promise.all(deletePromises)
      this.clearSelection()
      this.showStatusMessage(`${count} widget(s) deleted`, "success")
    } catch (error) {
      console.error("Failed to delete widgets:", error)
      this.showStatusMessage("Failed to delete widgets", "error")
    }
  }

  // === UI STATE MANAGEMENT ===

  showEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove(...this.emptyStateHiddenClasses)
    }
  }

  hideEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add(...this.emptyStateHiddenClasses)
    }
  }

  updateWidgetCount() {
    const count = this.widgets.size
    
    if (this.hasWidgetCountTarget) {
      this.widgetCountTarget.textContent = count
    }
    
    // Update quick add button visibility
    if (this.hasQuickAddButtonTarget) {
      this.quickAddButtonTarget.style.display = count >= this.maxWidgetsValue ? "none" : "flex"
    }
  }

  showStatusBar() {
    if (this.hasStatusBarTarget) {
      this.statusBarTarget.classList.add(...this.statusBarVisibleClasses)
    }
  }

  hideStatusBar() {
    if (this.hasStatusBarTarget) {
      this.statusBarTarget.classList.remove(...this.statusBarVisibleClasses)
    }
  }

  updateStatusBar() {
    if (this.hasAutoSaveStatusTarget) {
      this.autoSaveStatusTarget.textContent = this.autoSaveValue ? "On" : "Off"
    }
    
    if (this.hasSnapStatusTarget) {
      this.snapStatusTarget.textContent = this.enableSnapValue ? "On" : "Off"
    }
  }

  showStatusMessage(message, type = "info") {
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = message
      this.statusMessageTarget.className = `status-message ${type}`
    }
    
    if (this.hasStatusIndicatorTarget) {
      const icon = type === "success" ? "✓" : type === "error" ? "✗" : "ℹ"
      this.statusIndicatorTarget.innerHTML = `<span class="mr-1">${icon}</span>${message}`
      this.statusIndicatorTarget.className = `status-indicator ${type}`
    }
    
    this.showStatusBar()
    
    // Auto-hide success messages
    if (type === "success") {
      setTimeout(() => this.hideStatusBar(), 3000)
    }
  }

  showShortcuts() {
    if (this.hasShortcutsHelpTarget) {
      this.shortcutsHelpTarget.classList.remove("opacity-0", "invisible")
    }
  }

  hideShortcuts() {
    if (this.hasShortcutsHelpTarget) {
      this.shortcutsHelpTarget.classList.add("opacity-0", "invisible")
    }
  }

  // === PERFORMANCE MONITORING ===

  initializePerformanceMonitoring() {
    // FPS monitoring
    this.animationFrame = requestAnimationFrame(this.updateFPS.bind(this))
    
    // Memory monitoring
    this.memoryInterval = setInterval(this.updateMemoryUsage.bind(this), 5000)
    
    // Show performance monitor
    if (this.hasPerformanceMonitorTarget) {
      this.performanceMonitorTarget.classList.add(...this.performanceMonitorVisibleClasses)
    }
  }

  updateFPS() {
    const now = performance.now()
    this.frameCount++
    
    if (now >= this.lastFrameTime + 1000) {
      const fps = Math.round((this.frameCount * 1000) / (now - this.lastFrameTime))
      
      if (this.hasFpsCounterTarget) {
        this.fpsCounterTarget.textContent = fps
        this.fpsCounterTarget.className = fps < 30 ? "text-red-500" : fps < 45 ? "text-yellow-500" : "text-green-500"
      }
      
      this.frameCount = 0
      this.lastFrameTime = now
    }
    
    this.animationFrame = requestAnimationFrame(this.updateFPS.bind(this))
  }

  updateMemoryUsage() {
    if (performance.memory && this.hasMemoryUsageTarget) {
      const usedMB = Math.round(performance.memory.usedJSHeapSize / 1048576)
      this.memoryUsageTarget.textContent = usedMB
      
      // Color code based on usage
      const limitMB = Math.round(performance.memory.jsHeapSizeLimit / 1048576)
      const percentage = (usedMB / limitMB) * 100
      
      this.memoryUsageTarget.className = 
        percentage > 80 ? "text-red-500" : 
        percentage > 60 ? "text-yellow-500" : 
        "text-green-500"
    }
  }

  // === ANIMATIONS ===

  animateWidgetEntrance(element) {
    element.style.opacity = "0"
    element.style.transform = "scale(0.8)"
    element.style.transition = "opacity 0.3s ease, transform 0.3s ease"
    
    requestAnimationFrame(() => {
      element.style.opacity = "1"
      element.style.transform = "scale(1)"
      
      setTimeout(() => {
        element.style.transition = ""
      }, 300)
    })
  }

  // === EVENT HANDLERS ===

  handleMouseDown(event) {
    // Handle container clicks for selection
    if (event.target === this.widgetContentTarget) {
      this.clearSelection()
    }
  }

  handleMouseMove(event) {
    // Update cursor position for snapping indicators
  }

  handleMouseUp(event) {
    // Handle end of drag operations
  }

  handleContextMenu(event) {
    event.preventDefault()
    
    // Show context menu
    this.dispatch("show-context-menu", {
      detail: {
        x: event.clientX,
        y: event.clientY,
        target: event.target
      }
    })
  }

  handleWindowResize() {
    // Recalculate widget positions if needed
    this.widgets.forEach(widget => {
      // Ensure widgets stay within bounds
      this.constrainWidgetToBounds(widget)
    })
  }

  handleVisibilityChange() {
    if (document.hidden) {
      // Pause performance monitoring when hidden
      if (this.animationFrame) {
        cancelAnimationFrame(this.animationFrame)
      }
    } else {
      // Resume monitoring when visible
      this.animationFrame = requestAnimationFrame(this.updateFPS.bind(this))
    }
  }

  constrainWidgetToBounds(widget) {
    const containerRect = this.widgetContentTarget.getBoundingClientRect()
    const widgetRect = widget.element.getBoundingClientRect()
    
    let newX = widget.position.x
    let newY = widget.position.y
    
    // Ensure widget doesn't go outside container
    if (newX < 0) newX = 0
    if (newY < 0) newY = 0
    if (newX + widgetRect.width > containerRect.width) {
      newX = containerRect.width - widgetRect.width
    }
    if (newY + widgetRect.height > containerRect.height) {
      newY = containerRect.height - widgetRect.height
    }
    
    if (newX !== widget.position.x || newY !== widget.position.y) {
      widget.position.x = newX
      widget.position.y = newY
      widget.element.style.left = `${newX}px`
      widget.element.style.top = `${newY}px`
    }
  }

  // === UTILITY METHODS ===

  isInputFocused() {
    const activeElement = document.activeElement
    return activeElement && (
      activeElement.tagName === "INPUT" ||
      activeElement.tagName === "TEXTAREA" ||
      activeElement.isContentEditable
    )
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }

  dispatch(eventName, detail = {}) {
    const event = new CustomEvent(`widget-container:${eventName}`, {
      detail: { ...detail, controller: this },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  cleanup() {
    // Cancel performance monitoring
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }
    
    if (this.memoryInterval) {
      clearInterval(this.memoryInterval)
    }
    
    // Cleanup framework
    if (this.framework) {
      // Framework handles its own cleanup
      this.framework = null
    }
    
    // Remove from global registry
    if (window.widgetFrameworks) {
      window.widgetFrameworks.delete(this.documentIdValue)
    }
  }
}