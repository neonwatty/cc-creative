import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "sortSelect", "tab", "panel"]
  
  connect() {
    // Initialize with saved preferences if available
    this.loadPreferences()
  }

  filterItems(event) {
    const query = event.target.value.toLowerCase()
    
    // Store the search query
    this.savePreference('searchQuery', query)
    
    // Filter items in all panels
    this.panelTargets.forEach(panel => {
      const items = panel.querySelectorAll('[data-context-item]')
      
      items.forEach(item => {
        const title = item.querySelector('[data-item-title]')?.textContent.toLowerCase() || ''
        const content = item.querySelector('[data-item-content]')?.textContent.toLowerCase() || ''
        
        if (title.includes(query) || content.includes(query)) {
          item.style.display = ''
        } else {
          item.style.display = 'none'
        }
      })
      
      // Show/hide empty state
      const visibleItems = panel.querySelectorAll('[data-context-item]:not([style*="display: none"])')
      const emptyState = panel.querySelector('[data-empty-state]')
      
      if (emptyState) {
        emptyState.style.display = visibleItems.length === 0 ? '' : 'none'
      }
    })
  }

  sortItems(event) {
    const sortBy = event.target.value
    
    // Store the sort preference
    this.savePreference('sortBy', sortBy)
    
    // Reload the component with new sort order
    // In a real implementation, this would trigger a Turbo Frame update
    this.reloadWithParams({ sort_by: sortBy })
  }

  switchTab(event) {
    event.preventDefault()
    const button = event.currentTarget
    const tabName = button.dataset.tab
    
    // Update active tab styling
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      tab.classList.toggle('bg-white', isActive)
      tab.classList.toggle('text-blue-600', isActive)
      tab.classList.toggle('border-b-2', isActive)
      tab.classList.toggle('border-blue-600', isActive)
      tab.classList.toggle('text-gray-600', !isActive)
      tab.setAttribute('aria-selected', isActive)
    })
    
    // Show/hide panels
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.panel === tabName
      panel.classList.toggle('hidden', !isActive)
    })
    
    // Store the active tab preference
    this.savePreference('activeTab', tabName)
  }

  toggleCollapse(event) {
    event.preventDefault()
    
    // Toggle collapsed state
    const sidebar = this.element
    sidebar.classList.toggle('w-16')
    sidebar.classList.toggle('w-80')
    
    // Toggle visibility of content
    const content = sidebar.querySelectorAll('[data-collapsible]')
    content.forEach(el => {
      el.classList.toggle('hidden')
    })
    
    // Update button text/icon
    const button = event.currentTarget
    const isCollapsed = sidebar.classList.contains('w-16')
    button.innerHTML = isCollapsed ? 
      '<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>' :
      '<svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 5l7 7-7 7M5 5l7 7-7 7"></path></svg> Collapse'
    
    // Store collapsed state
    this.savePreference('collapsed', isCollapsed)
  }

  loadPreferences() {
    const preferences = JSON.parse(localStorage.getItem('contextSidebarPreferences') || '{}')
    
    if (preferences.searchQuery && this.hasSearchInputTarget) {
      this.searchInputTarget.value = preferences.searchQuery
      this.filterItems({ target: this.searchInputTarget })
    }
    
    if (preferences.sortBy && this.hasSortSelectTarget) {
      this.sortSelectTarget.value = preferences.sortBy
    }
    
    if (preferences.activeTab) {
      const activeTab = this.tabTargets.find(tab => tab.dataset.tab === preferences.activeTab)
      if (activeTab) {
        this.switchTab({ preventDefault: () => {}, currentTarget: activeTab })
      }
    }
    
    if (preferences.collapsed) {
      // Apply collapsed state
      this.element.classList.add('w-16')
      this.element.classList.remove('w-80')
    }
  }

  savePreference(key, value) {
    const preferences = JSON.parse(localStorage.getItem('contextSidebarPreferences') || '{}')
    preferences[key] = value
    localStorage.setItem('contextSidebarPreferences', JSON.stringify(preferences))
  }

  reloadWithParams(params) {
    // Build URL with new parameters
    const url = new URL(window.location)
    Object.entries(params).forEach(([key, value]) => {
      url.searchParams.set(key, value)
    })
    
    // Use Turbo to update the sidebar
    if (window.Turbo) {
      Turbo.visit(url.toString(), { frame: 'context-sidebar-frame' })
    } else {
      window.location = url.toString()
    }
  }
}