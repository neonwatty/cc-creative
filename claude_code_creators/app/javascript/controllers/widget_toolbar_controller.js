import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

// Connects to data-controller="widget-toolbar"
export default class extends Controller {
  static targets = [
    "toolbar", "content", "actionButton", "dropdownButton", "dropdownMenu",
    "collapseButton", "collapseIcon", "dragHandle", "hoverOverlay",
    "shortcutOverlay", "loadingOverlay", "loadingText", "contextMenu",
    "statusIndicator", "statusText", "widgetCount", "layoutIcon", "layoutMode",
    "marketplaceBadge", "updateCount", "labelsToggleText", "shortcutsToggleText"
  ]

  static values = {
    documentId: Number,
    userId: Number,
    position: { type: String, default: "top" },
    size: { type: String, default: "medium" },
    style: { type: String, default: "modern" },
    showLabels: { type: Boolean, default: true },
    showShortcuts: { type: Boolean, default: false },
    autoHide: { type: Boolean, default: false },
    collapsible: { type: Boolean, default: true }
  }

  static classes = [
    "collapsed", "loading", "active"
  ]

  connect() {
    // State management
    this.isCollapsed = false
    this.isDragging = false
    this.selectedWidgets = new Set()
    this.currentLayoutMode = "grid"
    this.zoomLevel = 1
    this.openDropdown = null
    
    // Drag state for floating toolbar
    this.dragStartPos = null
    this.toolbarStartPos = null
    
    // Connect to widget framework
    this.connectToWidgetFramework()
    
    // Setup event listeners
    this.setupEventListeners()
    this.setupKeyboardShortcuts()
    
    // Initialize UI state
    this.updateUI()
    this.updateStatus("Ready")
    
    // Setup auto-hide behavior
    if (this.autoHideValue) {
      this.setupAutoHide()
    }
    
    // Setup floating behavior
    if (this.positionValue === "floating") {
      this.setupFloatingBehavior()
    }
  }

  disconnect() {
    this.cleanup()
  }

  // === INITIALIZATION ===

  connectToWidgetFramework() {
    // Connect to widget framework if available
    if (window.widgetFrameworks) {
      const frameworks = Array.from(window.widgetFrameworks.values())
      if (frameworks.length > 0) {
        this.widgetFramework = frameworks[0]
        this.setupFrameworkEvents()
      }
    }
    
    // Also check for global plugin marketplace
    if (window.PluginMarketplace) {
      this.pluginMarketplace = window.PluginMarketplace
    }
  }

  setupFrameworkEvents() {
    if (!this.widgetFramework) return
    
    this.widgetFramework.on("widget:created", () => {
      this.updateWidgetCount()
      this.updateStatus("Widget created", "success")
    })
    
    this.widgetFramework.on("widget:closed", () => {
      this.updateWidgetCount()
      this.updateStatus("Widget closed", "info")
    })
    
    this.widgetFramework.on("widget:focused", () => {
      this.updateSelectedWidgets()
    })
    
    this.widgetFramework.on("layout:changed", (event) => {
      this.updateLayoutMode(event.detail.layout)
    })
    
    this.widgetFramework.on("layout:saved", () => {
      this.updateStatus("Layout saved", "success")
    })
  }

  setupEventListeners() {
    // Global click handler for dropdowns
    document.addEventListener("click", this.handleGlobalClick.bind(this))
    
    // Context menu
    this.element.addEventListener("contextmenu", this.handleContextMenu.bind(this))
    
    // Widget selection events
    document.addEventListener("widget:selected", this.handleWidgetSelected.bind(this))
    document.addEventListener("widget:deselected", this.handleWidgetDeselected.bind(this))
    
    // Marketplace events
    document.addEventListener("plugin-marketplace:plugin-installed", this.handleMarketplaceUpdate.bind(this))
    document.addEventListener("plugin-marketplace:updates-available", this.handleMarketplaceUpdate.bind(this))
  }

