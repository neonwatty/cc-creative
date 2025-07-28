import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

// Connects to data-controller="widget-manager"
export default class extends Controller {
  static targets = [
    "widgetList", "addButton", "removeButton", "reorderButton",
    "widgetTemplate", "emptyState", "widgetCount", "searchInput"
  ]
  
  static values = {
    widgetsUrl: String,
    maxWidgets: { type: Number, default: 10 },
    enableSearch: { type: Boolean, default: true },
    enableReorder: { type: Boolean, default: true },
    autoSave: { type: Boolean, default: true }
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
    
    this.loadWidgets()
    this.updateWidgetCount()
    this.setupEventListeners()
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
        console.error('Failed to load widgets')
        this.showEmptyState()
      }
    } catch (error) {
      console.error('Error loading widgets:', error)
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
    
    const titleElement = widgetElement.querySelector('[data-widget-title]')
    if (titleElement) titleElement.textContent = widget.title
    
    const contentElement = widgetElement.querySelector('[data-widget-content]')
    if (contentElement) contentElement.innerHTML = widget.content
    
    const typeElement = widgetElement.querySelector('[data-widget-type]')
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
    widgetElement.addEventListener('click', (event) => {
      if (!event.target.closest('[data-widget-action]')) {
        this.toggleWidgetSelection(widgetElement)
      }
    })
    
    // Widget actions
    const actionButtons = widgetElement.querySelectorAll('[data-widget-action]')
    actionButtons.forEach(button => {
      button.addEventListener('click', (event) => {
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
      this.addButtonTarget.addEventListener('click', this.showAddWidgetModal.bind(this))
    }
    
    // Remove button
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.addEventListener('click', this.removeSelectedWidgets.bind(this))
    }
    
    // Reorder button
    if (this.hasReorderButtonTarget && this.enableReorderValue) {
      this.reorderButtonTarget.addEventListener('click', this.toggleReorderMode.bind(this))
    }
    
    // Search input
    if (this.hasSearchInputTarget && this.enableSearchValue) {
      this.searchInputTarget.addEventListener('input', (event) => {
        this.debouncedSearch(event.target.value)
      })
    }
    
    // Keyboard shortcuts
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    // Only handle if focus is within this controller
    if (!this.element.contains(document.activeElement)) return
    
    switch (event.key) {
      case 'Delete':
      case 'Backspace':
        if (this.selectedWidgets.size > 0) {
          event.preventDefault()
          this.removeSelectedWidgets()
        }
        break
      case 'a':
        if (event.metaKey || event.ctrlKey) {
          event.preventDefault()
          this.selectAllWidgets()
        }
        break
      case 'Escape':
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
    const widgetElements = this.widgetListTarget.querySelectorAll('[data-widget-id]')
    
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
      case 'edit':
        this.editWidget(widgetId)
        break
      case 'delete':
        this.removeWidget(widgetId, widgetElement)
        break
      case 'duplicate':
        this.duplicateWidget(widgetId)
        break
      case 'toggle':
        this.toggleWidgetVisibility(widgetId, widgetElement)
        break
    }
  }

  // Add new widget
  async addWidget(widgetData) {
    if (this.widgets.size >= this.maxWidgetsValue) {
      this.showMessage(`Cannot add more than ${this.maxWidgetsValue} widgets`, 'error')
      return
    }
    
    try {
      const response = await fetch(this.widgetsUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ widget: widgetData })
      })
      
      if (response.ok) {
        const data = await response.json()
        this.widgets.set(data.id, data)
        this.addWidgetToDOM(data)
        this.hideEmptyState()
        this.updateWidgetCount()
        this.showMessage('Widget added successfully!', 'success')
      } else {
        throw new Error('Failed to create widget')
      }
    } catch (error) {
      console.error('Error adding widget:', error)
      this.showMessage('Failed to add widget', 'error')
    }
  }

  // Remove widget
  async removeWidget(widgetId, widgetElement) {
    if (!confirm('Are you sure you want to delete this widget?')) return
    
    try {
      const response = await fetch(`${this.widgetsUrlValue}/${widgetId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
        }
      })
      
      if (response.ok) {
        this.widgets.delete(widgetId)
        this.selectedWidgets.delete(widgetId)
        
        // Animate removal
        widgetElement.style.transition = 'transform 0.3s ease, opacity 0.3s ease'
        widgetElement.style.transform = 'translateX(-100%)'
        widgetElement.style.opacity = '0'
        
        setTimeout(() => {
          widgetElement.remove()
          this.updateWidgetCount()
          this.updateSelectionUI()
          
          if (this.widgets.size === 0) {
            this.showEmptyState()
          }
        }, 300)
        
        this.showMessage('Widget removed successfully!', 'success')
      } else {
        throw new Error('Failed to delete widget')
      }
    } catch (error) {
      console.error('Error removing widget:', error)
      this.showMessage('Failed to remove widget', 'error')
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
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
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
            element.style.transition = 'transform 0.3s ease, opacity 0.3s ease'
            element.style.transform = 'translateX(-100%)'
            element.style.opacity = '0'
            
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
        
        this.showMessage(`${count} widget(s) removed successfully!`, 'success')
      } else {
        throw new Error('Failed to delete widgets')
      }
    } catch (error) {
      console.error('Error removing widgets:', error)
      this.showMessage('Failed to remove widgets', 'error')
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
    const widgetElements = this.widgetListTarget.querySelectorAll('[data-widget-id]')
    
    if (!query.trim()) {
      // Show all widgets
      widgetElements.forEach(element => {
        element.classList.remove(this.widgetHiddenClass)
      })
      return
    }
    
    const searchTerms = query.toLowerCase().split(' ')
    
    widgetElements.forEach(element => {
      const title = element.querySelector('[data-widget-title]')?.textContent.toLowerCase() || ''
      const type = element.dataset.widgetType?.toLowerCase() || ''
      const content = element.querySelector('[data-widget-content]')?.textContent.toLowerCase() || ''
      
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
  showMessage(message, type = 'info') {
    // This could dispatch a custom event for a global notification system
    const event = new CustomEvent('widget-manager:message', {
      detail: { message, type },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Save widget state (for auto-save functionality)
  async saveWidgetState(widgetId, updates) {
    try {
      const response = await fetch(`${this.widgetsUrlValue}/${widgetId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ widget: updates })
      })
      
      if (!response.ok) {
        console.error('Failed to save widget state')
      }
    } catch (error) {
      console.error('Error saving widget state:', error)
    }
  }

  // Show add widget modal (placeholder - would integrate with modal system)
  showAddWidgetModal() {
    // Dispatch event for modal system to handle
    const event = new CustomEvent('widget-manager:show-add-modal', {
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Edit widget (placeholder - would integrate with modal system)
  editWidget(widgetId) {
    const widget = this.widgets.get(widgetId)
    if (!widget) return
    
    // Dispatch event for modal system to handle
    const event = new CustomEvent('widget-manager:show-edit-modal', {
      detail: { widget },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  // Toggle reorder mode
  toggleReorderMode() {
    this.isReordering = !this.isReordering
    
    if (this.hasReorderButtonTarget) {
      this.reorderButtonTarget.textContent = this.isReordering ? 'Done' : 'Reorder'
      this.reorderButtonTarget.classList.toggle('active', this.isReordering)
    }
    
    // Enable/disable sortable functionality
    const sortableController = this.application.getControllerForElementAndIdentifier(
      this.widgetListTarget, 'drag-drop'
    )
    
    if (sortableController) {
      if (this.isReordering) {
        sortableController.enableSorting()
      } else {
        sortableController.disableSorting()
      }
    }
  }
}