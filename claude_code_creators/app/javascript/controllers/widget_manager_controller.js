import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"
import { WidgetFramework } from "../services/widget_framework"

// Connects to data-controller="widget-manager"
export default class extends Controller {
  static targets = [
    "container", "toolbar", "status", "widgetArea",
    "widgetList", "addButton", "removeButton", "reorderButton",
    "widgetTemplate", "emptyState", "widgetCount", "searchInput"
  ]
  
  static values = {
    documentId: Number,
    userId: Number,
    widgetsUrl: String,
    maxWidgets: { type: Number, default: 20 },
    enableSearch: { type: Boolean, default: true },
    enableReorder: { type: Boolean, default: true },
    autoSave: { type: Boolean, default: true },
    enableDragDrop: { type: Boolean, default: true }
  }

  static classes = [
    "widget", "widgetSelected", "widgetHidden", "widgetAdding",
    "emptyStateVisible", "buttonDisabled"
  ]

  connect() {
    this.widgets = new Map()
    this.selectedWidgets = new Set()
    this.isReordering = false
    
    // Bind search function with debounce
    this.debouncedSearch = debounce(300, this.performSearch.bind(this))
    
    // Initialize widget framework if container target exists
    if (this.hasContainerTarget) {
      this.initializeFramework()
    } else {
      // Fall back to legacy widget management
      this.loadWidgets()
    }
    
    this.updateWidgetCount()
    this.setupEventListeners()
    this.setupWidgetTypes()
    this.bindGlobalEvents()
  }

  disconnect() {
    // Clean up any intervals or listeners
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }

  // Load existing widgets
  async loadWidgets() {
    try {
      const response = await fetch(this.widgetsUrlValue)
      if (response.ok) {
        const data = await response.json()
        this.populateWidgets(data.widgets || [])
      } else {
        console.error("Failed to load widgets")
        this.showEmptyState()
      }
    } catch (error) {
      console.error("Error loading widgets:", error)
      this.showEmptyState()
    }
  }

  // Populate widgets in the UI
  populateWidgets(widgetData) {
    this.widgets.clear()
    
    if (!widgetData.length) {
      this.showEmptyState()
      return
    }

    this.hideEmptyState()
    
    widgetData.forEach(widget => {
      this.widgets.set(widget.id, widget)
      this.addWidgetToDOM(widget)
    })
    
    this.updateWidgetCount()
  }

  // Add widget to DOM
  addWidgetToDOM(widget) {
    if (!this.hasWidgetTemplateTarget) return
    
    const template = this.widgetTemplateTarget
    const widgetElement = template.content.cloneNode(true).firstElementChild
    
    // Populate widget data
    widgetElement.dataset.widgetId = widget.id
    widgetElement.dataset.widgetType = widget.type
    
    const titleElement = widgetElement.querySelector("[data-widget-title]")
    if (titleElement) titleElement.textContent = widget.title
    
    const contentElement = widgetElement.querySelector("[data-widget-content]")
    if (contentElement) contentElement.innerHTML = widget.content
    
    const typeElement = widgetElement.querySelector("[data-widget-type]")
    if (typeElement) typeElement.textContent = widget.type
    
    // Add event listeners
    this.setupWidgetEventListeners(widgetElement)
    
    // Add to list with animation
    widgetElement.classList.add(this.widgetAddingClass)
    this.widgetListTarget.appendChild(widgetElement)
    
    // Trigger animation
    requestAnimationFrame(() => {
      widgetElement.classList.remove(this.widgetAddingClass)
    })
  }

  // Setup event listeners for individual widgets
  setupWidgetEventListeners(widgetElement) {
    // Widget selection
    widgetElement.addEventListener("click", (event) => {
      if (!event.target.closest("[data-widget-action]")) {
        this.toggleWidgetSelection(widgetElement)
      }
    })
    
    // Widget actions
    const actionButtons = widgetElement.querySelectorAll("[data-widget-action]")
    actionButtons.forEach(button => {
      button.addEventListener("click", (event) => {
        event.stopPropagation()
        const action = button.dataset.widgetAction
        const widgetId = widgetElement.dataset.widgetId
        this.performWidgetAction(action, widgetId, widgetElement)
      })
    })
  }

  // Setup global event listeners
  setupEventListeners() {
    // Add button
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.addEventListener("click", this.showAddWidgetModal.bind(this))
    }
    
