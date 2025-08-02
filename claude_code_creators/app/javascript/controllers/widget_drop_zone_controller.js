import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="widget-drop-zone"
export default class extends Controller {
  static targets = [
    "dropZone", "content", "instructions", "icon", "title", "description",
    "overlay", "pulseAnimation", "successFeedback", "errorFeedback", 
    "dropMessage", "errorMessage"
  ]
  
  static values = {
    target: String,
    acceptedTypes: Array,
    allowMultiple: Boolean,
    position: String
  }

  connect() {
    this.dragCounter = 0
    this.originalClasses = this.dropZoneTarget.className
    
    // Add global drag listeners to track drag state
    document.addEventListener("dragstart", this.handleGlobalDragStart.bind(this))
    document.addEventListener("dragend", this.handleGlobalDragEnd.bind(this))
  }

  disconnect() {
    document.removeEventListener("dragstart", this.handleGlobalDragStart.bind(this))
    document.removeEventListener("dragend", this.handleGlobalDragEnd.bind(this))
  }

  // Global drag start - prepare all drop zones
  handleGlobalDragStart(event) {
    const dragData = this.extractDragData(event)
    
    if (this.isAcceptableType(dragData.type)) {
      this.showAsAvailable()
    } else {
      this.showAsUnavailable()
    }
  }

  // Global drag end - reset all drop zones
  handleGlobalDragEnd(event) {
    this.resetToDefault()
  }

  // Handle drag over (required to allow drop)
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  // Handle drag enter
  handleDragEnter(event) {
    event.preventDefault()
    this.dragCounter++
    
    const dragData = this.extractDragData(event)
    
    if (this.isAcceptableType(dragData.type)) {
      this.showAsActive()
      this.updateDropMessage(dragData)
    }
  }

  // Handle drag leave
  handleDragLeave(event) {
    event.preventDefault()
    this.dragCounter--
    
    // Only hide overlay when we've left the drop zone entirely
    if (this.dragCounter === 0) {
      this.hideOverlay()
    }
  }

  // Handle drop
  handleDrop(event) {
    event.preventDefault()
    this.dragCounter = 0
    
    const dragData = this.extractDragData(event)
    
    if (!this.isAcceptableType(dragData.type)) {
      this.showError("This type of item is not accepted here")
      return
    }

    this.hideOverlay()
    this.processDrop(dragData, event)
  }

  // Extract data from drag event
  extractDragData(event) {
    const dataTransfer = event.dataTransfer
    
    // Try to get structured data first
    let dragData = {}
    
    try {
      const jsonData = dataTransfer.getData("application/json")
      if (jsonData) {
        dragData = JSON.parse(jsonData)
      }
    } catch (e) {
      // Fallback to individual data types
    }

    // Fallback to text data
    if (!dragData.type) {
      dragData = {
        type: dataTransfer.getData("text/type") || "unknown",
        id: dataTransfer.getData("text/id"),
        content: dataTransfer.getData("text/plain"),
        ...dragData
      }
    }

    return dragData
  }

  // Check if the dragged type is acceptable
  isAcceptableType(type) {
    if (!type) return false
    return this.acceptedTypesValue.includes(type) || this.acceptedTypesValue.includes("*")
  }

  // Show drop zone as available for dropping
  showAsAvailable() {
    this.dropZoneTarget.classList.add("drop-zone-available")
    
    if (this.hasPulseAnimationTarget) {
      this.pulseAnimationTarget.style.display = "block"
    }
  }

  // Show drop zone as unavailable
  showAsUnavailable() {
    this.dropZoneTarget.classList.add("drop-zone-unavailable")
    this.dropZoneTarget.style.opacity = "0.5"
  }

  // Show drop zone as active (being hovered)
  showAsActive() {
    this.dropZoneTarget.className = this.originalClasses + " " + this.getActiveClasses()
    
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("opacity-0", "invisible")
      this.overlayTarget.classList.add("opacity-100", "visible")
    }