  setupKeyboardShortcuts() {
    document.addEventListener("keydown", (event) => {
      // Only handle shortcuts when no input is focused
      if (this.isInputFocused()) return
      
      const { metaKey, ctrlKey, key, shiftKey } = event
      const cmdKey = metaKey || ctrlKey
      
      // Find action by shortcut
      const shortcut = this.formatShortcut(event)
      const action = this.findActionByShortcut(shortcut)
      
      if (action) {
        event.preventDefault()
        this.executeAction(action.id)
        return
      }
      
      // Special shortcuts
      switch (key) {
      case "?":
        if (!cmdKey) {
          event.preventDefault()
          this.showShortcuts()
        }
        break
      case "Escape":
        this.hideAllDropdowns()
        this.hideShortcuts()
        break
      }
    })
  }

  setupAutoHide() {
    let hideTimeout
    
    const showToolbar = () => {
      clearTimeout(hideTimeout)
      this.element.classList.remove("opacity-30")
      this.element.classList.add("opacity-100")
    }
    
    const hideToolbar = () => {
      hideTimeout = setTimeout(() => {
        this.element.classList.remove("opacity-100")
        this.element.classList.add("opacity-30")
      }, 2000)
    }
    
    this.element.addEventListener("mouseenter", showToolbar)
    this.element.addEventListener("mouseleave", hideToolbar)
    this.element.addEventListener("focusin", showToolbar)
    this.element.addEventListener("focusout", hideToolbar)
    
    // Start hidden
    hideToolbar()
  }

  setupFloatingBehavior() {
    // Load saved position
    const savedPos = this.loadFloatingPosition()
    if (savedPos) {
      this.element.style.left = `${savedPos.x}px`
      this.element.style.top = `${savedPos.y}px`
    }
  }

  // === ACTION HANDLERS ===

  showAddWidget() {
    this.showLoading("Opening widget creator...")
    
    // Dispatch event to show widget creation wizard
    this.dispatch("show-widget-creator", {
      detail: {
        availableTypes: this.getAvailableWidgetTypes()
      }
    })
    
    this.hideLoading()
  }

  openMarketplace() {
    if (this.pluginMarketplace) {
      this.pluginMarketplace.open()
      this.updateStatus("Marketplace opened", "info")
    } else {
      this.updateStatus("Marketplace not available", "error")
    }
  }

  toggleLayout() {
    // Cycle through layout modes
    const modes = ["grid", "column", "row"]
    const currentIndex = modes.indexOf(this.currentLayoutMode)
    const nextMode = modes[(currentIndex + 1) % modes.length]
    
    this.setLayoutMode(null, nextMode)
  }

  setLayoutMode(event, mode = null) {
    const targetMode = mode || event?.currentTarget?.dataset?.mode
    if (!targetMode || targetMode === this.currentLayoutMode) return
    
    this.currentLayoutMode = targetMode
    
    if (this.widgetFramework) {
      this.widgetFramework.setLayoutMode(targetMode)
    }
    
    this.updateLayoutMode(targetMode)
    this.updateStatus(`Layout: ${targetMode}`, "info")
    this.hideAllDropdowns()
  }

  selectAllWidgets() {
    if (this.widgetFramework) {
      const widgets = Array.from(this.widgetFramework.widgets.values())
      widgets.forEach(widget => {
        this.selectedWidgets.add(widget.id)
        widget.element.classList.add("selected")
      })
      
      this.updateSelectedWidgets()
      this.updateStatus(`${widgets.length} widgets selected`, "info")
    }
  }

  duplicateSelected() {
    if (this.selectedWidgets.size === 0) return
    
    this.showLoading("Duplicating widgets...")
    
    const promises = Array.from(this.selectedWidgets).map(async (widgetId) => {
      const widget = this.widgetFramework?.widgets.get(widgetId)
      if (!widget) return
      
      try {
        await this.widgetFramework.createWidget(widget.type, {
          title: `${widget.title} (Copy)`,
          content: widget.content,
          settings: { ...widget.settings },
          position: {
            x: widget.position.x + 20,
            y: widget.position.y + 20
          }
        })
      } catch (error) {
        console.error("Failed to duplicate widget:", error)
      }
    })
    
    Promise.all(promises).then(() => {
      this.hideLoading()
      this.updateStatus(`${this.selectedWidgets.size} widgets duplicated`, "success")
    }).catch((error) => {
      this.hideLoading()
      this.updateStatus("Failed to duplicate widgets", "error")
    })
  }

