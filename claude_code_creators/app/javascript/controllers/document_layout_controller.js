import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="document-layout"
export default class extends Controller {
  static targets = [
    "mainContent", "contentArea", "mobileMenu", "mobileOverlay", 
    "layoutToggle", "shortcutsModal", "dropZones"
  ]
  
  static values = {
    sidebarCollapsed: Boolean,
    layoutType: String,
    enableCollaboration: Boolean
  }

  connect() {
    // Bind keyboard shortcuts
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
    
    // Handle window resize for responsive behavior
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.handleResize)
    this.handleResize() // Check initial size
    
    // Initialize drop zones for global drag & drop
    this.initializeDropZones()
    
    // Load saved layout preferences
    this.loadLayoutPreferences()
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown)
    window.removeEventListener('resize', this.handleResize)
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    // Show shortcuts modal
    if (event.key === '?' && !event.shiftKey && !event.metaKey && !event.ctrlKey) {
      // Only if not in an input field
      if (!this.isInInputField(event.target)) {
        event.preventDefault()
        this.showShortcuts()
      }
    }
    
    // Hide shortcuts modal
    if (event.key === 'Escape' && this.hasShortcutsModalTarget) {
      if (!this.shortcutsModalTarget.classList.contains('invisible')) {
        event.preventDefault()
        this.hideShortcuts()
      }
    }
    
    // Toggle sidebar
    if ((event.metaKey || event.ctrlKey) && event.key === 'b') {
      event.preventDefault()
      this.toggleSidebar()
    }
    
    // New document
    if ((event.metaKey || event.ctrlKey) && event.key === 'n') {
      event.preventDefault()
      window.location.href = '/documents/new'
    }
    
    // Save document (if editing)
    if ((event.metaKey || event.ctrlKey) && event.key === 's') {
      event.preventDefault()
      this.saveDocument()
    }
  }

  // Check if we're in an input field
  isInInputField(element) {
    const tagName = element.tagName.toLowerCase()
    return tagName === 'input' || tagName === 'textarea' || element.contentEditable === 'true'
  }

  // Handle window resize
  handleResize() {
    const isMobile = window.innerWidth < 1024 // lg breakpoint
    
    if (isMobile) {
      this.closeMobileMenu()
    }
    
    // Update layout based on screen size
    this.updateResponsiveLayout()
  }

  // Update responsive layout
  updateResponsiveLayout() {
    const isMobile = window.innerWidth < 1024
    
    if (this.hasMainContentTarget) {
      if (isMobile || this.layoutTypeValue === 'focused') {
        // Remove sidebar margins on mobile or focused mode
        this.mainContentTarget.classList.remove('ml-16', 'ml-80')
        this.mainContentTarget.classList.add('ml-0')
      } else {
        // Apply sidebar margins on desktop
        this.mainContentTarget.classList.remove('ml-0')
        if (this.sidebarCollapsedValue) {
          this.mainContentTarget.classList.remove('ml-80')
          this.mainContentTarget.classList.add('ml-16')
        } else {
          this.mainContentTarget.classList.remove('ml-16')
          this.mainContentTarget.classList.add('ml-80')
        }
      }
    }
  }

  // Toggle sidebar collapsed state
  toggleSidebar() {
    this.sidebarCollapsedValue = !this.sidebarCollapsedValue
    this.updateResponsiveLayout()
    this.saveLayoutPreferences()
    
    // Dispatch event for sidebar component
    this.dispatch('sidebar-toggled', {
      detail: { collapsed: this.sidebarCollapsedValue }
    })
  }

  // Toggle layout type
  toggleLayoutType() {
    const types = ['default', 'focused', 'minimal']
    const currentIndex = types.indexOf(this.layoutTypeValue)
    const nextIndex = (currentIndex + 1) % types.length
    
    this.layoutTypeValue = types[nextIndex]
    this.updateLayoutType()
    this.saveLayoutPreferences()
  }

  // Update layout type
  updateLayoutType() {
    const layoutElement = this.element
    
    // Remove all layout type classes
    layoutElement.classList.remove(
      'layout-default', 'layout-focused', 'layout-minimal'
    )
    
    // Add current layout type class
    layoutElement.classList.add(`layout-${this.layoutTypeValue}`)
    
    // Update responsive layout
    this.updateResponsiveLayout()
    
    // Dispatch event
    this.dispatch('layout-type-changed', {
      detail: { layoutType: this.layoutTypeValue }
    })
  }

  // Open mobile menu
  openMobileMenu() {
    if (this.hasMobileMenuTarget && this.hasMobileOverlayTarget) {
      this.mobileMenuTarget.classList.remove('translate-x-full')
      this.mobileMenuTarget.classList.add('translate-x-0')
      
      this.mobileOverlayTarget.classList.remove('opacity-0', 'invisible')
      this.mobileOverlayTarget.classList.add('opacity-100', 'visible')
      
      // Prevent body scroll
      document.body.style.overflow = 'hidden'
    }
  }

  // Close mobile menu
  closeMobileMenu() {
    if (this.hasMobileMenuTarget && this.hasMobileOverlayTarget) {
      this.mobileMenuTarget.classList.add('translate-x-full')
      this.mobileMenuTarget.classList.remove('translate-x-0')
      
      this.mobileOverlayTarget.classList.add('opacity-0', 'invisible')
      this.mobileOverlayTarget.classList.remove('opacity-100', 'visible')
      
      // Restore body scroll
      document.body.style.overflow = ''
    }
  }

  // Show keyboard shortcuts modal
  showShortcuts() {
    if (this.hasShortcutsModalTarget) {
      this.shortcutsModalTarget.classList.remove('opacity-0', 'invisible')
      this.shortcutsModalTarget.classList.add('opacity-100', 'visible')
    }
  }

  // Hide keyboard shortcuts modal
  hideShortcuts() {
    if (this.hasShortcutsModalTarget) {
      this.shortcutsModalTarget.classList.add('opacity-0', 'invisible')
      this.shortcutsModalTarget.classList.remove('opacity-100', 'visible')
    }
  }

  // Share document
  shareDocument() {
    // Implement document sharing functionality
    if (navigator.share) {
      navigator.share({
        title: document.title,
        url: window.location.href
      }).catch(console.error)
    } else {
      // Fallback: copy URL to clipboard
      navigator.clipboard.writeText(window.location.href).then(() => {
        this.showNotification('Document URL copied to clipboard!')
      }).catch(console.error)
    }
  }

  // Export document
  exportDocument() {
    // Trigger export functionality
    const documentId = this.element.dataset.documentId
    if (documentId) {
      window.location.href = `/documents/${documentId}/export`
    }
  }

  // Save document
  saveDocument() {
    // Dispatch save event for editor
    this.dispatch('save-requested', {
      detail: { timestamp: Date.now() }
    })
  }

  // Initialize drop zones for global drag & drop
  initializeDropZones() {
    // This would set up global drop zones based on the current view
    // For now, we'll just add the necessary event listeners
    this.element.addEventListener('dragover', this.handleGlobalDragOver.bind(this))
    this.element.addEventListener('drop', this.handleGlobalDrop.bind(this))
  }

  // Handle global drag over
  handleGlobalDragOver(event) {
    event.preventDefault()
    
    // You could add visual feedback here for global drop zones
    const dragData = this.extractDragData(event)
    if (dragData) {
      this.highlightDropZones(dragData.type)
    }
  }

  // Handle global drop
  handleGlobalDrop(event) {
    event.preventDefault()
    
    const dragData = this.extractDragData(event)
    if (dragData) {
      this.clearDropZoneHighlights()
      
      // Dispatch global drop event
      this.dispatch('global-drop', {
        detail: { 
          data: dragData,
          position: { x: event.clientX, y: event.clientY }
        }
      })
    }
  }

  // Extract drag data (helper method)
  extractDragData(event) {
    try {
      const jsonData = event.dataTransfer.getData('application/json')
      return jsonData ? JSON.parse(jsonData) : null
    } catch (e) {
      return null
    }
  }

  // Highlight available drop zones
  highlightDropZones(dataType) {
    // This would highlight drop zones that accept the dragged data type
    const dropZones = this.element.querySelectorAll('[data-accepts-type]')
    dropZones.forEach(zone => {
      const acceptedTypes = zone.dataset.acceptsType.split(',')
      if (acceptedTypes.includes(dataType) || acceptedTypes.includes('*')) {
        zone.classList.add('drop-zone-highlighted')
      }
    })
  }

  // Clear drop zone highlights
  clearDropZoneHighlights() {
    const highlightedZones = this.element.querySelectorAll('.drop-zone-highlighted')
    highlightedZones.forEach(zone => {
      zone.classList.remove('drop-zone-highlighted')
    })
  }

  // Show notification
  showNotification(message, type = 'info') {
    // Create and show a temporary notification
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-4 py-2 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full`
    
    switch (type) {
      case 'success':
        notification.classList.add('bg-creative-secondary-500', 'text-white')
        break
      case 'error':
        notification.classList.add('bg-red-500', 'text-white')
        break
      default:
        notification.classList.add('bg-creative-primary-500', 'text-white')
    }
    
    notification.textContent = message
    document.body.appendChild(notification)
    
    // Animate in
    requestAnimationFrame(() => {
      notification.classList.remove('translate-x-full')
      notification.classList.add('translate-x-0')
    })
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => {
        document.body.removeChild(notification)
      }, 300)
    }, 3000)
  }

  // Save layout preferences to localStorage
  saveLayoutPreferences() {
    const preferences = {
      sidebarCollapsed: this.sidebarCollapsedValue,
      layoutType: this.layoutTypeValue
    }
    
    localStorage.setItem('document-layout-preferences', JSON.stringify(preferences))
  }

  // Load layout preferences from localStorage
  loadLayoutPreferences() {
    try {
      const saved = localStorage.getItem('document-layout-preferences')
      if (saved) {
        const preferences = JSON.parse(saved)
        this.sidebarCollapsedValue = preferences.sidebarCollapsed || false
        this.layoutTypeValue = preferences.layoutType || 'default'
        
        this.updateLayoutType()
        this.updateResponsiveLayout()
      }
    } catch (e) {
      console.warn('Failed to load layout preferences:', e)
    }
  }

  // Handle value changes
  sidebarCollapsedValueChanged() {
    this.updateResponsiveLayout()
  }

  layoutTypeValueChanged() {
    this.updateLayoutType()
  }
}