    // Remove button
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.addEventListener("click", this.removeSelectedWidgets.bind(this))
    }
    
    // Reorder button
    if (this.hasReorderButtonTarget && this.enableReorderValue) {
      this.reorderButtonTarget.addEventListener("click", this.toggleReorderMode.bind(this))
    }
    
    // Search input
    if (this.hasSearchInputTarget && this.enableSearchValue) {
      this.searchInputTarget.addEventListener("input", (event) => {
        this.debouncedSearch(event.target.value)
      })
    }
    
    // Keyboard shortcuts
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    // Only handle if focus is within this controller
    if (!this.element.contains(document.activeElement)) return
    
    switch (event.key) {
    case "Delete":
    case "Backspace":
      if (this.selectedWidgets.size > 0) {
        event.preventDefault()
        this.removeSelectedWidgets()
      }
      break
    case "a":
      if (event.metaKey || event.ctrlKey) {
        event.preventDefault()
        this.selectAllWidgets()
      }
      break
    case "Escape":
      this.clearSelection()
      break
    }
  }

  // Toggle widget selection
  toggleWidgetSelection(widgetElement) {
    const widgetId = widgetElement.dataset.widgetId
    
    if (this.selectedWidgets.has(widgetId)) {
      this.selectedWidgets.delete(widgetId)
      widgetElement.classList.remove(this.widgetSelectedClass)
    } else {
      this.selectedWidgets.add(widgetId)
      widgetElement.classList.add(this.widgetSelectedClass)
    }
    
    this.updateSelectionUI()
  }

  // Select all widgets
  selectAllWidgets() {
    const widgetElements = this.widgetListTarget.querySelectorAll("[data-widget-id]")
    
    widgetElements.forEach(widget => {
      const widgetId = widget.dataset.widgetId
      this.selectedWidgets.add(widgetId)
      widget.classList.add(this.widgetSelectedClass)
    })
    
    this.updateSelectionUI()
  }

  // Clear selection
  clearSelection() {
    this.selectedWidgets.clear()
    
    const selectedElements = this.widgetListTarget.querySelectorAll(`.${this.widgetSelectedClass}`)
    selectedElements.forEach(element => {
      element.classList.remove(this.widgetSelectedClass)
    })
    
    this.updateSelectionUI()
  }

  // Update selection-dependent UI
  updateSelectionUI() {
    const hasSelection = this.selectedWidgets.size > 0
    
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.disabled = !hasSelection
      this.removeButtonTarget.classList.toggle(this.buttonDisabledClass, !hasSelection)
    }
  }

  // Perform widget action
  async performWidgetAction(action, widgetId, widgetElement) {
    switch (action) {
    case "edit":
      this.editWidget(widgetId)
      break
    case "delete":
      this.removeWidget(widgetId, widgetElement)
      break
    case "duplicate":
      this.duplicateWidget(widgetId)
      break
    case "toggle":
      this.toggleWidgetVisibility(widgetId, widgetElement)
      break
    }
  }

  // Add new widget
  async addWidget(widgetData) {
    if (this.widgets.size >= this.maxWidgetsValue) {
      this.showMessage(`Cannot add more than ${this.maxWidgetsValue} widgets`, "error")
      return
    }
    
    try {
      const response = await fetch(this.widgetsUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({ widget: widgetData })
      })
      
      if (response.ok) {
        const data = await response.json()
        this.widgets.set(data.id, data)
        this.addWidgetToDOM(data)
        this.hideEmptyState()
        this.updateWidgetCount()
        this.showMessage("Widget added successfully!", "success")
      } else {
        throw new Error("Failed to create widget")
      }
    } catch (error) {
      console.error("Error adding widget:", error)
      this.showMessage("Failed to add widget", "error")
    }
  }

  // Remove widget
  async removeWidget(widgetId, widgetElement) {
    if (!confirm("Are you sure you want to delete this widget?")) return
    
    try {
      const response = await fetch(`${this.widgetsUrlValue}/${widgetId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        }
      })
      
      if (response.ok) {
        this.widgets.delete(widgetId)
        this.selectedWidgets.delete(widgetId)
        
        // Animate removal
        widgetElement.style.transition = "transform 0.3s ease, opacity 0.3s ease"
        widgetElement.style.transform = "translateX(-100%)"
        widgetElement.style.opacity = "0"
        
        setTimeout(() => {
          widgetElement.remove()
          this.updateWidgetCount()
          this.updateSelectionUI()
          
          if (this.widgets.size === 0) {
            this.showEmptyState()
          }
        }, 300)
        
        this.showMessage("Widget removed successfully!", "success")
      } else {
        throw new Error("Failed to delete widget")
      }
    } catch (error) {
      console.error("Error removing widget:", error)
      this.showMessage("Failed to remove widget", "error")
    }
  }

  // Remove selected widgets
  async removeSelectedWidgets() {
    if (this.selectedWidgets.size === 0) return
    
    const count = this.selectedWidgets.size
    if (!confirm(`Are you sure you want to delete ${count} widget(s)?`)) return
    
    const widgetIds = Array.from(this.selectedWidgets)
    
    try {
      const response = await fetch(`${this.widgetsUrlValue}/bulk_delete`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({ widget_ids: widgetIds })
      })
      
      if (response.ok) {
        // Remove from data structures
        widgetIds.forEach(id => {
          this.widgets.delete(id)
          this.selectedWidgets.delete(id)
        })
        
        // Remove from DOM with staggered animation
        const widgetElements = widgetIds.map(id => 
          this.widgetListTarget.querySelector(`[data-widget-id="${id}"]`)
        ).filter(Boolean)
        
        widgetElements.forEach((element, index) => {
          setTimeout(() => {
            element.style.transition = "transform 0.3s ease, opacity 0.3s ease"
            element.style.transform = "translateX(-100%)"
            element.style.opacity = "0"
            
            setTimeout(() => {
              element.remove()
              if (index === widgetElements.length - 1) {
                this.updateWidgetCount()
                this.updateSelectionUI()
                
                if (this.widgets.size === 0) {
                  this.showEmptyState()
                }
              }
            }, 300)
          }, index * 100)
        })
        
        this.showMessage(`${count} widget(s) removed successfully!`, "success")
      } else {
        throw new Error("Failed to delete widgets")
      }
    } catch (error) {
      console.error("Error removing widgets:", error)
      this.showMessage("Failed to remove widgets", "error")
    }
  }

  // Duplicate widget
  async duplicateWidget(widgetId) {
    const original = this.widgets.get(widgetId)
    if (!original) return
    
    const duplicateData = {
      ...original,
      title: `${original.title} (Copy)`,
      id: undefined // Let server assign new ID
    }
    
    await this.addWidget(duplicateData)
  }

  // Toggle widget visibility
  toggleWidgetVisibility(widgetId, widgetElement) {
    const isHidden = widgetElement.classList.contains(this.widgetHiddenClass)
    
    if (isHidden) {
      widgetElement.classList.remove(this.widgetHiddenClass)
    } else {
      widgetElement.classList.add(this.widgetHiddenClass)
    }
    
    // Update widget data
    const widget = this.widgets.get(widgetId)
    if (widget) {
      widget.hidden = !isHidden
      if (this.autoSaveValue) {
        this.saveWidgetState(widgetId, { hidden: widget.hidden })
      }
    }
  }

  // Search widgets
  performSearch(query) {
    const widgetElements = this.widgetListTarget.querySelectorAll("[data-widget-id]")
    
    if (!query.trim()) {
      // Show all widgets
      widgetElements.forEach(element => {
        element.classList.remove(this.widgetHiddenClass)
      })
      return
    }
    
    const searchTerms = query.toLowerCase().split(" ")
    
    widgetElements.forEach(element => {
      const title = element.querySelector("[data-widget-title]")?.textContent.toLowerCase() || ""
      const type = element.dataset.widgetType?.toLowerCase() || ""
      const content = element.querySelector("[data-widget-content]")?.textContent.toLowerCase() || ""
      
      const searchText = `${title} ${type} ${content}`
      const matches = searchTerms.every(term => searchText.includes(term))
      
      element.classList.toggle(this.widgetHiddenClass, !matches)
    })
  }

  // Show/hide empty state
  showEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add(this.emptyStateVisibleClass)
    }
  }

  hideEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove(this.emptyStateVisibleClass)
    }
  }

  // Update widget count
  updateWidgetCount() {
    if (this.hasWidgetCountTarget) {
      this.widgetCountTarget.textContent = this.widgets.size
    }
  }

  // Show message to user
  showMessage(message, type = "info") {
    // This could dispatch a custom event for a global notification system
    const event = new CustomEvent("widget-manager:message", {
      detail: { message, type },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Save widget state (for auto-save functionality)
  async saveWidgetState(widgetId, updates) {
    try {
      const response = await fetch(`${this.widgetsUrlValue}/${widgetId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({ widget: updates })
      })
      
      if (!response.ok) {
        console.error("Failed to save widget state")
      }
    } catch (error) {
      console.error("Error saving widget state:", error)
    }
  }

  // Show add widget modal (placeholder - would integrate with modal system)
  showAddWidgetModal() {
    // Dispatch event for modal system to handle
    const event = new CustomEvent("widget-manager:show-add-modal", {
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Edit widget (placeholder - would integrate with modal system)
  editWidget(widgetId) {
    const widget = this.widgets.get(widgetId)
    if (!widget) return
    
    // Dispatch event for modal system to handle
    const event = new CustomEvent("widget-manager:show-edit-modal", {
      detail: { widget },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Toggle reorder mode
  toggleReorderMode() {
    this.isReordering = !this.isReordering
    
    if (this.hasReorderButtonTarget) {
      this.reorderButtonTarget.textContent = this.isReordering ? "Done" : "Reorder"
      this.reorderButtonTarget.classList.toggle("active", this.isReordering)
    }
    
    // Enable/disable sortable functionality
    const sortableController = this.application.getControllerForElementAndIdentifier(
      this.widgetListTarget, "drag-drop"
    )
    
    if (sortableController) {
      if (this.isReordering) {
        sortableController.enableSorting()
      } else {
        sortableController.disableSorting()
      }
    }
  }

  // === NEW WIDGET FRAMEWORK INTEGRATION ===

  async initializeFramework() {
    try {
      // Initialize the widget framework
      this.framework = new WidgetFramework(this.containerTarget, {
        persistenceKey: `widget-layout-${this.documentIdValue}`,
        defaultLayout: "grid",
        maxWidgets: this.maxWidgetsValue || 20,
        enableDragDrop: this.enableDragDropValue !== false,
        enableResize: true,
        autoSave: this.autoSaveValue !== false
      })
      
      // Register framework with global access
      if (!window.widgetFrameworks) {
        window.widgetFrameworks = new Map()
      }
      window.widgetFrameworks.set(this.documentIdValue, this.framework)
      
      // Setup framework event handlers
      this.setupFrameworkEvents()
      
      // Connect to plugin marketplace
      if (window.PluginMarketplace) {
        window.PluginMarketplace.registerWidgetFramework(this.framework)
      }
      
      this.showStatus("Widget framework initialized", "success")
      this.emit("widget-manager:initialized", { framework: this.framework })
    } catch (error) {
      console.error("Failed to initialize widget framework:", error)
      this.showStatus("Failed to initialize widget framework", "error")
    }
  }

  setupFrameworkEvents() {
    if (!this.framework) return
    
    // Framework events
    this.framework.on("framework:initialized", () => {
      this.showStatus("Widget framework ready", "success")
    })
    
    this.framework.on("framework:error", (event) => {
      console.error("Widget framework error:", event.detail.error)
      this.showStatus("Widget framework error", "error")
    })
    
    // Widget lifecycle events
    this.framework.on("widget:created", (event) => {
      const widget = event.detail.widget
      this.showStatus(`Widget "${widget.title}" created`, "success")
      this.updateWidgetCount()
      this.emit("widget:created", { widget })
    })
    
    this.framework.on("widget:closed", (event) => {
      const widget = event.detail.widget
      this.showStatus(`Widget "${widget.title}" closed`, "info")
      this.updateWidgetCount()
      this.emit("widget:closed", { widget })
    })
    
    this.framework.on("widget:focused", (event) => {
      const widget = event.detail.widget
      this.emit("widget:focused", { widget })
    })
    
    // Layout events
    this.framework.on("layout:saved", () => {
      this.showStatus("Layout saved", "success")
    })
    
    this.framework.on("layout:restored", () => {
      this.showStatus("Layout restored", "info")
      this.updateWidgetCount()
    })
    
    this.framework.on("layout:reset", () => {
      this.showStatus("Layout reset", "info")
      this.updateWidgetCount()
    })
  }

  setupWidgetTypes() {
    // Register available widget types
    this.widgetTypes = {
      "text": {
        name: "Text Widget",
        description: "Simple text display widget",
        icon: "📄",
        creator: this.createTextWidget.bind(this)
      },
      "notes": {
        name: "Notes Widget",
        description: "Editable notes widget",
        icon: "📝",
        creator: this.createNotesWidget.bind(this)
      },
      "todo": {
        name: "Todo List",
        description: "Task management widget",
        icon: "✅",
        creator: this.createTodoWidget.bind(this)
      },
      "timer": {
        name: "Timer Widget",
        description: "Countdown timer widget",
        icon: "⏰",
        creator: this.createTimerWidget.bind(this)
      },
      "plugin": {
        name: "Plugin Widget",
        description: "Widget powered by installed plugin",
        icon: "🔌",
        creator: this.createPluginWidget.bind(this)
      },
      "ai-review": {
        name: "AI Review Widget",
        description: "AI-powered code review widget",
        icon: "🤖",
        creator: this.createAIReviewWidget.bind(this)
      },
      "console": {
        name: "Console Widget",
        description: "Command execution console",
        icon: "💻",
        creator: this.createConsoleWidget.bind(this)
      }
    }
  }

  bindGlobalEvents() {
    // Handle widget creation from external sources
    document.addEventListener("create-widget", (event) => {
      this.handleExternalWidgetCreation(event.detail)
    })
    
    // Handle plugin widget requests
    document.addEventListener("create-plugin-widget", (event) => {
      this.handlePluginWidgetCreation(event.detail)
    })
    
    // Handle AI review widget requests
    document.addEventListener("create-ai-review-widget", (event) => {
      this.handleAIReviewWidgetCreation(event.detail)
    })
  }

  // Widget Creation Methods
  async createAIReviewWidget(options = {}) {
    if (!this.framework) return
    
    const content = `
      <div class="ai-review-widget">
        <div class="review-toolbar">
          <select class="review-type">
            <option value="review">Code Review</option>
            <option value="suggest">Suggestions</option>
            <option value="critique">Critique</option>
          </select>
          <button type="button" class="btn btn-sm" data-action="start-review">Start Review</button>
        </div>
        <div class="review-input-section">
          <textarea class="review-code" placeholder="Paste code here for review...">
${options.code || ""}
          </textarea>
        </div>
        <div class="review-output-section">
          <div class="review-results">
            <div class="no-results">No review results yet. Click "Start Review" to begin.</div>
          </div>
        </div>
        <div class="review-status">
          <div class="status-text"></div>
        </div>
      </div>
    `
    
    const widget = await this.framework.createWidget("ai-review", {
      title: options.title || "AI Code Review",
      content: content,
      size: { width: 600, height: 500 },
      settings: { reviewType: "review" },
      ...options
    })
    
    // Bind AI review events
    this.bindAIReviewEvents(widget)
    return widget
  }

  async createPluginWidget(options = {}) {
    if (!this.framework) return
    if (!options.pluginId) {
      throw new Error("Plugin ID is required for plugin widgets")
    }
    
    const content = `
      <div class="plugin-widget" data-plugin-id="${options.pluginId}">
        <div class="plugin-loading">
          <div class="loading-spinner"></div>
          <div>Loading plugin...</div>
        </div>
        <div class="plugin-content" style="display: none;">
          <!-- Plugin content will be loaded here -->
        </div>
        <div class="plugin-error" style="display: none;">
          <div class="error-message">Plugin failed to load</div>
          <button type="button" class="btn btn-sm" data-action="retry-plugin">Retry</button>
        </div>
      </div>
    `
    
    const widget = await this.framework.createWidget("plugin", {
      title: options.title || "Plugin Widget",
      content: content,
      size: { width: 400, height: 300 },
      pluginId: options.pluginId,
      ...options
    })
    
    // Initialize plugin
    await this.initializePluginWidget(widget)
    return widget
  }

  bindAIReviewEvents(widget) {
    const element = widget.element
    const reviewType = element.querySelector(".review-type")
    const startBtn = element.querySelector("[data-action=\"start-review\"]")
    const codeArea = element.querySelector(".review-code")
    const resultsArea = element.querySelector(".review-results")
    const statusArea = element.querySelector(".status-text")
    
    startBtn.addEventListener("click", async () => {
      const code = codeArea.value.trim()
      if (!code) {
        this.showWidgetStatus(statusArea, "Please enter code to review", "error")
        return
      }
      
      const type = reviewType.value
      await this.performAIReview(widget, type, code, resultsArea, statusArea)
    })
    
    reviewType.addEventListener("change", () => {
      widget.settings.reviewType = reviewType.value
    })
  }

  async performAIReview(widget, type, code, resultsArea, statusArea) {
    this.showWidgetStatus(statusArea, `Starting ${type}...`, "loading")
    
    try {
      const response = await fetch(`/documents/${this.documentIdValue}/commands`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          command: type,
          parameters: [],
          selected_content: code
        })
      })
      
      const result = await response.json()
      
      if (response.ok && result.status === "success") {
        this.displayReviewResults(resultsArea, result.result)
        this.showWidgetStatus(statusArea, `${type} completed`, "success")
      } else {
        throw new Error(result.error || "Review failed")
      }
    } catch (error) {
      console.error("AI review failed:", error)
      this.showWidgetStatus(statusArea, `${type} failed: ${error.message}`, "error")
    }
  }

  displayReviewResults(container, results) {
    container.innerHTML = `
      <div class="review-result">
        <div class="result-content">
          ${this.formatReviewContent(results.content || results)}
        </div>
        ${results.timestamp ? `<div class="result-timestamp">Generated: ${new Date(results.timestamp).toLocaleString()}</div>` : ""}
      </div>
    `
  }

  formatReviewContent(content) {
    // Simple formatting - in production, this would be more sophisticated
    if (typeof content === "string") {
      return content.replace(/\n/g, "<br>")
    }
    return JSON.stringify(content, null, 2).replace(/\n/g, "<br>")
  }

  async initializePluginWidget(widget) {
    const pluginContainer = widget.element.querySelector(".plugin-widget")
    const loadingDiv = pluginContainer.querySelector(".plugin-loading")
    const contentDiv = pluginContainer.querySelector(".plugin-content")
    const errorDiv = pluginContainer.querySelector(".plugin-error")
    
    try {
      // Simulate plugin loading (real implementation would load actual plugin)
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      // Hide loading, show content
      loadingDiv.style.display = "none"
      contentDiv.style.display = "block"
      contentDiv.innerHTML = `
        <div class="plugin-interface">
          <h4>Plugin: ${widget.pluginId}</h4>
          <p>Plugin interface would be loaded here.</p>
          <button type="button" class="btn btn-sm" data-action="plugin-action">Execute Action</button>
        </div>
      `
      
      // Bind plugin-specific events
      contentDiv.querySelector("[data-action=\"plugin-action\"]").addEventListener("click", () => {
        this.executePluginAction(widget)
      })
      
    } catch (error) {
      console.error("Plugin initialization failed:", error)
      loadingDiv.style.display = "none"
      errorDiv.style.display = "block"
      
      errorDiv.querySelector("[data-action=\"retry-plugin\"]").addEventListener("click", () => {
        errorDiv.style.display = "none"
        loadingDiv.style.display = "block"
        this.initializePluginWidget(widget)
      })
    }
  }

  async executePluginAction(widget) {
    try {
      const response = await fetch(`/extensions/${widget.pluginId}/execute`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          command: { action: "widget-action" }
        })
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.showStatus("Plugin action executed successfully", "success")
      } else {
        throw new Error(result.error)
      }
    } catch (error) {
      console.error("Plugin action failed:", error)
      this.showStatus(`Plugin action failed: ${error.message}`, "error")
    }
  }

  // External Event Handlers
  async handleExternalWidgetCreation(detail) {
    const { type, options } = detail
    
    if (this.widgetTypes[type]) {
      await this.widgetTypes[type].creator(options)
    } else {
      throw new Error(`Unknown widget type: ${type}`)
    }
  }

  async handlePluginWidgetCreation(detail) {
    const { pluginId, options } = detail
    await this.createPluginWidget({ pluginId, ...options })
  }

  async handleAIReviewWidgetCreation(detail) {
    const { code, reviewType, options } = detail
    await this.createAIReviewWidget({ code, reviewType, ...options })
  }

  // Action Handlers (called from UI)
  async openMarketplace(event) {
    event.preventDefault()
    
    if (window.PluginMarketplace) {
      window.PluginMarketplace.open()
    } else {
      this.showStatus("Plugin marketplace not available", "error")
    }
  }

  async saveLayout(event) {
    event.preventDefault()
    
    if (this.framework) {
      await this.framework.saveLayout()
    }
  }

  async resetLayout(event) {
    event.preventDefault()
    
    if (this.framework) {
      await this.framework.resetLayout()
    }
  }

  // Helper Methods
  showStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `widget-status ${type}`
      
      // Auto-clear success messages
      if (type === "success") {
        setTimeout(() => {
          this.statusTarget.textContent = ""
          this.statusTarget.className = "widget-status"
        }, 3000)
      }
    }
  }

  showWidgetStatus(element, message, type = "info") {
    element.textContent = message
    element.className = `status-text ${type}`
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  emit(eventName, detail = {}) {
    const event = new CustomEvent(eventName, { 
      detail: { ...detail, controller: this },
      bubbles: true 
    })
    this.element.dispatchEvent(event)
  }

  cleanup() {
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