  async deleteSelected() {
    if (this.selectedWidgets.size === 0) return
    
    const count = this.selectedWidgets.size
    const confirmed = confirm(`Delete ${count} selected widget(s)?`)
    
    if (!confirmed) return
    
    this.showLoading("Deleting widgets...")
    
    try {
      const promises = Array.from(this.selectedWidgets).map(async (widgetId) => {
        const widget = this.widgetFramework?.widgets.get(widgetId)
        if (widget) {
          await this.widgetFramework.closeWidget(widget)
        }
      })
      
      await Promise.all(promises)
      this.selectedWidgets.clear()
      this.updateSelectedWidgets()
      this.updateStatus(`${count} widgets deleted`, "success")
    } catch (error) {
      console.error("Failed to delete widgets:", error)
      this.updateStatus("Failed to delete widgets", "error")
    } finally {
      this.hideLoading()
    }
  }

  zoomIn() {
    this.zoomLevel = Math.min(this.zoomLevel * 1.2, 3)
    this.applyZoom()
    this.updateStatus(`Zoom: ${Math.round(this.zoomLevel * 100)}%`, "info")
  }

  zoomOut() {
    this.zoomLevel = Math.max(this.zoomLevel / 1.2, 0.25)
    this.applyZoom()
    this.updateStatus(`Zoom: ${Math.round(this.zoomLevel * 100)}%`, "info")
  }

  fitToScreen() {
    if (!this.widgetFramework) return
    
    // Calculate optimal zoom to fit all widgets
    const widgets = Array.from(this.widgetFramework.widgets.values())
    if (widgets.length === 0) return
    
    // Implementation would calculate bounds and optimal zoom
    this.zoomLevel = 1
    this.applyZoom()
    this.updateStatus("Fit to screen", "info")
  }

  showPreferences() {
    this.dispatch("show-preferences", {
      detail: {
        currentSettings: {
          position: this.positionValue,
          size: this.sizeValue,
          style: this.styleValue,
          showLabels: this.showLabelsValue,
          showShortcuts: this.showShortcutsValue,
          autoHide: this.autoHideValue
        }
      }
    })
  }

  async saveLayout() {
    if (!this.widgetFramework) return
    
    this.showLoading("Saving layout...")
    
    try {
      await this.widgetFramework.saveLayout()
      this.updateStatus("Layout saved", "success")
    } catch (error) {
      console.error("Failed to save layout:", error)
      this.updateStatus("Failed to save layout", "error")
    } finally {
      this.hideLoading()
    }
  }

  async resetLayout() {
    if (!this.widgetFramework) return
    
    const confirmed = confirm("Reset layout to default? This will remove all current widgets.")
    if (!confirmed) return
    
    this.showLoading("Resetting layout...")
    
    try {
      await this.widgetFramework.resetLayout()
      this.selectedWidgets.clear()
      this.updateSelectedWidgets()
      this.updateStatus("Layout reset", "info")
    } catch (error) {
      console.error("Failed to reset layout:", error)
      this.updateStatus("Failed to reset layout", "error")
    } finally {
      this.hideLoading()
    }
  }

  // === DROPDOWN MANAGEMENT ===

  handleDropdownClick(event) {
    const dropdownId = event.currentTarget.dataset.dropdownId
    this.toggleDropdown(dropdownId)
  }

  toggleDropdown(dropdownId) {
    const dropdown = this.dropdownMenuTargets.find(
      menu => menu.dataset.dropdownId === dropdownId
    )
    
    if (!dropdown) return
    
    const isOpen = dropdown.classList.contains(...this.dropdownVisibleClasses)
    
    // Close all dropdowns first
    this.hideAllDropdowns()
    
    if (!isOpen) {
      // Open this dropdown
      dropdown.classList.add(...this.dropdownVisibleClasses)
      this.openDropdown = dropdownId
      
      // Update button state
      const button = this.dropdownButtonTargets.find(
        btn => btn.dataset.dropdownId === dropdownId
      )
      if (button) {
        button.setAttribute("aria-expanded", "true")
      }
    }
  }

  hideAllDropdowns() {
    this.dropdownMenuTargets.forEach(menu => {
      menu.classList.remove(...this.dropdownVisibleClasses)
    })
    
    this.dropdownButtonTargets.forEach(button => {
      button.setAttribute("aria-expanded", "false")
    })
    
    this.openDropdown = null
  }

