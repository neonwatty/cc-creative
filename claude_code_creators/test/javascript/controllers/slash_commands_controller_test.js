import { Application } from "@hotwired/stimulus"
import SlashCommandsController from "../../../app/javascript/controllers/slash_commands_controller"

// Mock fetch for API calls
global.fetch = jest.fn()

describe("SlashCommandsController", () => {
  let application
  let controller
  let element

  beforeEach(() => {
    // Setup DOM element
    element = document.createElement("div")
    element.setAttribute("data-controller", "slash-commands")
    element.setAttribute("data-slash-commands-document-id-value", "1")
    element.innerHTML = `
      <textarea data-slash-commands-target="input" class="editor-input"></textarea>
      <div data-slash-commands-target="suggestions" class="suggestions-dropdown" style="display: none;">
        <ul data-slash-commands-target="suggestionsList"></ul>
      </div>
      <div data-slash-commands-target="status" class="command-status"></div>
    `
    document.body.appendChild(element)

    // Setup Stimulus application
    application = Application.start()
    application.register("slash-commands", SlashCommandsController)
    controller = application.getControllerForElementAndIdentifier(element, "slash-commands")

    // Clear fetch mock
    fetch.mockClear()
  })

  afterEach(() => {
    document.body.removeChild(element)
    application.stop()
  })

  // Command Detection Tests
  describe("Command Detection", () => {
    test("should detect slash command at cursor position", () => {
      const input = controller.inputTarget
      input.value = "Some text /save document"
      input.setSelectionRange(15, 15) // After "/save"

      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.currentCommand).toBe("save")
      expect(controller.commandPosition).toBe(10) // Position of slash
    })

    test("should detect slash command with parameters", () => {
      const input = controller.inputTarget
      input.value = "/load my_context with params"
      input.setSelectionRange(25, 25)

      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.currentCommand).toBe("load")
      expect(controller.commandParameters).toEqual(["my_context", "with", "params"])
    })

    test("should not detect slash in middle of word", () => {
      const input = controller.inputTarget
      input.value = "email@domain.com/path"
      input.setSelectionRange(20, 20)

      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.currentCommand).toBeNull()
    })

    test("should detect slash at beginning of line", () => {
      const input = controller.inputTarget
      input.value = "Previous line\n/snippet test"
      input.setSelectionRange(25, 25)

      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.currentCommand).toBe("snippet")
    })

    test("should detect slash after whitespace", () => {
      const input = controller.inputTarget
      input.value = "Some text    /compact"
      input.setSelectionRange(20, 20)

      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.currentCommand).toBe("compact")
    })

    test("should update detection on cursor movement", () => {
      const input = controller.inputTarget
      input.value = "/save test /load other"
      
      // Make input the active element for selectionchange to work
      input.focus()
      
      // Move to first command
      input.setSelectionRange(5, 5)
      input.dispatchEvent(new Event("selectionchange"))
      expect(controller.currentCommand).toBe("save")

      // Move to second command
      input.setSelectionRange(15, 15)
      input.dispatchEvent(new Event("selectionchange"))
      expect(controller.currentCommand).toBe("load")
    })
  })

  // Command Validation Tests
  describe("Command Validation", () => {
    test("should validate known commands", () => {
      const input = controller.inputTarget
      input.value = "/save"
      
      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.isValidCommand("save")).toBe(true)
      expect(element.classList.contains("valid-command")).toBe(true)
    })

    test("should invalidate unknown commands", () => {
      const input = controller.inputTarget
      input.value = "/unknown"
      
      const event = new Event("input")
      input.dispatchEvent(event)

      expect(controller.isValidCommand("unknown")).toBe(false)
      expect(element.classList.contains("invalid-command")).toBe(true)
    })

    test("should show validation feedback", () => {
      const input = controller.inputTarget
      input.value = "/invalid_command"
      
      const event = new Event("input")
      input.dispatchEvent(event)

      const status = controller.statusTarget
      expect(status.textContent).toContain("Unknown command: invalid_command")
      expect(status.classList.contains("error")).toBe(true)
    })
  })

  // Suggestion System Tests
  describe("Command Suggestions", () => {
    test("should show suggestions on slash character", () => {
      const input = controller.inputTarget
      input.value = "/"
      input.setSelectionRange(1, 1)

      const event = new Event("input")
      input.dispatchEvent(event)

      const suggestions = controller.suggestionsTarget
      expect(suggestions.style.display).not.toBe("none")
      expect(controller.suggestionsList.children.length).toBe(6) // All commands
    })

    test("should filter suggestions based on input", () => {
      const input = controller.inputTarget
      input.value = "/sa"
      input.setSelectionRange(3, 3)

      const event = new Event("input")
      input.dispatchEvent(event)

      const filteredSuggestions = Array.from(controller.suggestionsList.children)
        .map(li => li.textContent)
      
      expect(filteredSuggestions).toContain("save")
      expect(filteredSuggestions).not.toContain("load")
    })

    test("should position suggestions near cursor", () => {
      const input = controller.inputTarget
      input.value = "Some text /"
      input.setSelectionRange(11, 11)

      const event = new Event("input")
      input.dispatchEvent(event)

      const suggestions = controller.suggestionsTarget
      const cursorPosition = controller.getCursorPosition()
      
      expect(suggestions.style.left).toBe(`${cursorPosition.x}px`)
      expect(suggestions.style.top).toBe(`${cursorPosition.y + 20}px`)
    })

    test("should hide suggestions when no slash command", () => {
      // First show suggestions
      const input = controller.inputTarget
      input.value = "/sa"
      input.dispatchEvent(new Event("input"))
      
      expect(controller.suggestionsTarget.style.display).not.toBe("none")

      // Then remove slash
      input.value = "sa"
      input.dispatchEvent(new Event("input"))

      expect(controller.suggestionsTarget.style.display).toBe("none")
    })

    test("should update suggestions in real-time", () => {
      const input = controller.inputTarget
      
      // Start typing
      input.value = "/s"
      input.dispatchEvent(new Event("input"))
      let suggestions = Array.from(controller.suggestionsList.children)
      expect(suggestions.length).toBeGreaterThan(1)

      // Continue typing
      input.value = "/sa"
      input.dispatchEvent(new Event("input"))
      suggestions = Array.from(controller.suggestionsList.children)
      expect(suggestions.length).toBe(1)
      expect(suggestions[0].textContent).toContain("save")
    })
  })

  // Keyboard Navigation Tests
  describe("Keyboard Navigation", () => {
    beforeEach(() => {
      // Setup suggestions
      const input = controller.inputTarget
      input.value = "/s"
      input.dispatchEvent(new Event("input"))
    })

    test("should navigate suggestions with arrow keys", () => {
      const input = controller.inputTarget
      
      // Press down arrow
      const downEvent = new KeyboardEvent("keydown", { key: "ArrowDown" })
      input.dispatchEvent(downEvent)

      expect(controller.selectedSuggestionIndex).toBe(0)
      expect(controller.suggestionsList.children[0].classList.contains("selected")).toBe(true)

      // Press down arrow again
      input.dispatchEvent(downEvent)
      expect(controller.selectedSuggestionIndex).toBe(1)
    })

    test("should wrap navigation at boundaries", () => {
      const input = controller.inputTarget
      const suggestionCount = controller.suggestionsList.children.length

      // Navigate to last item
      for (let i = 0; i < suggestionCount; i++) {
        input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown" }))
      }

      expect(controller.selectedSuggestionIndex).toBe(suggestionCount - 1)

      // Press down once more - should wrap to first
      input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown" }))
      expect(controller.selectedSuggestionIndex).toBe(0)
    })

    test("should select suggestion with Enter key", () => {
      const input = controller.inputTarget
      
      // Navigate to first suggestion
      input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown" }))
      
      // Mock the selected suggestion
      const firstSuggestion = controller.suggestionsList.children[0]
      firstSuggestion.setAttribute("data-command", "save")
      
      // Press Enter
      const enterEvent = new KeyboardEvent("keydown", { key: "Enter" })
      Object.defineProperty(enterEvent, 'preventDefault', { value: jest.fn() })
      input.dispatchEvent(enterEvent)

      expect(enterEvent.preventDefault).toHaveBeenCalled()
      expect(controller.suggestionsTarget.style.display).toBe("none")
    })

    test("should close suggestions with Escape key", () => {
      const input = controller.inputTarget
      
      const escapeEvent = new KeyboardEvent("keydown", { key: "Escape" })
      input.dispatchEvent(escapeEvent)

      expect(controller.suggestionsTarget.style.display).toBe("none")
      expect(controller.selectedSuggestionIndex).toBe(-1)
    })
  })

  // Command Execution Tests
  describe("Command Execution", () => {
    test("should execute command on Enter key", () => {
      // Mock successful API response
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: "success",
          command: "save",
          result: { context_name: "test" }
        })
      })

      const input = controller.inputTarget
      input.value = "/save test_context"
      input.setSelectionRange(17, 17)

      const enterEvent = new KeyboardEvent("keydown", { key: "Enter", ctrlKey: true })
      Object.defineProperty(enterEvent, 'preventDefault', { value: jest.fn() })
      input.dispatchEvent(enterEvent)

      expect(fetch).toHaveBeenCalledWith("/documents/1/commands", expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          "Content-Type": "application/json"
        })
      }))
    })

    test("should show loading state during execution", () => {
      // Mock delayed API response
      fetch.mockImplementationOnce(() => new Promise(resolve => {
        setTimeout(() => resolve({
          ok: true,
          json: async () => ({ status: "success" })
        }), 100)
      }))

      const input = controller.inputTarget
      input.value = "/save test"
      
      const enterEvent = new KeyboardEvent("keydown", { key: "Enter", ctrlKey: true })
      input.dispatchEvent(enterEvent)

      expect(controller.statusTarget.textContent).toContain("Executing")
      expect(controller.statusTarget.classList.contains("loading")).toBe(true)
    })

    test("should handle execution errors gracefully", async () => {
      // Mock API error
      fetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({
          status: "error",
          error: "Command failed"
        })
      })

      const input = controller.inputTarget
      input.value = "/invalid"
      
      const enterEvent = new KeyboardEvent("keydown", { key: "Enter", ctrlKey: true })
      input.dispatchEvent(enterEvent)

      // Wait for async operation
      await new Promise(resolve => setTimeout(resolve, 10))

      expect(controller.statusTarget.textContent).toContain("Command failed")
      expect(controller.statusTarget.classList.contains("error")).toBe(true)
    })

    test("should clear status after successful execution", async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: "success",
          command: "save"
        })
      })

      const input = controller.inputTarget
      input.value = "/save"
      
      input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", ctrlKey: true }))

      // Wait for execution and auto-clear
      await new Promise(resolve => setTimeout(resolve, 3100))

      expect(controller.statusTarget.textContent).toBe("")
      expect(controller.statusTarget.className).toBe("command-status")
    })
  })

  // UI Interaction Tests
  describe("UI Interactions", () => {
    test("should handle mouse clicks on suggestions", () => {
      const input = controller.inputTarget
      input.value = "/s"
      input.dispatchEvent(new Event("input"))

      const firstSuggestion = controller.suggestionsList.children[0]
      firstSuggestion.setAttribute("data-command", "save")
      
      const clickEvent = new Event("click")
      firstSuggestion.dispatchEvent(clickEvent)

      expect(controller.suggestionsTarget.style.display).toBe("none")
    })

    test("should handle input focus and blur", () => {
      const input = controller.inputTarget
      
      // Focus should not automatically show suggestions
      input.dispatchEvent(new Event("focus"))
      expect(controller.suggestionsTarget.style.display).toBe("none")

      // Blur should hide suggestions
      input.value = "/s"
      input.dispatchEvent(new Event("input"))
      expect(controller.suggestionsTarget.style.display).not.toBe("none")

      input.dispatchEvent(new Event("blur"))
      expect(controller.suggestionsTarget.style.display).toBe("none")
    })

    test("should maintain cursor position after suggestion selection", () => {
      const input = controller.inputTarget
      input.value = "Some text /s more text"
      input.setSelectionRange(12, 12) // At "/s"

      const event = new Event("input")
      input.dispatchEvent(event)

      // Select "save" suggestion
      controller.selectSuggestion("save")

      expect(input.value).toBe("Some text /save more text")
      expect(input.selectionStart).toBe(15) // After "/save"
    })
  })

  // Performance Tests
  describe("Performance", () => {
    test("should debounce suggestion updates", (done) => {
      const input = controller.inputTarget
      let updateCount = 0
      
      // Mock the suggestion update method
      const originalUpdate = controller.updateSuggestions
      controller.updateSuggestions = () => {
        updateCount++
        originalUpdate.call(controller)
      }

      // Rapidly type characters
      input.value = "/"
      input.dispatchEvent(new Event("input"))
      input.value = "/s"
      input.dispatchEvent(new Event("input"))
      input.value = "/sa"
      input.dispatchEvent(new Event("input"))

      // Should debounce to single update
      setTimeout(() => {
        expect(updateCount).toBeLessThan(3)
        done()
      }, 300)
    })

    test("should handle large documents without performance issues", () => {
      const input = controller.inputTarget
      const largeText = "Lorem ipsum ".repeat(10000) + "/save test"
      
      const start = performance.now()
      input.value = largeText
      input.setSelectionRange(largeText.length, largeText.length)
      input.dispatchEvent(new Event("input"))
      const end = performance.now()

      expect(end - start).toBeLessThan(100) // Should complete in under 100ms
      expect(controller.currentCommand).toBe("save")
    })
  })

  // Accessibility Tests
  describe("Accessibility", () => {
    test("should provide ARIA labels for suggestions", () => {
      const input = controller.inputTarget
      input.value = "/s"
      input.dispatchEvent(new Event("input"))

      const suggestionsList = controller.suggestionsTarget
      expect(suggestionsList.getAttribute("role")).toBe("listbox")
      expect(suggestionsList.getAttribute("aria-label")).toBe("Command suggestions")

      const suggestions = controller.suggestionsList.children
      for (let suggestion of suggestions) {
        expect(suggestion.getAttribute("role")).toBe("option")
        expect(suggestion.getAttribute("aria-selected")).toBeDefined()
      }
    })

    test("should announce selection changes to screen readers", () => {
      const input = controller.inputTarget
      input.value = "/s"
      input.dispatchEvent(new Event("input"))

      // Navigate to first suggestion
      input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown" }))

      const selectedSuggestion = controller.suggestionsList.children[0]
      expect(selectedSuggestion.getAttribute("aria-selected")).toBe("true")
      
      // Others should not be selected
      const otherSuggestions = Array.from(controller.suggestionsList.children).slice(1)
      otherSuggestions.forEach(suggestion => {
        expect(suggestion.getAttribute("aria-selected")).toBe("false")
      })
    })

    test("should support keyboard-only navigation", () => {
      const input = controller.inputTarget
      input.value = "/s"
      input.dispatchEvent(new Event("input"))

      // Should be able to navigate and select using only keyboard
      input.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown" }))
      input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }))

      expect(controller.suggestionsTarget.style.display).toBe("none")
    })
  })

  // Edge Cases
  describe("Edge Cases", () => {
    test("should handle multiple slashes in input", () => {
      const input = controller.inputTarget
      input.value = "/save /load /compact"
      input.setSelectionRange(5, 5) // At first space

      input.dispatchEvent(new Event("input"))

      expect(controller.currentCommand).toBe("save")
    })

    test("should handle slash at end of input", () => {
      const input = controller.inputTarget
      input.value = "text /"
      input.setSelectionRange(6, 6)

      input.dispatchEvent(new Event("input"))

      expect(controller.suggestionsTarget.style.display).not.toBe("none")
    })

    test("should handle empty input gracefully", () => {
      const input = controller.inputTarget
      input.value = ""
      
      input.dispatchEvent(new Event("input"))

      expect(controller.currentCommand).toBeNull()
      expect(controller.suggestionsTarget.style.display).toBe("none")
    })
  })
})