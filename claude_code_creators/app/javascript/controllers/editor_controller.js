import { Controller } from "@hotwired/stimulus"
import hotkeys from "hotkeys-js"
import { debounce, throttle } from "throttle-debounce"

// Connects to data-controller="editor"
export default class extends Controller {
  static targets = ["wordCount", "lastSaved", "status", "form", "formatBar", "shortcutsHelp"]
  static values = { 
    autosaveUrl: String,
    autosaveInterval: { type: Number, default: 30000 }, // 30 seconds
    showFormatBar: { type: Boolean, default: true },
    enableShortcuts: { type: Boolean, default: true },
    currentUserId: Number,
    documentId: Number
  }

  connect() {
    this.editor = this.element.querySelector("trix-editor")
    this.presenceChannel = null
    this.isTyping = false
    this.lastCursorPosition = null
    
    if (this.editor) {
      this.updateWordCount()
      
      // Bind methods to preserve context
      this.boundHandleChange = this.handleChange.bind(this)
      this.boundHandleSelection = debounce(200, this.handleSelection.bind(this))
      this.boundHandleFocus = this.handleFocus.bind(this)
      this.boundHandleBlur = this.handleBlur.bind(this)
      this.boundHandleMouseMove = throttle(100, this.handleMouseMove.bind(this))
      this.boundHandleAttachment = this.handleAttachment.bind(this)
      this.boundHandleContextItemInsert = this.handleContextItemInsert.bind(this)
      this.boundHandleContextItemClosed = this.handleContextItemClosed.bind(this)
      this.boundAutosaveBlur = () => {
        if (this.contentChanged) {
          this.performAutosave()
        }
      }
      
      // Setup event listeners
      this.editor.addEventListener("trix-change", this.boundHandleChange)
      this.editor.addEventListener("trix-selection-change", this.boundHandleSelection)
      this.editor.addEventListener("trix-attachment-add", this.boundHandleAttachment)
      this.editor.addEventListener("trix-focus", this.boundHandleFocus)
      this.editor.addEventListener("trix-blur", this.boundHandleBlur)
      this.editor.addEventListener("mousemove", this.boundHandleMouseMove)
      
      // Setup keyboard shortcuts
      if (this.enableShortcutsValue) {
        this.setupKeyboardShortcuts()
      }
      
      // Setup format bar
      if (this.showFormatBarValue && this.hasFormatBarTarget) {
        this.setupFormatBar()
      }
      
      // Setup autosave
      this.setupAutosave()
      this.lastContent = this.editor.value
      
      // Listen for context item insertions
      this.setupContextItemListeners()
      
      // Setup collaborative presence
      this.setupPresence()
    }
  }

  handleChange(event) {
    this.updateWordCount()
    this.updateStatus("editing")
    
    // Mark as changed for autosave
    this.contentChanged = true
    
    // Broadcast typing status
    if (this.presenceChannel && !this.isTyping) {
      this.presenceChannel.startTyping()
      this.isTyping = true
    }
    
    // Handle context item insertions
    if (event && event.detail && event.detail.insertedFrom === "context-item") {
      console.log("Context item inserted:", event.detail.insertedContent)
      
      // You could add additional logic here for context item tracking
      // For example, tracking which context items have been used
    }
  }

  handleSelection(event) {
    const selection = this.editor.editor.getSelectedRange()
    if (this.presenceChannel && selection !== this.lastSelection) {
      this.presenceChannel.updateSelection(selection)
      this.lastSelection = selection
    }
  }

  handleFocus(event) {
    if (this.hasFormatBarTarget) {
      this.formatBarTarget.classList.remove("opacity-0")
      this.formatBarTarget.classList.add("opacity-100")
    }
  }

  handleBlur(event) {
    if (this.presenceChannel && this.isTyping) {
      this.presenceChannel.stopTyping()
      this.isTyping = false
    }
    
    if (this.hasFormatBarTarget) {
      this.formatBarTarget.classList.add("opacity-0")
      this.formatBarTarget.classList.remove("opacity-100")
    }
  }

  handleMouseMove(event) {
    if (this.presenceChannel) {
      const editorRect = this.editor.getBoundingClientRect()
      const position = {
        x: event.clientX - editorRect.left,
        y: event.clientY - editorRect.top
      }
      
      if (position !== this.lastCursorPosition) {
        this.presenceChannel.updateCursor(position.x, position.y)
        this.lastCursorPosition = position
      }
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
    const timeString = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
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
    this.editor.addEventListener("trix-blur", this.boundAutosaveBlur)
  }
  
  async performAutosave() {
    if (!this.contentChanged || !this.editor) return
    
    this.updateStatus("saving")
    const content = this.editor.value
    
    try {
      const response = await fetch(this.autosaveUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name=\"csrf-token\"]").content,
          "Accept": "application/json"
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
        console.error("Autosave failed:", await response.text())
      }
    } catch (error) {
      this.updateStatus("error")
      console.error("Autosave error:", error)
    }
  }
  
  setupContextItemListeners() {
    // Listen for context item preview events
    document.addEventListener("context-item-preview:insert", this.boundHandleContextItemInsert)
    document.addEventListener("context-item-preview:closed", this.boundHandleContextItemClosed)
  }
  