  handleGlobalClick(event) {
    // Close dropdowns when clicking outside
    if (!this.element.contains(event.target)) {
      this.hideAllDropdowns()
    }
  }

  // === COLLAPSE/EXPAND ===

  toggleCollapse() {
    this.isCollapsed = !this.isCollapsed
    
    if (this.isCollapsed) {
      this.contentTarget.classList.add(...this.collapsedClasses)
    } else {
      this.contentTarget.classList.remove(...this.collapsedClasses)
    }
    
    // Update collapse icon
    if (this.hasCollapseIconTarget) {
      const rotation = this.isCollapsed ? "rotate-180" : ""
      this.collapseIconTarget.classList.toggle("rotate-180", this.isCollapsed)
    }
    
    // Save preference
    this.saveToolbarPreference("collapsed", this.isCollapsed)
  }

  // === DRAG AND DROP (for floating toolbar) ===

  startDrag(event) {
    if (this.positionValue !== "floating") return
    
    this.isDragging = true
    this.dragStartPos = { x: event.clientX, y: event.clientY }
    
    const rect = this.element.getBoundingClientRect()
    this.toolbarStartPos = { x: rect.left, y: rect.top }
    
    document.addEventListener("mousemove", this.handleDragMove.bind(this))
    document.addEventListener("mouseup", this.handleDragEnd.bind(this))
    
    event.preventDefault()
  }

  handleDragMove(event) {
    if (!this.isDragging) return
    
    const deltaX = event.clientX - this.dragStartPos.x
    const deltaY = event.clientY - this.dragStartPos.y
    
    const newX = this.toolbarStartPos.x + deltaX
    const newY = this.toolbarStartPos.y + deltaY
    
    // Constrain to viewport
    const rect = this.element.getBoundingClientRect()
    const constrainedX = Math.max(0, Math.min(newX, window.innerWidth - rect.width))
    const constrainedY = Math.max(0, Math.min(newY, window.innerHeight - rect.height))
    
    this.element.style.left = `${constrainedX}px`
    this.element.style.top = `${constrainedY}px`
    this.element.style.transform = "none"
  }

  handleDragEnd() {
    if (!this.isDragging) return
    
    this.isDragging = false
    document.removeEventListener("mousemove", this.handleDragMove.bind(this))
    document.removeEventListener("mouseup", this.handleDragEnd.bind(this))
    
    // Save position
    this.saveFloatingPosition()
  }

  // === CONTEXT MENU ===

  handleContextMenu(event) {
    event.preventDefault()
    
    if (this.hasContextMenuTarget) {
      this.showContextMenu(event.clientX, event.clientY)
    }
  }

  showContextMenu(x, y) {
    const menu = this.contextMenuTarget
    menu.style.left = `${x}px`
    menu.style.top = `${y}px`
    menu.classList.remove("opacity-0", "invisible")
    
    // Hide on next click
    setTimeout(() => {
      document.addEventListener("click", () => {
        menu.classList.add("opacity-0", "invisible")
      }, { once: true })
    }, 100)
  }

  // === SETTINGS ===

  toggleLabels() {
    this.showLabelsValue = !this.showLabelsValue
    this.updateLabelsDisplay()
    this.saveToolbarPreference("showLabels", this.showLabelsValue)
    
    if (this.hasLabelsToggleTextTarget) {
      this.labelsToggleTextTarget.textContent = this.showLabelsValue ? "Hide Labels" : "Show Labels"
    }
  }

  toggleShortcuts() {
    this.showShortcutsValue = !this.showShortcutsValue
    this.updateShortcutsDisplay()
    this.saveToolbarPreference("showShortcuts", this.showShortcutsValue)
    
    if (this.hasShortcutsToggleTextTarget) {
      this.shortcutsToggleTextTarget.textContent = this.showShortcutsValue ? "Hide Shortcuts" : "Show Shortcuts"
    }
  }

  changePosition(event) {
    const newPosition = event.currentTarget.dataset.position
    this.positionValue = newPosition
    
    // This would require re-rendering the component with new position
    this.dispatch("change-position", { detail: { position: newPosition } })
    this.saveToolbarPreference("position", newPosition)
  }

