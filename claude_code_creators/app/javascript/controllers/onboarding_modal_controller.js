import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="onboarding-modal"
export default class extends Controller {
  static targets = ["modal", "backdrop", "content", "stepContent"]
  static values = { 
    currentStep: Number,
    totalSteps: Number,
    userId: Number
  }

  connect() {
    // Bind keyboard event listeners
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    
    // Add entrance animation
    this.animateEntrance()
    
    // Track onboarding analytics
    this.trackEvent("onboarding_started", { step: this.currentStepValue })
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  // Animate modal entrance
  animateEntrance() {
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "scale(0.9) translateY(20px)"
      this.contentTarget.style.opacity = "0"
      
      requestAnimationFrame(() => {
        this.contentTarget.style.transition = "all 300ms cubic-bezier(0.4, 0, 0.2, 1)"
        this.contentTarget.style.transform = "scale(1) translateY(0)"
        this.contentTarget.style.opacity = "1"
      })
    }
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    if (!this.modalTarget.style.display || this.modalTarget.style.display === "none") return
    
    switch (event.key) {
    case "Escape":
      event.preventDefault()
      this.close()
      break
    case "ArrowLeft":
      if (event.altKey || event.metaKey) {
        event.preventDefault()
        this.previousStep()
      }
      break
    case "ArrowRight":
    case "Enter":
      if (event.altKey || event.metaKey || event.key === "Enter") {
        event.preventDefault()
        this.nextStep()
      }
      break
    }
  }

  // Navigate to next step
  nextStep() {
    if (this.currentStepValue >= this.totalStepsValue) {
      this.completeOnboarding()
      return
    }

    this.trackEvent("onboarding_step_completed", { 
      step: this.currentStepValue,
      next_step: this.currentStepValue + 1
    })

    this.animateStepTransition(() => {
      this.currentStepValue = this.currentStepValue + 1
      this.updateStepContent()
    })
  }

  // Navigate to previous step
  previousStep() {
    if (this.currentStepValue <= 1) return

    this.trackEvent("onboarding_step_back", { 
      step: this.currentStepValue,
      previous_step: this.currentStepValue - 1 
    })

    this.animateStepTransition(() => {
      this.currentStepValue = this.currentStepValue - 1
      this.updateStepContent()
    })
  }

  // Animate step transition
  animateStepTransition(callback) {
    if (this.hasStepContentTarget) {
      // Fade out current content
      this.stepContentTarget.style.transition = "opacity 150ms ease-out, transform 150ms ease-out"
      this.stepContentTarget.style.opacity = "0"
      this.stepContentTarget.style.transform = "translateX(-20px)"
      
      setTimeout(() => {
        callback()
        
        // Fade in new content
        this.stepContentTarget.style.transform = "translateX(20px)"
        requestAnimationFrame(() => {
          this.stepContentTarget.style.opacity = "1"
          this.stepContentTarget.style.transform = "translateX(0)"
        })
      }, 150)
    } else {
      callback()
    }
  }

  // Update step content via Turbo Stream
  updateStepContent() {
    // This would trigger a Turbo Stream update to refresh the modal content
    // For now, we'll reload the component
    this.requestStepUpdate()
  }

