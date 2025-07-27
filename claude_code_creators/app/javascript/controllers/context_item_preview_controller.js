import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="context-item-preview"
export default class extends Controller {
  static targets = ["backdrop", "panel", "content", "insertButton", "copyButton"]
  static values = { 
    id: Number,
    type: String,
    contentType: String,
    modalId: String
  }

  connect() {
    this.setupKeyboardHandlers()
    this.setupFocusManagement()
    this.highlightCodeIfNeeded()
  }

  disconnect() {
    this.removeKeyboardHandlers()
  }

  close() {
    this.element.classList.add("hidden")
    this.restorePreviousFocus()
    this.dispatch("closed", { detail: { contextItemId: this.idValue } })
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  insertContent() {
    const content = this.getPlainTextContent()
    
    // Dispatch custom event with content for parent components to handle
    this.dispatch("insert", { 
      detail: { 
        content: content,
        contextItemId: this.idValue,
        itemType: this.typeValue,
        contentType: this.contentTypeValue
      } 
    })
    
    // Try to find Trix editor and insert content directly
    this.insertIntoTrixEditor(content)
    
    this.close()
  }

  copyContent() {
    const content = this.getPlainTextContent()
    
    if (navigator.clipboard && window.isSecureContext) {
      // Use modern clipboard API
      navigator.clipboard.writeText(content).then(() => {
        this.showCopyFeedback()
        this.dispatch("copied", { detail: { contextItemId: this.idValue } })
      }).catch(err => {
        console.error('Failed to copy content:', err)
        this.fallbackCopy(content)
      })
    } else {
      // Fallback for older browsers
      this.fallbackCopy(content)
    }
  }

  // Private methods

  getPlainTextContent() {
    // Get the raw content from the context item
    const contentElement = this.contentTarget
    
    if (this.contentTypeValue === 'code') {
      // For code content, get text from the code element
      const codeElement = contentElement.querySelector('code')
      return codeElement ? codeElement.textContent : contentElement.textContent
    } else {
      // For other content types, get plain text
      return contentElement.textContent.trim()
    }
  }

  insertIntoTrixEditor(content) {
    // Look for active Trix editor
    const trixEditor = document.querySelector('trix-editor')
    if (trixEditor && trixEditor.editor) {
      const position = trixEditor.editor.getPosition()
      trixEditor.editor.insertString(content)
      trixEditor.editor.setSelectedRange([position, position + content.length])
    }
  }

  fallbackCopy(content) {
    // Create temporary textarea for copying
    const textarea = document.createElement('textarea')
    textarea.value = content
    textarea.style.position = 'fixed'
    textarea.style.left = '-999999px'
    textarea.style.top = '-999999px'
    document.body.appendChild(textarea)
    textarea.select()
    
    try {
      document.execCommand('copy')
      this.showCopyFeedback()
      this.dispatch("copied", { detail: { contextItemId: this.idValue } })
    } catch (err) {
      console.error('Fallback copy failed:', err)
    } finally {
      document.body.removeChild(textarea)
    }
  }

  showCopyFeedback() {
    const button = this.copyButtonTarget
    const originalText = button.textContent
    
    button.textContent = 'Copied!'
    button.classList.add('bg-green-50', 'text-green-700')
    
    setTimeout(() => {
      button.textContent = originalText
      button.classList.remove('bg-green-50', 'text-green-700')
    }, 2000)
  }

  setupKeyboardHandlers() {
    this.keydownHandler = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.keydownHandler)
  }

  removeKeyboardHandlers() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      event.preventDefault()
      this.close()
    }
    
    // Handle Tab key for focus trapping
    if (event.key === 'Tab') {
      this.trapFocus(event)
    }
  }

  setupFocusManagement() {
    this.previouslyFocusedElement = document.activeElement
    
    // Focus the modal panel
    requestAnimationFrame(() => {
      this.panelTarget.focus()
    })
  }

  restorePreviousFocus() {
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus()
    }
  }

  trapFocus(event) {
    const focusableElements = this.panelTarget.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]
    
    if (event.shiftKey) {
      if (document.activeElement === firstElement) {
        event.preventDefault()
        lastElement.focus()
      }
    } else {
      if (document.activeElement === lastElement) {
        event.preventDefault()
        firstElement.focus()
      }
    }
  }

  highlightCodeIfNeeded() {
    if (this.contentTypeValue === 'code') {
      // If you have a syntax highlighting library like Prism.js or highlight.js
      // you can trigger highlighting here
      const codeBlocks = this.contentTarget.querySelectorAll('pre code')
      codeBlocks.forEach(block => {
        // Example for Prism.js: Prism.highlightElement(block)
        // Example for highlight.js: hljs.highlightElement(block)
        
        // For now, just add a class to indicate it's ready for highlighting
        block.classList.add('syntax-ready')
      })
    }
  }
}