  resetToDefaults() {
    const confirmed = confirm("Reset toolbar to default settings?")
    if (!confirmed) return
    
    // Reset all preferences
    this.clearToolbarPreferences()
    
    // Reset values
    this.showLabelsValue = true
    this.showShortcutsValue = false
    this.isCollapsed = false
    
    // Update UI
    this.updateUI()
    this.updateStatus("Toolbar reset to defaults", "info")
  }

  // === UI UPDATES ===

  updateUI() {
    this.updateWidgetCount()
    this.updateSelectedWidgets()
    this.updateLayoutMode(this.currentLayoutMode)
    this.updateLabelsDisplay()
    this.updateShortcutsDisplay()
  }

  updateWidgetCount() {
    if (this.hasWidgetCountTarget && this.widgetFramework) {
      this.widgetCountTarget.textContent = this.widgetFramework.widgets.size
    }
  }

  updateSelectedWidgets() {
    // Update button states based on selection
    this.actionButtonTargets.forEach(button => {
      const actionId = button.dataset.actionId
      
      if (this.isSelectionAction(actionId)) {
        button.disabled = this.selectedWidgets.size === 0
        button.classList.toggle("opacity-50", this.selectedWidgets.size === 0)
      }
    })
  }

  updateLayoutMode(mode) {
    this.currentLayoutMode = mode
    
    if (this.hasLayoutModeTarget) {
      this.layoutModeTarget.textContent = mode.charAt(0).toUpperCase() + mode.slice(1)
    }
    
    if (this.hasLayoutIconTarget) {
      // Update icon based on layout mode
      const iconSvg = this.getLayoutIcon(mode)
      this.layoutIconTarget.innerHTML = iconSvg
    }
  }

  updateLabelsDisplay() {
    // This would require component re-render in a real implementation
    // For now, we can hide/show existing labels
    const labels = this.element.querySelectorAll(".toolbar-btn span:not(.badge)")
    labels.forEach(label => {
      label.style.display = this.showLabelsValue ? "inline" : "none"
    })
  }

  updateShortcutsDisplay() {
    // Update tooltip display with/without shortcuts
    const tooltips = this.element.querySelectorAll(".tooltip")
    tooltips.forEach(tooltip => {
      const shortcutSpan = tooltip.querySelector(".text-gray-400")
      if (shortcutSpan) {
        shortcutSpan.style.display = this.showShortcutsValue ? "inline" : "none"
      }
    })
  }

  updateStatus(message, type = "info") {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = message
    }
    
    if (this.hasStatusIndicatorTarget) {
      const colors = {
        success: "bg-green-500",
        error: "bg-red-500",
        warning: "bg-yellow-500",
        info: "bg-blue-500"
      }
      
      // Reset classes
      Object.values(colors).forEach(color => {
        this.statusIndicatorTarget.classList.remove(color)
      })
      
      // Add new color
      this.statusIndicatorTarget.classList.add(colors[type] || colors.info)
    }
    
