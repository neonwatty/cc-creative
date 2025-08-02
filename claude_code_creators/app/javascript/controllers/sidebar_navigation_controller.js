import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-navigation"
export default class extends Controller {
  static targets = ["toggleButton"]
  static values = { collapsed: Boolean }

  connect() {
    // Load collapsed state from localStorage
    const savedState = localStorage.getItem("sidebar-collapsed")
    if (savedState !== null) {
      this.collapsedValue = savedState === "true"
      this.updateSidebarState()
    }

    // Add resize listener to auto-collapse on small screens
    this.resizeListener = this.handleResize.bind(this)
    window.addEventListener("resize", this.resizeListener)
    this.handleResize() // Check initial screen size
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeListener)
  }

  // Toggle sidebar collapsed state
  toggle() {
    this.collapsedValue = !this.collapsedValue
    this.updateSidebarState()
    this.saveSidebarState()
  }

  // Update sidebar visual state
  updateSidebarState() {
    const sidebar = this.element
    
    if (this.collapsedValue) {
      sidebar.classList.remove("w-80")
      sidebar.classList.add("w-16")
    } else {
      sidebar.classList.remove("w-16")
      sidebar.classList.add("w-80")
    }

    // Update toggle button icon
    if (this.hasToggleButtonTarget) {
      const icon = this.toggleButtonTarget.querySelector("svg")
      if (icon) {
        if (this.collapsedValue) {
          icon.classList.add("rotate-180")
        } else {
          icon.classList.remove("rotate-180")
        }
      }
    }

    // Dispatch event for other components to react
    this.dispatch("toggled", { 
      detail: { collapsed: this.collapsedValue } 
    })
  }

  // Save state to localStorage
  saveSidebarState() {
    localStorage.setItem("sidebar-collapsed", this.collapsedValue.toString())
  }

  // Handle window resize
  handleResize() {
    const isSmallScreen = window.innerWidth < 1024 // lg breakpoint
    
    if (isSmallScreen && !this.collapsedValue) {
      this.collapsedValue = true
      this.updateSidebarState()
    }
  }

  // Handle context item selection
  selectContextItem(event) {
    event.preventDefault()
    const contextItemId = event.currentTarget.dataset.contextItemId
    
    // Add visual selection state
    this.clearContextItemSelection()
    event.currentTarget.classList.add("bg-creative-primary-50", "dark:bg-creative-primary-900/20")
    
    // Dispatch event for other components
    this.dispatch("context-item-selected", {
      detail: { contextItemId }
    })
  }

  // Handle context item insertion
  insertContextItem(event) {
    event.stopPropagation()
    const contextItemId = event.currentTarget.dataset.contextItemId
    
    // Add loading state to button
    const button = event.currentTarget
    const originalContent = button.innerHTML
    button.innerHTML = "<div class=\"w-3 h-3 border border-creative-primary-500 border-t-transparent rounded-full animate-spin\"></div>"
    button.disabled = true
    
    // Dispatch event for editor to handle insertion
    this.dispatch("context-item-insert", {
      detail: { 
        contextItemId,
        button,
        originalContent
      }
    })
  }

  // Clear context item selections
  clearContextItemSelection() {
    const selectedItems = this.element.querySelectorAll("[data-context-item-id]")
    selectedItems.forEach(item => {
      item.classList.remove("bg-creative-primary-50", "dark:bg-creative-primary-900/20")
    })
  }

  // Handle context item insertion completion
  contextItemInserted(event) {
    const { button, originalContent, success } = event.detail
    
    if (button) {
      // Restore button state
      button.innerHTML = originalContent
      button.disabled = false
      
      if (success) {
        // Show brief success state
        button.classList.add("text-creative-secondary-600", "dark:text-creative-secondary-400")
        setTimeout(() => {
          button.classList.remove("text-creative-secondary-600", "dark:text-creative-secondary-400")
        }, 1000)
      }
    }
  }

  // Expand sidebar (called from external components)
  expand() {
    if (this.collapsedValue) {
      this.collapsedValue = false
      this.updateSidebarState()
      this.saveSidebarState()
    }
  }

  // Collapse sidebar (called from external components)
  collapse() {
    if (!this.collapsedValue) {
      this.collapsedValue = true
      this.updateSidebarState()
      this.saveSidebarState()
    }
  }

  // Handle search functionality (if search input is added)
  search(event) {
    const query = event.target.value.toLowerCase().trim()
    const searchableItems = this.element.querySelectorAll("[data-searchable]")
    
    searchableItems.forEach(item => {
      const text = item.textContent.toLowerCase()
      const matches = text.includes(query) || query === ""
      
      item.style.display = matches ? "" : "none"
    })
  }

  // Handle navigation item hover for tooltips in collapsed mode
  showTooltip(event) {
    if (!this.collapsedValue) return
    
    const item = event.currentTarget
    const tooltip = item.querySelector("[data-tooltip]")
    
    if (tooltip) {
      tooltip.classList.remove("opacity-0", "invisible")
      tooltip.classList.add("opacity-100", "visible")
    }
  }

  hideTooltip(event) {
    if (!this.collapsedValue) return
    
    const item = event.currentTarget
    const tooltip = item.querySelector("[data-tooltip]")
    
    if (tooltip) {
      tooltip.classList.add("opacity-0", "invisible")
      tooltip.classList.remove("opacity-100", "visible")
    }
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    // Cmd/Ctrl + B to toggle sidebar
    if ((event.metaKey || event.ctrlKey) && event.key === "b") {
      event.preventDefault()
      this.toggle()
    }
    
    // Escape to collapse sidebar
    if (event.key === "Escape" && !this.collapsedValue) {
      this.collapse()
    }
  }

  // Update values when changed
  collapsedValueChanged() {
    this.updateSidebarState()
  }
}