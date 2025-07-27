import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="editor"
export default class extends Controller {
  static targets = ["wordCount", "lastSaved", "status", "form"]
  static values = { 
    autosaveUrl: String,
    autosaveInterval: { type: Number, default: 30000 } // 30 seconds
  }

  connect() {
    this.editor = this.element.querySelector("trix-editor")
    if (this.editor) {
      this.updateWordCount()
      this.editor.addEventListener("trix-change", this.handleChange.bind(this))
      this.editor.addEventListener("trix-attachment-add", this.handleAttachment.bind(this))
      
      // Setup autosave
      this.setupAutosave()
      this.lastContent = this.editor.value
      
      // Listen for context item insertions
      this.setupContextItemListeners()
    }
  }

  handleChange(event) {
    this.updateWordCount()
    this.updateStatus("editing")
    
    // Mark as changed for autosave
    this.contentChanged = true
    
    // Handle context item insertions
    if (event && event.detail && event.detail.insertedFrom === 'context-item') {
      console.log('Context item inserted:', event.detail.insertedContent)
      
      // You could add additional logic here for context item tracking
      // For example, tracking which context items have been used
    }
  }

  updateWordCount() {
    if (!this.editor) return
    
    const text = this.editor.editor.getDocument().toString()
    const words = text.trim().split(/\s+/).filter(word => word.length > 0).length
    
    if (this.hasWordCountTarget) {
      this.wordCountTarget.textContent = words
    }
  }

  updateStatus(status) {
    if (!this.hasStatusTarget) return
    
    const statusElement = this.statusTarget
    const indicator = statusElement.querySelector("span:first-child")
    const text = statusElement.querySelector("span:last-child")
    
    switch(status) {
      case "editing":
        indicator.classList.remove("bg-green-500", "bg-yellow-500", "bg-red-500")
        indicator.classList.add("bg-yellow-500")
        text.textContent = "Editing..."
        break
      case "saved":
        indicator.classList.remove("bg-green-500", "bg-yellow-500", "bg-red-500")
        indicator.classList.add("bg-green-500")
        text.textContent = "Saved"
        this.updateLastSaved()
        break
      case "error":
        indicator.classList.remove("bg-green-500", "bg-yellow-500", "bg-red-500")
        indicator.classList.add("bg-red-500")
        text.textContent = "Error saving"
        break
      default:
        indicator.classList.remove("bg-green-500", "bg-yellow-500", "bg-red-500")
        indicator.classList.add("bg-green-500")
        text.textContent = "Ready"
    }
  }

  updateLastSaved() {
    if (!this.hasLastSavedTarget) return
    
    const now = new Date()
    const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    this.lastSavedTarget.textContent = timeString
  }

  handleAttachment(event) {
    const attachment = event.attachment
    
    if (attachment.file) {
      // Show upload progress
      attachment.setUploadProgress(0)
      
      // Simulate upload progress (in real app, this would track actual upload)
      let progress = 0
      const interval = setInterval(() => {
        progress += 10
        attachment.setUploadProgress(progress)
        
        if (progress >= 100) {
          clearInterval(interval)
        }
      }, 100)
    }
  }

  setupAutosave() {
    if (!this.hasAutosaveUrlValue) return
    
    // Autosave on interval
    this.autosaveTimer = setInterval(() => {
      if (this.contentChanged) {
        this.performAutosave()
      }
    }, this.autosaveIntervalValue)
    
    // Autosave on blur
    this.editor.addEventListener("trix-blur", () => {
      if (this.contentChanged) {
        this.performAutosave()
      }
    })
  }
  
  async performAutosave() {
    if (!this.contentChanged || !this.editor) return
    
    this.updateStatus("saving")
    const content = this.editor.value
    
    try {
      const response = await fetch(this.autosaveUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          document: { content: content }
        })
      })
      
      if (response.ok) {
        this.contentChanged = false
        this.lastContent = content
        this.updateStatus("saved")
      } else {
        this.updateStatus("error")
        console.error('Autosave failed:', await response.text())
      }
    } catch (error) {
      this.updateStatus("error")
      console.error('Autosave error:', error)
    }
  }
  
  setupContextItemListeners() {
    // Listen for context item preview events
    document.addEventListener('context-item-preview:insert', this.handleContextItemInsert.bind(this))
    document.addEventListener('context-item-preview:closed', this.handleContextItemClosed.bind(this))
  }
  
  handleContextItemInsert(event) {
    const { content, contextItemId, itemType, contentType } = event.detail
    
    // Format content based on type before insertion
    let formattedContent = content
    
    if (contentType === 'code') {
      // Wrap code in appropriate formatting
      formattedContent = `\n\`\`\`\n${content}\n\`\`\`\n`
    } else if (itemType === 'note') {
      // Add some context for notes
      formattedContent = `\n> ${content}\n`
    }
    
    // Insert at current cursor position
    if (this.editor && this.editor.editor) {
      this.editor.editor.recordUndoEntry('Insert Context Item')
      
      const position = this.editor.editor.getPosition()
      this.editor.editor.insertString(formattedContent)
      
      // Move cursor to end of inserted content
      const newPosition = position + formattedContent.length
      this.editor.editor.setSelectedRange([newPosition, newPosition])
      
      // Focus the editor
      this.editor.focus()
    }
  }
  
  handleContextItemClosed(event) {
    // Return focus to editor when context item preview is closed
    if (this.editor) {
      setTimeout(() => {
        this.editor.focus()
      }, 100)
    }
  }
  
  disconnect() {
    if (this.editor) {
      this.editor.removeEventListener("trix-change", this.handleChange.bind(this))
      this.editor.removeEventListener("trix-attachment-add", this.handleAttachment.bind(this))
    }
    
    // Remove context item listeners
    document.removeEventListener('context-item-preview:insert', this.handleContextItemInsert.bind(this))
    document.removeEventListener('context-item-preview:closed', this.handleContextItemClosed.bind(this))
    
    if (this.autosaveTimer) {
      clearInterval(this.autosaveTimer)
    }
  }
}