    // Auto-clear success messages
    if (type === "success") {
      setTimeout(() => {
        this.updateStatus("Ready")
      }, 3000)
    }
  }

  // === LOADING ===

  showLoading(message = "Loading...") {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove("opacity-0", "invisible")
    }
    
    if (this.hasLoadingTextTarget) {
      this.loadingTextTarget.textContent = message
    }
  }

  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add("opacity-0", "invisible")
    }
  }

  // === SHORTCUTS ===

  showShortcuts() {
    if (this.hasShortcutOverlayTarget) {
      this.shortcutOverlayTarget.classList.remove("opacity-0", "invisible")
    }
  }

  hideShortcuts() {
    if (this.hasShortcutOverlayTarget) {
      this.shortcutOverlayTarget.classList.add("opacity-0", "invisible")
    }
  }

  // === EVENT HANDLERS ===

  handleMouseLeave() {
    // Hide all dropdowns when mouse leaves toolbar
    this.hideAllDropdowns()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.hideAllDropdowns()
      this.hideShortcuts()
    }
  }

  handleWidgetSelected(event) {
    const widgetId = event.detail.widgetId
    this.selectedWidgets.add(widgetId)
    this.updateSelectedWidgets()
  }

  handleWidgetDeselected(event) {
    const widgetId = event.detail.widgetId
    this.selectedWidgets.delete(widgetId)
    this.updateSelectedWidgets()
  }

  handleMarketplaceUpdate(event) {
    if (this.hasMarketplaceBadgeTarget) {
      const count = event.detail.updateCount || 0
      if (count > 0) {
        this.marketplaceBadgeTarget.style.display = "flex"
        if (this.hasUpdateCountTarget) {
          this.updateCountTarget.textContent = count
        }
      } else {
        this.marketplaceBadgeTarget.style.display = "none"
      }
    }
  }

  // === UTILITY METHODS ===

  applyZoom() {
    if (this.widgetFramework && this.widgetFramework.layoutContainer) {
      this.widgetFramework.layoutContainer.style.transform = `scale(${this.zoomLevel})`
      this.widgetFramework.layoutContainer.style.transformOrigin = "top left"
    }
  }

  executeAction(actionId) {
    const actionMap = {
      "add": () => this.showAddWidget(),
      "marketplace": () => this.openMarketplace(),
      "layout": () => this.toggleLayout(),
      "select-all": () => this.selectAllWidgets(),
      "duplicate": () => this.duplicateSelected(),
      "delete": () => this.deleteSelected(),
      "zoom-in": () => this.zoomIn(),
      "zoom-out": () => this.zoomOut(),
      "fit-to-screen": () => this.fitToScreen(),
      "preferences": () => this.showPreferences(),
      "save": () => this.saveLayout(),
      "reset": () => this.resetLayout()
    }
    
    const action = actionMap[actionId]
    if (action) {
      action()
    }
  }

  findActionByShortcut(shortcut) {
    // This would search through all actions to find matching shortcut
    // Implementation depends on how actions are structured
    return null
  }

  formatShortcut(event) {
    const parts = []
    if (event.metaKey || event.ctrlKey) parts.push("⌘")
    if (event.shiftKey) parts.push("⇧")
    if (event.altKey) parts.push("⌥")
    parts.push(event.key.toUpperCase())
    return parts.join("")
  }

  isSelectionAction(actionId) {
    return ["duplicate", "delete"].includes(actionId)
  }

  isInputFocused() {
    const activeElement = document.activeElement
    return activeElement && (
      activeElement.tagName === "INPUT" ||
      activeElement.tagName === "TEXTAREA" ||
      activeElement.isContentEditable
    )
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

  getLayoutIcon(mode) {
    const icons = {
      grid: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>',
      column: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 4v16M15 4v16M4 6h16M4 10h16M4 14h16M4 18h16"/>',
      row: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>'
    }
    return icons[mode] || icons.grid
  }

  // === PERSISTENCE ===

  saveToolbarPreference(key, value) {
    const preferences = this.loadToolbarPreferences()
    preferences[key] = value
    localStorage.setItem(`widget-toolbar-${this.documentIdValue}`, JSON.stringify(preferences))
  }

  loadToolbarPreferences() {
    try {
      const saved = localStorage.getItem(`widget-toolbar-${this.documentIdValue}`)
      return saved ? JSON.parse(saved) : {}
    } catch (error) {
      console.error("Failed to load toolbar preferences:", error)
      return {}
    }
  }

  clearToolbarPreferences() {
    localStorage.removeItem(`widget-toolbar-${this.documentIdValue}`)
  }

  saveFloatingPosition() {
    if (this.positionValue !== "floating") return
    
    const rect = this.element.getBoundingClientRect()
    const position = { x: rect.left, y: rect.top }
    
    this.saveToolbarPreference("floatingPosition", position)
  }

  loadFloatingPosition() {
    const preferences = this.loadToolbarPreferences()
    return preferences.floatingPosition
  }

  // === EVENTS ===

  dispatch(eventName, detail = {}) {
    const event = new CustomEvent(`widget-toolbar:${eventName}`, {
      detail: { ...detail, controller: this },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  cleanup() {
    // Remove event listeners
    document.removeEventListener("click", this.handleGlobalClick.bind(this))
    document.removeEventListener("mousemove", this.handleDragMove.bind(this))
    document.removeEventListener("mouseup", this.handleDragEnd.bind(this))
  }
}