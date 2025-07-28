import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["toggle"]
  static values = { 
    theme: String,
    storageKey: { type: String, default: "creative-theme" }
  }

  connect() {
    this.initializeTheme()
    this.updateToggleState()
  }

  themeValueChanged() {
    this.applyTheme()
    this.updateToggleState()
  }

  toggle() {
    const newTheme = this.themeValue === 'dark' ? 'light' : 'dark'
    this.themeValue = newTheme
    localStorage.setItem(this.storageKeyValue, newTheme)
  }

  initializeTheme() {
    // Priority: 1. Stored preference, 2. System preference, 3. Light default
    const storedTheme = localStorage.getItem(this.storageKeyValue)
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    
    if (storedTheme) {
      this.themeValue = storedTheme
    } else if (systemPrefersDark) {
      this.themeValue = 'dark'
    } else {
      this.themeValue = 'light'
    }

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem(this.storageKeyValue)) {
        this.themeValue = e.matches ? 'dark' : 'light'
      }
    })
  }

  applyTheme() {
    const html = document.documentElement
    
    if (this.themeValue === 'dark') {
      html.classList.add('dark')
    } else {
      html.classList.remove('dark')
    }

    // Dispatch custom event for other components
    this.dispatch('changed', { 
      detail: { 
        theme: this.themeValue,
        isDark: this.themeValue === 'dark'
      } 
    })
  }

  updateToggleState() {
    if (this.hasToggleTarget) {
      const isDark = this.themeValue === 'dark'
      const toggle = this.toggleTarget
      
      // Update aria-pressed for accessibility
      toggle.setAttribute('aria-pressed', isDark.toString())
      
      // Update visual state
      toggle.classList.toggle('active', isDark)
      toggle.classList.toggle('bg-creative-primary-500', isDark)
      toggle.classList.toggle('bg-creative-neutral-300', !isDark)
      
      // Update icon or text if present
      const icon = toggle.querySelector('[data-theme-icon]')
      const text = toggle.querySelector('[data-theme-text]')
      
      if (icon) {
        icon.innerHTML = isDark ? this.moonIcon() : this.sunIcon()
      }
      
      if (text) {
        text.textContent = isDark ? 'Dark' : 'Light'
      }
    }
  }

  sunIcon() {
    return `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
      </svg>
    `
  }

  moonIcon() {
    return `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
      </svg>
    `
  }

  // Helper method to get current theme for other controllers
  get isDark() {
    return this.themeValue === 'dark'
  }

  // Method to programmatically set theme
  setTheme(theme) {
    if (['light', 'dark'].includes(theme)) {
      this.themeValue = theme
      localStorage.setItem(this.storageKeyValue, theme)
    }
  }
}