  // Request step update from server
  async requestStepUpdate() {
    try {
      const response = await fetch("/onboarding/step", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          step: this.currentStepValue,
          user_id: this.userIdValue
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Failed to update onboarding step:", error)
    }
  }

  // Complete onboarding
  async completeOnboarding() {
    this.trackEvent("onboarding_completed", { 
      total_steps: this.totalStepsValue 
    })

    try {
      // Mark onboarding as completed on server
      await fetch("/onboarding/complete", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          user_id: this.userIdValue
        })
      })
    } catch (error) {
      console.error("Failed to complete onboarding:", error)
    }

    this.close()
  }

  // Skip onboarding
  async skipOnboarding() {
    this.trackEvent("onboarding_skipped", { 
      step: this.currentStepValue 
    })

    try {
      // Mark onboarding as skipped on server
      await fetch("/onboarding/skip", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          user_id: this.userIdValue
        })
      })
    } catch (error) {
      console.error("Failed to skip onboarding:", error)
    }

    this.close()
  }

  // Close modal
  close() {
    this.trackEvent("onboarding_closed", { 
      step: this.currentStepValue 
    })

    this.animateExit(() => {
      this.modalTarget.style.display = "none"
      
      // Dispatch close event
      this.dispatch("closed", {
        detail: { step: this.currentStepValue }
      })
    })
  }

  // Animate modal exit
  animateExit(callback) {
    if (this.hasContentTarget && this.hasBackdropTarget) {
      this.contentTarget.style.transition = "all 300ms cubic-bezier(0.4, 0, 0.2, 1)"
      this.backdropTarget.style.transition = "opacity 300ms ease-out"
      
      this.contentTarget.style.transform = "scale(0.9) translateY(20px)"
      this.contentTarget.style.opacity = "0"
      this.backdropTarget.style.opacity = "0"
      
      setTimeout(callback, 300)
    } else {
      callback()
    }
  }

  // Handle action button clicks in final step
  handleActionClick(event) {
    const action = event.currentTarget.dataset.onboardingAction
    
    this.trackEvent("onboarding_action_clicked", {
      action: action,
      step: this.currentStepValue
    })

    // Add loading state to clicked button
    const button = event.currentTarget
    button.style.transform = "scale(0.98)"
    
    setTimeout(() => {
      button.style.transform = "scale(1)"
      this.completeOnboarding()
    }, 150)
  }

  // Track analytics events
  trackEvent(eventName, properties = {}) {
    // You can integrate with your analytics service here
    if (window.gtag) {
      window.gtag("event", eventName, properties)
    }
    
    if (window.mixpanel) {
      window.mixpanel.track(eventName, properties)
    }
    
    // Also log to console for debugging
    console.log(`Onboarding Event: ${eventName}`, properties)
  }

  // Show modal (called externally)
  show() {
    this.modalTarget.style.display = "flex"
    this.animateEntrance()
    this.trackEvent("onboarding_shown")
  }

  // Update current step value
  currentStepValueChanged() {
    // This is called automatically when the value changes
    this.updateProgressIndicators()
  }

  // Update progress indicators
  updateProgressIndicators() {
    const progressSteps = this.element.querySelectorAll("[data-step-number]")
    const progressLines = this.element.querySelectorAll("[data-progress-line]")
    
    progressSteps.forEach((step, index) => {
      const stepNumber = index + 1
      const stepElement = step
      
      if (stepNumber < this.currentStepValue) {
        stepElement.classList.add("bg-creative-secondary-500", "text-white")
        stepElement.classList.remove("bg-creative-primary-500", "bg-creative-neutral-200")
        stepElement.innerHTML = "<svg class=\"w-4 h-4\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 13l4 4L19 7\"/></svg>"
      } else if (stepNumber === this.currentStepValue) {
        stepElement.classList.add("bg-creative-primary-500", "text-white", "ring-4", "ring-creative-primary-200")
        stepElement.classList.remove("bg-creative-secondary-500", "bg-creative-neutral-200")
        stepElement.textContent = stepNumber
      } else {
        stepElement.classList.add("bg-creative-neutral-200", "text-creative-neutral-600")
        stepElement.classList.remove("bg-creative-primary-500", "bg-creative-secondary-500", "text-white", "ring-4")
        stepElement.textContent = stepNumber
      }
    })
    
    progressLines.forEach((line, index) => {
      const stepNumber = index + 1
      
      if (stepNumber < this.currentStepValue) {
        line.classList.add("bg-creative-secondary-500")
        line.classList.remove("bg-creative-neutral-200")
      } else {
        line.classList.add("bg-creative-neutral-200")
        line.classList.remove("bg-creative-secondary-500")
      }
    })
  }
}