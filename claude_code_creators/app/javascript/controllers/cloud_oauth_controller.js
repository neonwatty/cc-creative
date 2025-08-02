import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cloud-oauth"
export default class extends Controller {
  static targets = ["trigger", "status"]
  static values = { 
    provider: String,
    authUrl: String,
    callbackUrl: String,
    width: { type: Number, default: 600 },
    height: { type: Number, default: 700 }
  }

  connect() {
    // Listen for messages from OAuth popup
    this.boundHandleMessage = this.handleMessage.bind(this)
    window.addEventListener("message", this.boundHandleMessage)
    
    // Track popup reference
    this.popup = null
    this.pollInterval = null
  }

  disconnect() {
    window.removeEventListener("message", this.boundHandleMessage)
    this.closePopup()
  }

  // Initiate OAuth flow with popup window
  authorize(event) {
    event.preventDefault()
    
    if (this.popup && !this.popup.closed) {
      this.popup.focus()
      return
    }

    this.updateStatus("connecting", `Connecting to ${this.providerValue}...`)
    this.disableTrigger(true)

    // Calculate popup position (center of screen)
    const left = (screen.width / 2) - (this.widthValue / 2)
    const top = (screen.height / 2) - (this.heightValue / 2)

    // Open OAuth popup
    this.popup = window.open(
      this.authUrlValue,
      `oauth_${this.providerValue}`,
      `width=${this.widthValue},height=${this.heightValue},left=${left},top=${top},scrollbars=yes,resizable=yes`
    )

    if (!this.popup) {
      this.handleError("Popup blocked. Please allow popups for this site.")
      return
    }

    // Poll for popup closure (fallback for cases where postMessage doesn't work)
    this.startPolling()

    // Set timeout for authentication
    this.authTimeout = setTimeout(() => {
      if (this.popup && !this.popup.closed) {
        this.handleError("Authentication timed out. Please try again.")
        this.closePopup()
      }
    }, 300000) // 5 minute timeout
  }

  // Handle messages from OAuth popup
  handleMessage(event) {
    // Verify origin for security
    if (!this.isValidOrigin(event.origin)) {
      return
    }

    const { type, provider, status, error, data } = event.data

    if (type !== "oauth_result" || provider !== this.providerValue) {
      return
    }

    if (status === "success") {
      this.handleSuccess(data)
    } else if (status === "error") {
      this.handleError(error || "Authentication failed")
    }
  }

  // Handle successful OAuth
  handleSuccess(data) {
    this.updateStatus("success", `Successfully connected to ${this.providerValue}`)
    this.closePopup()
    
    // Dispatch custom event for parent components
    this.dispatch("success", {
      detail: {
        provider: this.providerValue,
        data: data
      }
    })

    // Refresh the page or update UI after short delay
    setTimeout(() => {
      if (data?.redirect) {
        window.location.href = data.redirect
      } else {
        window.location.reload()
      }
    }, 1500)
  }

  // Handle OAuth errors
  handleError(error) {
    this.updateStatus("error", error)
    this.disableTrigger(false)
    this.closePopup()
    
    // Dispatch error event
    this.dispatch("error", {
      detail: {
        provider: this.providerValue,
        error: error
      }
    })
  }

  // Update status display
  updateStatus(type, message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.className = `oauth-status oauth-status--${type}`
    this.statusTarget.textContent = message
    this.statusTarget.style.display = "block"

    // Auto-hide success/error messages
    if (type === "success" || type === "error") {
      setTimeout(() => {
        if (this.hasStatusTarget) {
          this.statusTarget.style.display = "none"
        }
      }, 5000)
    }
  }

  // Enable/disable trigger button
  disableTrigger(disabled) {
    if (this.hasTriggerTarget) {
      this.triggerTarget.disabled = disabled
      this.triggerTarget.classList.toggle("loading", disabled)
    }
  }

  // Close OAuth popup
  closePopup() {
    if (this.popup && !this.popup.closed) {
      this.popup.close()
    }
    this.popup = null
    
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
    
    if (this.authTimeout) {
      clearTimeout(this.authTimeout)
      this.authTimeout = null
    }
  }

  // Start polling for popup closure
  startPolling() {
    this.pollInterval = setInterval(() => {
      if (this.popup && this.popup.closed) {
        // Popup was closed without successful auth
        this.handleError("Authentication cancelled")
      }
    }, 1000)
  }

  // Validate message origin for security
  isValidOrigin(origin) {
    const allowedOrigins = [
      window.location.origin,
      "https://accounts.google.com",
      "https://www.dropbox.com",
      "https://api.notion.com"
    ]
    
    return allowedOrigins.includes(origin)
  }

  // Retry authentication
  retry(event) {
    event.preventDefault()
    this.authorize(event)
  }

  // Cancel authentication
  cancel(event) {
    event.preventDefault()
    this.closePopup()
    this.updateStatus("cancelled", "Authentication cancelled")
    this.disableTrigger(false)
  }
}