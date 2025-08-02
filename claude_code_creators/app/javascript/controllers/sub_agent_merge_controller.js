import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "mergeButton", "cancelButton", "confirmButton", "contentPreview", "loadingOverlay"]
  static values = { 
    documentId: Number,
    subAgentId: Number,
    mergeUrl: String,
    subAgentContent: String
  }
  
  connect() {
    console.log("SubAgentMergeController connected")
    this.setupKeyboardShortcuts()
  }
  
  disconnect() {
    this.removeKeyboardShortcuts()
  }
  
  // Show merge dialog
  showDialog(event) {
    event?.preventDefault()
    
    if (!this.hasDialogTarget) return
    
    // Update content preview if available
    if (this.hasContentPreviewTarget && this.subAgentContentValue) {
      this.contentPreviewTarget.innerHTML = this.formatContentPreview(this.subAgentContentValue)
    }
    
    // Show dialog with animation
    this.dialogTarget.classList.remove("hidden")
    this.dialogTarget.classList.add("flex")
    
    // Animate backdrop
    const backdrop = this.dialogTarget.querySelector(".backdrop")
    if (backdrop) {
      backdrop.style.opacity = "0"
      requestAnimationFrame(() => {
        backdrop.style.transition = "opacity 0.3s ease-out"
        backdrop.style.opacity = "1"
      })
    }
    
    // Animate dialog content
    const content = this.dialogTarget.querySelector(".dialog-content")
    if (content) {
      content.style.transform = "scale(0.95)"
      content.style.opacity = "0"
      requestAnimationFrame(() => {
        content.style.transition = "all 0.3s ease-out"
        content.style.transform = "scale(1)"
        content.style.opacity = "1"
      })
    }
    
    // Focus confirm button for accessibility
    if (this.hasConfirmButtonTarget) {
      setTimeout(() => this.confirmButtonTarget.focus(), 100)
    }
  }
  
  // Hide merge dialog
  hideDialog(event) {
    event?.preventDefault()
    
    if (!this.hasDialogTarget) return
    
    // Animate out
    const backdrop = this.dialogTarget.querySelector(".backdrop")
    const content = this.dialogTarget.querySelector(".dialog-content")
    
    if (backdrop) {
      backdrop.style.transition = "opacity 0.2s ease-in"
      backdrop.style.opacity = "0"
    }
    
    if (content) {
      content.style.transition = "all 0.2s ease-in"
      content.style.transform = "scale(0.95)"
      content.style.opacity = "0"
    }
    
    // Hide after animation
    setTimeout(() => {
      this.dialogTarget.classList.add("hidden")
      this.dialogTarget.classList.remove("flex")
    }, 200)
  }
  
  // Handle merge confirmation
  async confirmMerge(event) {
    event?.preventDefault()
    
    // Show loading state
    this.setLoadingState(true)
    
    try {
      const response = await fetch(this.mergeUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          merge: true
        })
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      // Hide dialog
      this.hideDialog()
      
      // Show success notification
      this.showNotification("Content merged successfully!", "success")
      
      // Reload page or update UI based on response
      if (data.redirect_to) {
        // Use Turbo to navigate
        window.Turbo.visit(data.redirect_to)
      } else {
        // Refresh the current page
        window.location.reload()
      }
      
    } catch (error) {
      console.error("Failed to merge content:", error)
      this.showNotification("Failed to merge content. Please try again.", "error")
      this.setLoadingState(false)
    }
  }
  
  // Loading state management
  setLoadingState(loading) {
    if (this.hasConfirmButtonTarget) {
      this.confirmButtonTarget.disabled = loading
      
      if (loading) {
        this.confirmButtonTarget.innerHTML = `
          <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Merging...
        `
      } else {
        this.confirmButtonTarget.innerHTML = "Merge Content"
      }
    }
    
    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.disabled = loading
    }
    
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.style.display = loading ? "flex" : "none"
    }
  }
  
  // Format content preview
  formatContentPreview(content) {
    if (!content) return "<p class=\"text-gray-500\">No content to preview</p>"
    
    // Truncate long content
    const maxLength = 500
    const truncated = content.length > maxLength 
      ? content.substring(0, maxLength) + "..." 
      : content
    
    // Convert to HTML with line breaks
    return truncated
      .split("\n")
      .map(line => `<p class="mb-2">${this.escapeHtml(line)}</p>`)
      .join("")
  }
  
  // Show notification
  showNotification(message, type = "info") {
    const notification = document.createElement("div")
    notification.className = `fixed top-4 right-4 z-50 px-6 py-3 rounded-lg text-white font-medium shadow-lg transition-all duration-300 ${
      type === "success" ? "bg-green-500" : 
        type === "error" ? "bg-red-500" : 
          "bg-blue-500"
    }`
    notification.style.transform = "translateX(400px)"
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Animate in
    requestAnimationFrame(() => {
      notification.style.transform = "translateX(0)"
    })
    
    // Auto dismiss
    setTimeout(() => {
      notification.style.transform = "translateX(400px)"
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
  
  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    this.keyboardHandler = (event) => {
      // Escape to close dialog
      if (event.key === "Escape" && !this.dialogTarget?.classList.contains("hidden")) {
        event.preventDefault()
        this.hideDialog()
      }
      
      // Enter to confirm when dialog is open
      if (event.key === "Enter" && !this.dialogTarget?.classList.contains("hidden")) {
        if (document.activeElement === this.confirmButtonTarget) {
          event.preventDefault()
          this.confirmMerge()
        }
      }
    }
    
    document.addEventListener("keydown", this.keyboardHandler)
  }
  
  removeKeyboardShortcuts() {
    if (this.keyboardHandler) {
      document.removeEventListener("keydown", this.keyboardHandler)
    }
  }
  
  // Click outside to close
  handleBackdropClick(event) {
    if (event.target === event.currentTarget) {
      this.hideDialog()
    }
  }
  
  // Utility methods
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}