import { Controller } from "@hotwired/stimulus"

// Debounce helper function
function debounce(func, wait) {
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

export default class extends Controller {
  static targets = ["searchInput", "typeFilter", "dateFilter", "sortSelect", "clearButton", "form"]
  static values = { documentId: Number }
  
  connect() {
    // Initialize keyboard shortcuts
    this.setupKeyboardShortcuts()
    
    // Create debounced search function
    this.debouncedSubmit = debounce(this.submitForm.bind(this), 300)
    
    // Update clear button visibility on load
    this.updateClearButtonVisibility()
    
    // Store initial scroll position
    this.preserveScroll = true
  }
  
  disconnect() {
    // Remove keyboard event listener
    this.removeKeyboardShortcuts()
  }
  
  // Handle search input with debouncing
  debounceSearch(event) {
    const query = event.target.value.trim()
    
    // Show loading state
    this.setLoadingState(true)
    
    // Update URL params immediately for better UX
    this.updateUrlParams({ query })
    
    // Submit form after debounce
    this.debouncedSubmit()
  }
  
  // Handle filter changes (immediate submit)
  filterChanged(event) {
    this.setLoadingState(true)
    this.submitForm()
  }
  
  // Handle sort changes (immediate submit)
  sortChanged(event) {
    this.setLoadingState(true)
    this.submitForm()
  }
  
  // Submit the form via Turbo
  submitForm() {
    if (!this.element.closest("form")) return
    
    const form = this.element.closest("form")
    
    // Preserve scroll position
    if (this.preserveScroll) {
      const scrollTop = document.querySelector("[data-context-sidebar]")?.scrollTop || 0
      sessionStorage.setItem("contextSidebarScrollPosition", scrollTop)
    }
    
    // Submit form using Turbo
    form.requestSubmit()
  }
  
  // Clear search input and submit
  clearSearch(event) {
    event?.preventDefault()
    
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }
    
    this.setLoadingState(true)
    this.submitForm()
  }
  
  // Clear all filters
  clearAllFilters(event) {
    event?.preventDefault()
    
    // Reset all form inputs
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }
    
    if (this.hasTypeFilterTarget) {
      this.typeFilterTarget.value = ""
    }
    
    if (this.hasDateFilterTarget) {
      this.dateFilterTarget.value = ""
    }
    
    if (this.hasSortSelectTarget) {
      this.sortSelectTarget.value = "recent"
    }
    
    this.setLoadingState(true)
    this.submitForm()
  }
  
  // Clear individual filter
  clearFilter(event) {
    event.preventDefault()
    const filterType = event.currentTarget.dataset.filterType
    
    switch(filterType) {
    case "query":
      if (this.hasSearchInputTarget) this.searchInputTarget.value = ""
      break
    case "type":
      if (this.hasTypeFilterTarget) this.typeFilterTarget.value = ""
      break
    case "date":
      if (this.hasDateFilterTarget) this.dateFilterTarget.value = ""
      break
    }
    
    this.setLoadingState(true)
    this.submitForm()
  }
  
  // Update URL parameters without navigation
  updateUrlParams(params) {
    const url = new URL(window.location)
    
    Object.entries(params).forEach(([key, value]) => {
      if (value) {
        url.searchParams.set(key, value)
      } else {
        url.searchParams.delete(key)
      }
    })
    
    // Update browser URL without navigation
    window.history.replaceState({}, "", url)
  }
  
  // Set loading state on form elements
  setLoadingState(loading) {
    const form = this.element.closest("form")
    if (!form) return
    
    // Add/remove loading classes
    if (loading) {
      form.classList.add("opacity-60", "pointer-events-none")
      
      // Add loading spinner to search input
      if (this.hasSearchInputTarget) {
        this.searchInputTarget.classList.add("pr-8")
        
        // Create spinner if it doesn't exist
        if (!this.spinner) {
          this.spinner = document.createElement("div")
          this.spinner.className = "absolute right-2 top-2.5"
          this.spinner.innerHTML = `
            <svg class="animate-spin h-4 w-4 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          `
          this.searchInputTarget.parentElement.appendChild(this.spinner)
        }
        
        this.spinner.style.display = "block"
      }
    } else {
      form.classList.remove("opacity-60", "pointer-events-none")
      
      if (this.spinner) {
        this.spinner.style.display = "none"
      }
      
      // Restore scroll position
      const scrollPosition = sessionStorage.getItem("contextSidebarScrollPosition")
      if (scrollPosition && this.preserveScroll) {
        const sidebar = document.querySelector("[data-context-sidebar]")
        if (sidebar) {
          sidebar.scrollTop = parseInt(scrollPosition)
        }
        sessionStorage.removeItem("contextSidebarScrollPosition")
      }
    }
  }
  
  // Update visibility of clear buttons based on active filters
  updateClearButtonVisibility() {
    const hasActiveFilters = 
      (this.hasSearchInputTarget && this.searchInputTarget.value) ||
      (this.hasTypeFilterTarget && this.typeFilterTarget.value) ||
      (this.hasDateFilterTarget && this.dateFilterTarget.value)
    
    // Show/hide clear all button
    const clearAllButton = this.element.querySelector("[data-action*=\"clearAllFilters\"]")
    if (clearAllButton) {
      clearAllButton.style.display = hasActiveFilters ? "inline-flex" : "none"
    }
  }
  
  // Setup keyboard shortcuts
  setupKeyboardShortcuts() {
    this.keyboardHandler = (event) => {
      // Cmd/Ctrl + K to focus search
      if ((event.metaKey || event.ctrlKey) && event.key === "k") {
        event.preventDefault()
        if (this.hasSearchInputTarget) {
          this.searchInputTarget.focus()
          this.searchInputTarget.select()
        }
      }
      
      // Escape to clear search when focused
      if (event.key === "Escape" && document.activeElement === this.searchInputTarget) {
        event.preventDefault()
        this.clearSearch()
        this.searchInputTarget.blur()
      }
    }
    
    document.addEventListener("keydown", this.keyboardHandler)
  }
  
  removeKeyboardShortcuts() {
    if (this.keyboardHandler) {
      document.removeEventListener("keydown", this.keyboardHandler)
    }
  }
  
  // Called after Turbo Frame renders
  frameRendered(event) {
    // Remove loading state
    this.setLoadingState(false)
    
    // Update clear button visibility
    this.updateClearButtonVisibility()
    
    // Announce results to screen readers
    this.announceResults()
  }
  
  // Announce search results for accessibility
  announceResults() {
    const resultsCount = this.element.querySelector("[data-results-count]")
    if (resultsCount) {
      const announcement = document.createElement("div")
      announcement.setAttribute("role", "status")
      announcement.setAttribute("aria-live", "polite")
      announcement.className = "sr-only"
      announcement.textContent = resultsCount.textContent
      
      document.body.appendChild(announcement)
      setTimeout(() => announcement.remove(), 1000)
    }
  }
  
  // Handle Turbo form submission events
  formSubmitStart(event) {
    this.setLoadingState(true)
  }
  
  formSubmitEnd(event) {
    if (event.detail.success) {
      this.setLoadingState(false)
      this.updateClearButtonVisibility()
    }
  }
}