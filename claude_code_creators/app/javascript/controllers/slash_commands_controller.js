import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "status"]
  static values = { documentId: Number }

  // Command registry (matches backend CommandParserService)
  static commands = {
    "save": {
      description: "Save document to various formats",
      parameters: ["name"],
      category: "context"
    },
    "load": {
      description: "Load saved context into current session", 
      parameters: ["name"],
      category: "context"
    },
    "compact": {
      description: "Compact Claude context using AI summarization",
      parameters: ["mode"],
      category: "optimization"
    },
    "clear": {
      description: "Clear context or document content",
      parameters: ["target"],
      category: "cleanup"
    },
    "include": {
      description: "Include file content in current context",
      parameters: ["file", "format"],
      category: "content"
    },
    "snippet": {
      description: "Save selected content as reusable snippet",
      parameters: ["name"],
      category: "content"
    }
  }

  connect() {
    this.currentCommand = null
    this.commandPosition = -1
    this.commandParameters = []
    this.selectedSuggestionIndex = -1
    this.debounceTimeout = null

    // Get suggestionsList element from suggestions target
    this.suggestionsList = this.suggestionsTarget.querySelector("ul")

    // Bind event handlers
    this.inputTarget.addEventListener("input", this.handleInput.bind(this))
    this.inputTarget.addEventListener("keydown", this.handleKeydown.bind(this))
    this.inputTarget.addEventListener("focus", this.handleFocus.bind(this))
    this.inputTarget.addEventListener("blur", this.handleBlur.bind(this))
    
    // Store bound handler reference for removal
    this.boundSelectionChangeHandler = this.handleSelectionChange.bind(this)
    document.addEventListener("selectionchange", this.boundSelectionChangeHandler)

    // Setup suggestions dropdown
    this.setupSuggestions()
  }

  disconnect() {
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }
    
    // Remove selectionchange event listener
    if (this.boundSelectionChangeHandler) {
      document.removeEventListener("selectionchange", this.boundSelectionChangeHandler)
    }
  }

  // Main input handler
  handleInput() {
    // For testing: if in test environment, execute immediately
    if (typeof jest !== "undefined") {
      this.detectCommand()
      this.updateValidation()
      this.updateSuggestions()
      return
    }

    // Debounce rapid typing
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }

    this.debounceTimeout = setTimeout(() => {
      this.detectCommand()
      this.updateValidation()
      this.updateSuggestions()
    }, 150)
  }

  // Keyboard event handler
  handleKeydown(event) {
    if (this.isSuggestionsVisible()) {
      switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.navigateSuggestions(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.navigateSuggestions(-1)
        break
      case "Enter":
        if (this.selectedSuggestionIndex >= 0) {
          event.preventDefault()
          this.selectCurrentSuggestion()
        } else if (event.ctrlKey || event.metaKey) {
          event.preventDefault()
          this.executeCommand()
        }
        break
      case "Escape":
        this.hideSuggestions()
        break
      }
    } else if (event.key === "Enter" && (event.ctrlKey || event.metaKey) && this.currentCommand) {
      event.preventDefault()
      this.executeCommand()
    }
  }

  handleSelectionChange() {
    // Only handle selection changes for our input
    if (document.activeElement !== this.inputTarget) {
      return
    }

    // For testing: if in test environment, execute immediately
    if (typeof jest !== "undefined") {
      this.detectCommand()
      this.updateValidation()
      this.updateSuggestions()
      return
    }

    // Debounce selection change detection
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }

    this.debounceTimeout = setTimeout(() => {
      this.detectCommand()
      this.updateValidation()
      this.updateSuggestions()
    }, 150)
  }

  handleFocus() {
    // Don't automatically show suggestions on focus
  }

  handleBlur() {
    // Hide suggestions after a short delay to allow clicks
    setTimeout(() => {
      this.hideSuggestions()
    }, 150)
  }

  // Command detection logic
  detectCommand() {
    const input = this.inputTarget
    const value = input.value
    const cursorPos = input.selectionStart

    // Reset state
    this.currentCommand = null
    this.commandPosition = -1
    this.commandParameters = []

    // Find slash before cursor
    const textToCursor = value.substring(0, cursorPos)
    const lastSlashIndex = this.findValidSlashPosition(textToCursor)

    if (lastSlashIndex === -1) {
      return
    }

    // Extract command and parameters
    const endPos = this.findCommandEnd(value, lastSlashIndex + 1)
    const fullCommand = value.substring(lastSlashIndex + 1, endPos)
    
    if (fullCommand.trim().length === 0) {
      this.commandPosition = lastSlashIndex
      return
    }

    // Parse command and parameters
    const parts = this.parseCommandString(fullCommand)
    this.currentCommand = parts.command
    this.commandParameters = parts.parameters
    this.commandPosition = lastSlashIndex
  }

  findValidSlashPosition(text) {
    // Find last slash that's either at start, after whitespace, or after newline
    for (let i = text.length - 1; i >= 0; i--) {
      if (text[i] === "/") {
        if (i === 0 || /\s/.test(text[i - 1])) {
          return i
        }
      }
    }
    return -1
  }

  findCommandEnd(text, startPos) {
    // Find end of command (next newline or end of text)
    const nextNewline = text.indexOf("\n", startPos)
    return nextNewline === -1 ? text.length : nextNewline
  }

  parseCommandString(commandString) {
    const parts = this.shellwordsSplit(commandString.trim())
    return {
      command: parts[0]?.toLowerCase() || null,
      parameters: parts.slice(1) || []
    }
  }

  // Simple shellwords-like splitting
  shellwordsSplit(str) {
    const words = []
    let current = ""
    let inQuotes = false
    let quoteChar = ""

    for (let i = 0; i < str.length; i++) {
      const char = str[i]
      
      if (!inQuotes && (char === "\"" || char === "'")) {
        inQuotes = true
        quoteChar = char
      } else if (inQuotes && char === quoteChar) {
        inQuotes = false
        quoteChar = ""
      } else if (!inQuotes && /\s/.test(char)) {
        if (current.length > 0) {
          words.push(current)
          current = ""
        }
      } else {
        current += char
      }
    }

    if (current.length > 0) {
      words.push(current)
    }

    return words
  }

  // Command validation
  updateValidation() {
    const element = this.element
    
    // Clear previous validation classes
    element.classList.remove("valid-command", "invalid-command")

    if (this.currentCommand === null) {
      this.clearStatus()
      return
    }

    if (this.isValidCommand(this.currentCommand)) {
      element.classList.add("valid-command")
      this.clearStatus()
    } else {
      element.classList.add("invalid-command")
      this.showStatus(`Unknown command: ${this.currentCommand}`, "error")
    }
  }

  isValidCommand(command) {
    return Object.keys(this.constructor.commands).includes(command)
  }

  // Suggestions system
  setupSuggestions() {
    this.suggestionsTarget.style.display = "none"
    this.suggestionsTarget.setAttribute("role", "listbox")
    this.suggestionsTarget.setAttribute("aria-label", "Command suggestions")
  }

  updateSuggestions() {
    if (this.commandPosition === -1) {
      this.hideSuggestions()
      return
    }

    const prefix = this.currentCommand || ""
    const suggestions = this.getSuggestions(prefix)

    if (suggestions.length === 0) {
      this.hideSuggestions()
      return
    }

    this.renderSuggestions(suggestions)
    this.positionSuggestions()
    this.showSuggestions()
  }

  getSuggestions(prefix) {
    const commands = Object.keys(this.constructor.commands)
    
    if (prefix === "") {
      return commands.map(cmd => this.constructor.commands[cmd])
        .map((info, index) => ({ 
          command: commands[index], 
          ...info 
        }))
    }

    return commands.filter(cmd => cmd.startsWith(prefix.toLowerCase()))
      .map(cmd => ({ 
        command: cmd, 
        ...this.constructor.commands[cmd] 
      }))
  }

  renderSuggestions(suggestions) {
    this.suggestionsList.innerHTML = ""
    
    suggestions.forEach((suggestion) => {
      const li = document.createElement("li")
      li.setAttribute("role", "option")
      li.setAttribute("aria-selected", "false")
      li.setAttribute("data-command", suggestion.command)
      li.className = "suggestion-item"
      li.innerHTML = `
        <div class="command-name">${suggestion.command}</div>
        <div class="command-description">${suggestion.description}</div>
        <div class="command-category">${suggestion.category}</div>
      `
      
      li.addEventListener("click", () => {
        this.selectSuggestion(suggestion.command)
      })

      this.suggestionsList.appendChild(li)
    })

    this.selectedSuggestionIndex = -1
  }

  positionSuggestions() {
    if (this.commandPosition === -1) return

    const cursorPosition = this.getCursorPosition()
    this.suggestionsTarget.style.left = `${cursorPosition.x}px`
    this.suggestionsTarget.style.top = `${cursorPosition.y + 20}px`
  }

  getCursorPosition() {
    const input = this.inputTarget
    const style = window.getComputedStyle(input)
    
    // Create a mirror element to measure text
    const mirror = document.createElement("div")
    mirror.style.position = "absolute"
    mirror.style.visibility = "hidden"
    mirror.style.whiteSpace = "pre-wrap"
    mirror.style.wordWrap = "break-word"
    mirror.style.font = style.font
    mirror.style.fontSize = style.fontSize
    mirror.style.fontFamily = style.fontFamily
    mirror.style.padding = style.padding
    mirror.style.border = style.border
    mirror.style.width = input.offsetWidth + "px"
    
    const textToCursor = input.value.substring(0, this.commandPosition)
    mirror.textContent = textToCursor
    
    document.body.appendChild(mirror)
    const rect = input.getBoundingClientRect()
    const x = rect.left + mirror.offsetWidth
    const y = rect.top
    document.body.removeChild(mirror)
    
    return { x, y }
  }

  showSuggestions() {
    this.suggestionsTarget.style.display = "block"
  }

  hideSuggestions() {
    this.suggestionsTarget.style.display = "none"
    this.selectedSuggestionIndex = -1
  }

  isSuggestionsVisible() {
    return this.suggestionsTarget.style.display !== "none"
  }

  // Keyboard navigation
  navigateSuggestions(direction) {
    const suggestions = this.suggestionsList.children
    if (suggestions.length === 0) return

    // Clear current selection
    if (this.selectedSuggestionIndex >= 0) {
      suggestions[this.selectedSuggestionIndex].setAttribute("aria-selected", "false")
      suggestions[this.selectedSuggestionIndex].classList.remove("selected")
    }

    // Calculate new index with wrapping
    this.selectedSuggestionIndex += direction
    if (this.selectedSuggestionIndex >= suggestions.length) {
      this.selectedSuggestionIndex = 0
    } else if (this.selectedSuggestionIndex < 0) {
      this.selectedSuggestionIndex = suggestions.length - 1
    }

    // Set new selection
    suggestions[this.selectedSuggestionIndex].setAttribute("aria-selected", "true")
    suggestions[this.selectedSuggestionIndex].classList.add("selected")
  }

  selectCurrentSuggestion() {
    const suggestions = this.suggestionsList.children
    if (this.selectedSuggestionIndex >= 0 && this.selectedSuggestionIndex < suggestions.length) {
      const selectedSuggestion = suggestions[this.selectedSuggestionIndex]
      const command = selectedSuggestion.getAttribute("data-command")
      this.selectSuggestion(command)
    }
  }

  selectSuggestion(command) {
    this.replaceCurrentCommand(command)
    this.hideSuggestions()
  }

  replaceCurrentCommand(command) {
    const input = this.inputTarget
    const value = input.value
    
    if (this.commandPosition === -1) return

    // Find end of current command
    const endPos = this.findCommandEnd(value, this.commandPosition + 1)
    
    // Replace the current command
    const before = value.substring(0, this.commandPosition + 1)
    const after = value.substring(endPos)
    const newValue = before + command + after
    
    input.value = newValue
    
    // Position cursor after the command
    const newCursorPos = this.commandPosition + 1 + command.length
    input.setSelectionRange(newCursorPos, newCursorPos)
    
    // Update command detection
    this.detectCommand()
  }

  // Command execution
  async executeCommand() {
    if (!this.currentCommand) return

    this.showStatus("Executing command...", "loading")

    try {
      const response = await fetch(`/documents/${this.documentIdValue}/commands`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({
          command: this.currentCommand,
          parameters: this.commandParameters,
          selected_content: this.getSelectedContent()
        })
      })

      const result = await response.json()

      if (response.ok && result.status === "success") {
        this.showStatus(`Command '${this.currentCommand}' executed successfully`, "success")
        this.dispatch("command-executed", { 
          detail: { 
            command: this.currentCommand, 
            result: result.result 
          } 
        })
      } else {
        this.showStatus(result.error || "Command execution failed", "error")
      }

    } catch {
      this.showStatus("Network error: Could not execute command", "error")
    }
  }

  getSelectedContent() {
    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd
    
    if (start !== end) {
      return input.value.substring(start, end)
    }
    
    return null
  }

  // Status management
  showStatus(message, type) {
    this.statusTarget.textContent = message
    this.statusTarget.className = `command-status ${type}`
    
    // Auto-clear success messages
    if (type === "success") {
      setTimeout(() => {
        this.clearStatus()
      }, 3000)
    }
  }

  clearStatus() {
    this.statusTarget.textContent = ""
    this.statusTarget.className = "command-status"
  }
}