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
    
    // Also dispatch on document for global listeners
    document.dispatchEvent(new CustomEvent("context-item-preview:closed", {
      detail: { contextItemId: this.idValue }
    }))
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  insertContent() {
    const content = this.getContentForInsertion()
    
    // Dispatch custom event with content for parent components to handle
    this.dispatch("insert", { 
      detail: { 
        content: content,
        contextItemId: this.idValue,
        itemType: this.typeValue,
        contentType: this.contentTypeValue
      } 
    })
    
    // Also dispatch on document for global listeners
    document.dispatchEvent(new CustomEvent("context-item-preview:insert", {
      detail: {
        content: content,
        contextItemId: this.idValue,
        itemType: this.typeValue,
        contentType: this.contentTypeValue
      }
    }))
    
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
        console.error("Failed to copy content:", err)
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
    
    if (this.contentTypeValue === "code") {
      // For code content, get text from the code element
      const codeElement = contentElement.querySelector("code")
      return codeElement ? codeElement.textContent : contentElement.textContent
    } else {
      // For other content types, get plain text
      return contentElement.textContent.trim()
    }
  }
  
  getContentForInsertion() {
    // Get content formatted appropriately for insertion
    const rawContent = this.getPlainTextContent()
    
    // Format content based on type and context
    switch (this.contentTypeValue) {
    case "code":
      // Detect language and wrap in code block
      const language = this.detectLanguageFromContent()
      return `\n\`\`\`${language}\n${rawContent}\n\`\`\`\n`
        
    case "snippet":
      // Wrap in inline code
      return `\`${rawContent}\``
        
    case "note":
    case "reference":
      // Add as blockquote for notes and references
      return `\n> ${rawContent}\n`
        
    case "text":
    default:
      // Insert as plain text with line breaks
      return `\n${rawContent}\n`
    }
  }
  
  detectLanguageFromContent() {
    // Try to detect language from the context item
    const contentElement = this.contentTarget
    const codeElement = contentElement.querySelector("code")
    
    if (codeElement) {
      // Check for language class
      const classList = Array.from(codeElement.classList)
      for (const className of classList) {
        if (className.startsWith("language-")) {
          return className.replace("language-", "")
        }
      }
      
      // Check data attributes
      const dataLang = codeElement.getAttribute("data-language")
      if (dataLang) {
        return dataLang
      }
    }
    
    // Check the item type for hints
    if (this.typeValue) {
      const typeHints = {
        "javascript": "javascript",
        "ruby": "ruby",
        "python": "python",
        "html": "html",
        "css": "css",
        "sql": "sql"
      }
      
      for (const [hint, lang] of Object.entries(typeHints)) {
        if (this.typeValue.toLowerCase().includes(hint)) {
          return lang
        }
      }
    }
    
    // Default fallback
    return ""
  }

  insertIntoTrixEditor(content) {
    // Look for active Trix editor
    const trixEditor = document.querySelector("trix-editor")
    if (trixEditor && trixEditor.editor) {
      // Store the current state for undo functionality
      const currentPosition = trixEditor.editor.getPosition()
      
      // Create an undo entry before making changes
      trixEditor.editor.recordUndoEntry("Insert Context Item")
      
      // Insert the content
      trixEditor.editor.insertString(content)
      
      // Set selection to the inserted content
      trixEditor.editor.setSelectedRange([currentPosition, currentPosition + content.length])
      
      // Trigger change event to notify other controllers
      trixEditor.dispatchEvent(new CustomEvent("trix-change", {
        bubbles: true,
        detail: { insertedContent: content, insertedFrom: "context-item" }
      }))
      
      // Focus the editor
      trixEditor.focus()
    }
  }

  fallbackCopy(content) {
    // Create temporary textarea for copying
    const textarea = document.createElement("textarea")
    textarea.value = content
    textarea.style.position = "fixed"
    textarea.style.left = "-999999px"
    textarea.style.top = "-999999px"
    document.body.appendChild(textarea)
    textarea.select()
    
    try {
      document.execCommand("copy")
      this.showCopyFeedback()
      this.dispatch("copied", { detail: { contextItemId: this.idValue } })
    } catch (err) {
      console.error("Fallback copy failed:", err)
    } finally {
      document.body.removeChild(textarea)
    }
  }

  showCopyFeedback() {
    const button = this.copyButtonTarget
    const originalText = button.textContent
    
    button.textContent = "Copied!"
    button.classList.add("bg-green-50", "text-green-700")
    
    setTimeout(() => {
      button.textContent = originalText
      button.classList.remove("bg-green-50", "text-green-700")
    }, 2000)
  }

  setupKeyboardHandlers() {
    this.keydownHandler = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.keydownHandler)
  }

  removeKeyboardHandlers() {
    if (this.keydownHandler) {
      document.removeEventListener("keydown", this.keydownHandler)
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
    
    // Handle Cmd/Ctrl+Shift+I for insert
    if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key === "I") {
      event.preventDefault()
      this.insertContent()
    }
    
    // Handle Tab key for focus trapping
    if (event.key === "Tab") {
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
      "button, [href], input, select, textarea, [tabindex]:not([tabindex=\"-1\"])"
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
    if (this.contentTypeValue === "code" && window.Prism) {
      // Use Prism.js for syntax highlighting
      const codeBlocks = this.contentTarget.querySelectorAll("pre code")
      codeBlocks.forEach(block => {
        // Detect language from class or data attribute
        const language = this.detectLanguage(block)
        if (language) {
          block.className = `language-${language}`
        }
        
        // Apply Prism highlighting
        try {
          window.Prism.highlightElement(block)
        } catch (error) {
          console.warn("Prism highlighting failed:", error)
          block.classList.add("syntax-ready")
        }
      })
    }
  }
  
  detectLanguage(codeElement) {
    // Try to detect language from various sources
    const classList = Array.from(codeElement.classList)
    
    // Look for language- prefixed classes
    for (const className of classList) {
      if (className.startsWith("language-")) {
        return className.replace("language-", "")
      }
    }
    
    // Look for data-language attribute
    const dataLang = codeElement.getAttribute("data-language")
    if (dataLang) {
      return dataLang
    }
    
    // Look for parent pre element with language class
    const parent = codeElement.closest("pre")
    if (parent) {
      const parentClasses = Array.from(parent.classList)
      for (const className of parentClasses) {
        if (className.startsWith("language-")) {
          return className.replace("language-", "")
        }
      }
    }
    
    // Default fallback
    return "javascript"
  }
}