  handleContextItemInsert(event) {
    const { content, contextItemId, itemType, contentType } = event.detail
    
    // Format content based on type before insertion
    let formattedContent = content
    
    if (contentType === "code") {
      // Wrap code in appropriate formatting
      formattedContent = `\n\`\`\`\n${content}\n\`\`\`\n`
    } else if (itemType === "note") {
      // Add some context for notes
      formattedContent = `\n> ${content}\n`
    }
    
    // Insert at current cursor position
    if (this.editor && this.editor.editor) {
      this.editor.editor.recordUndoEntry("Insert Context Item")
      
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

  // Setup keyboard shortcuts for enhanced editing
  setupKeyboardShortcuts() {
    const scope = `editor-${this.element.id || "default"}`
    hotkeys.setScope(scope)

    // Format shortcuts
    hotkeys("cmd+b,ctrl+b", scope, (event) => {
      event.preventDefault()
      this.toggleBold()
    })

    hotkeys("cmd+i,ctrl+i", scope, (event) => {
      event.preventDefault()
      this.toggleItalic()
    })

    hotkeys("cmd+u,ctrl+u", scope, (event) => {
      event.preventDefault()
      this.toggleUnderline()
    })

    hotkeys("cmd+k,ctrl+k", scope, (event) => {
      event.preventDefault()
      this.toggleLink()
    })

    // Save shortcut
    hotkeys("cmd+s,ctrl+s", scope, (event) => {
      event.preventDefault()
      this.performAutosave()
    })

    // Help shortcut
    hotkeys("cmd+?,ctrl+?", scope, (event) => {
      event.preventDefault()
      this.toggleShortcutsHelp()
    })

    // Focus editor
    hotkeys("cmd+e,ctrl+e", scope, (event) => {
      event.preventDefault()
      this.editor.focus()
    })

    // Insert timestamp
    hotkeys("cmd+t,ctrl+t", scope, (event) => {
      event.preventDefault()
      this.insertTimestamp()
    })
  }

  // Setup format bar functionality
  setupFormatBar() {
    if (!this.hasFormatBarTarget) return

    const formatBar = this.formatBarTarget
    
    // Add event listeners to format buttons
    formatBar.querySelectorAll("[data-format-action]").forEach(button => {
      button.addEventListener("click", (event) => {
        event.preventDefault()
        const action = button.dataset.formatAction
        this.performFormatAction(action)
      })
    })
  }

  // Setup collaborative presence
  setupPresence() {
    if (!this.documentIdValue || !this.currentUserIdValue) return

    // Import and setup presence channel
    import("../channels/presence_channel").then(({ default: PresenceChannel }) => {
      this.presenceChannel = PresenceChannel.create(
        this.documentIdValue,
        this.currentUserIdValue,
        {
          onConnected: () => {
            console.log("Editor connected to presence channel")
          },
          onDisconnected: () => {
            console.log("Editor disconnected from presence channel")
          }
        }
      )
    })
  }

  // Format actions
  toggleBold() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("bold")
    }
  }

  toggleItalic() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("italic")
    }
  }

  toggleUnderline() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("underline")
    }
  }

  toggleLink() {
    if (this.editor.editor) {
      const selectedText = this.editor.editor.getSelectedDocument().toString()
      const url = prompt("Enter URL:", "https://")
      
      if (url && url.trim()) {
        this.editor.editor.activateAttribute("href", url.trim())
      }
    }
  }

  performFormatAction(action) {
    switch (action) {
    case "bold":
      this.toggleBold()
      break
    case "italic":
      this.toggleItalic()
      break
    case "underline":
      this.toggleUnderline()
      break
    case "link":
      this.toggleLink()
      break
    case "heading":
      this.insertHeading()
      break
    case "bullet-list":
      this.insertBulletList()
      break
    case "number-list":
      this.insertNumberList()
      break
    case "quote":
      this.insertQuote()
      break
    case "code":
      this.insertCodeBlock()
      break
    }
    
    // Keep focus on editor
    this.editor.focus()
  }

  insertHeading() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("heading1")
    }
  }

  insertBulletList() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("bulletList")
    }
  }

  insertNumberList() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("numberList")
    }
  }

  insertQuote() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("quote")
    }
  }

  insertCodeBlock() {
    if (this.editor.editor) {
      this.editor.editor.activateAttribute("code")
    }
  }

  insertTimestamp() {
    if (this.editor.editor) {
      const now = new Date()
      const timestamp = now.toLocaleString()
      this.editor.editor.insertString(`[${timestamp}] `)
    }
  }

  toggleShortcutsHelp() {
    if (this.hasShortcutsHelpTarget) {
      const help = this.shortcutsHelpTarget
      help.classList.toggle("hidden")
    }
  }
  
  disconnect() {
    if (this.editor) {
      this.editor.removeEventListener("trix-change", this.boundHandleChange)
      this.editor.removeEventListener("trix-selection-change", this.boundHandleSelection)
      this.editor.removeEventListener("trix-attachment-add", this.boundHandleAttachment)
      this.editor.removeEventListener("trix-focus", this.boundHandleFocus)
      this.editor.removeEventListener("trix-blur", this.boundHandleBlur)
      this.editor.removeEventListener("mousemove", this.boundHandleMouseMove)
      this.editor.removeEventListener("trix-blur", this.boundAutosaveBlur)
    }
    
    // Remove context item listeners
    document.removeEventListener("context-item-preview:insert", this.boundHandleContextItemInsert)
    document.removeEventListener("context-item-preview:closed", this.boundHandleContextItemClosed)
    
    // Disconnect presence channel
    if (this.presenceChannel) {
      this.presenceChannel.disconnect()
    }
    
    // Clear keyboard shortcuts
    if (this.enableShortcutsValue) {
      const scope = `editor-${this.element.id || "default"}`
      hotkeys.deleteScope(scope)
    }
    
    if (this.autosaveTimer) {
      clearInterval(this.autosaveTimer)
    }
  }
}