    if (this.hasInstructionsTarget) {
      this.instructionsTarget.style.opacity = "0.3"
    }
  }

  // Hide overlay and return to default state
  hideOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("opacity-0", "invisible")
      this.overlayTarget.classList.remove("opacity-100", "visible")
    }

    if (this.hasInstructionsTarget) {
      this.instructionsTarget.style.opacity = "1"
    }
  }

  // Reset to default state
  resetToDefault() {
    this.dropZoneTarget.className = this.originalClasses
    this.dropZoneTarget.style.opacity = "1"
    
    if (this.hasPulseAnimationTarget) {
      this.pulseAnimationTarget.style.display = "none"
    }
    
    this.hideOverlay()
  }

  // Get active state classes
  getActiveClasses() {
    return [
      "border-creative-primary-500",
      "dark:border-creative-primary-400",
      "bg-creative-primary-100",
      "dark:bg-creative-primary-800/30",
      "shadow-creative-xl",
      "dark:shadow-creative-dark-xl",
      "scale-105"
    ].join(" ")
  }

  // Update drop message based on drag data
  updateDropMessage(dragData) {
    if (this.hasDropMessageTarget) {
      const itemType = dragData.type ? dragData.type.replace("_", " ") : "item"
      const message = this.allowMultipleValue 
        ? `Drop your ${itemType}${dragData.count > 1 ? "s" : ""} here`
        : `Drop your ${itemType} here`
      
      this.dropMessageTarget.textContent = message
    }
  }

  // Process the actual drop
  async processDrop(dragData, event) {
    try {
      // Show loading state
      this.showProcessing()
      
      // Dispatch custom event for handling by parent controllers
      const dropEvent = new CustomEvent("widget-drop-zone:dropped", {
        detail: {
          data: dragData,
          target: this.targetValue,
          dropZone: this.element,
          originalEvent: event
        },
        bubbles: true,
        cancelable: true
      })
      
      const handled = this.element.dispatchEvent(dropEvent)
      
      if (!handled) {
        // If no parent handled the event, try to handle it ourselves
        await this.handleDropLocally(dragData)
      }
      
      this.showSuccess()
      
    } catch (error) {
      console.error("Drop processing failed:", error)
      this.showError(error.message || "Failed to process dropped item")
    }
  }

  // Handle drop locally (fallback)
  async handleDropLocally(dragData) {
    // This would need to be customized based on your application logic
    // For now, we'll just make a simple POST request
    
    const response = await fetch("/drop_zone_handler", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
      },
      body: JSON.stringify({
        target: this.targetValue,
        data: dragData
      })
    })
    
    if (!response.ok) {
      throw new Error(`Server error: ${response.status}`)
    }
    
    return response.json()
  }

  // Show processing state
  showProcessing() {
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = "Processing..."
    }
    
    if (this.hasIconTarget) {
      this.iconTarget.classList.add("animate-spin")
    }
  }

  // Show success feedback
  showSuccess(message = "Successfully dropped!") {
    if (this.hasSuccessFeedbackTarget) {
      this.successFeedbackTarget.classList.remove("opacity-0", "invisible")
      this.successFeedbackTarget.classList.add("opacity-100", "visible")
      
      setTimeout(() => {
        this.hideSuccess()
      }, 2000)
    }
    
    this.resetToDefault()
  }

  // Hide success feedback
  hideSuccess() {
    if (this.hasSuccessFeedbackTarget) {
      this.successFeedbackTarget.classList.add("opacity-0", "invisible")
      this.successFeedbackTarget.classList.remove("opacity-100", "visible")
    }
  }

  // Show error feedback
  showError(message) {
    if (this.hasErrorFeedbackTarget) {
      if (this.hasErrorMessageTarget) {
        this.errorMessageTarget.textContent = message
      }
      
      this.errorFeedbackTarget.classList.remove("opacity-0", "invisible")
      this.errorFeedbackTarget.classList.add("opacity-100", "visible")
      
      setTimeout(() => {
        this.hideError()
      }, 3000)
    }
    
    this.resetToDefault()
  }

  // Hide error feedback
  hideError() {
    if (this.hasErrorFeedbackTarget) {
      this.errorFeedbackTarget.classList.add("opacity-0", "invisible")
      this.errorFeedbackTarget.classList.remove("opacity-100", "visible")
    }
  }
}