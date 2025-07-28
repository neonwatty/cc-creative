import { Application } from "@hotwired/stimulus"
import SubAgentConversationController from "controllers/sub_agent_conversation_controller"

describe("SubAgentConversationController", () => {
  let application
  let controller
  let element

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="sub-agent-conversation"
           data-sub-agent-conversation-sub-agent-id-value="1"
           data-sub-agent-conversation-document-id-value="1">
        <div data-sub-agent-conversation-target="messagesList">
          <div class="message">Hello</div>
        </div>
        <form data-action="submit->sub-agent-conversation#sendMessage">
          <textarea data-sub-agent-conversation-target="messageInput"></textarea>
          <span data-sub-agent-conversation-target="charCount">0 / 10000</span>
          <button type="submit">Send</button>
        </form>
        <div data-sub-agent-conversation-target="loadingIndicator" class="hidden">
          Loading...
        </div>
        <button data-action="click->sub-agent-conversation#mergeContent">Merge</button>
        <button data-action="click->sub-agent-conversation#exportConversation">Export</button>
        <button data-action="click->sub-agent-conversation#clearMessages">Clear</button>
      </div>
    `

    application = Application.start()
    application.register("sub-agent-conversation", SubAgentConversationController)
    
    element = document.querySelector('[data-controller="sub-agent-conversation"]')
    controller = application.getControllerForElementAndIdentifier(element, "sub-agent-conversation")
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("#connect", () => {
    it("scrolls to bottom of messages", () => {
      const scrollSpy = jest.spyOn(controller, 'scrollToBottom')
      controller.connect()
      expect(scrollSpy).toHaveBeenCalled()
    })

    it("subscribes to ActionCable channel", () => {
      expect(controller.channel).toBeDefined()
      expect(controller.channel.identifier).toContain('"sub_agent_id":1')
    })
  })

  describe("#sendMessage", () => {
    beforeEach(() => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ success: true, message: { id: 1, content: "Test" } })
      })
    })

    it("sends message when form is submitted", async () => {
      const textarea = controller.messageInputTarget
      textarea.value = "Test message"
      
      const form = element.querySelector('form')
      form.dispatchEvent(new Event('submit'))
      
      expect(fetch).toHaveBeenCalledWith(
        "/documents/1/sub_agents/1/send_message",
        expect.objectContaining({
          method: "POST",
          body: expect.stringContaining("Test message")
        })
      )
    })

    it("clears input after successful send", async () => {
      controller.messageInputTarget.value = "Test message"
      
      await controller.sendMessage(new Event('submit'))
      
      expect(controller.messageInputTarget.value).toBe("")
    })

    it("shows loading indicator while sending", async () => {
      const loadingIndicator = controller.loadingIndicatorTarget
      
      const promise = controller.sendMessage(new Event('submit'))
      expect(loadingIndicator.classList.contains('hidden')).toBe(false)
      
      await promise
      expect(loadingIndicator.classList.contains('hidden')).toBe(true)
    })

    it("prevents empty messages", async () => {
      controller.messageInputTarget.value = ""
      
      await controller.sendMessage(new Event('submit'))
      
      expect(fetch).not.toHaveBeenCalled()
    })

    it("handles errors gracefully", async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))
      const alertSpy = jest.spyOn(window, 'alert').mockImplementation()
      
      controller.messageInputTarget.value = "Test"
      await controller.sendMessage(new Event('submit'))
      
      expect(alertSpy).toHaveBeenCalledWith("Error sending message: Network error")
    })
  })

  describe("#updateCharCount", () => {
    it("updates character count display", () => {
      controller.messageInputTarget.value = "Hello"
      controller.updateCharCount()
      
      expect(controller.charCountTarget.textContent).toBe("5 / 10000")
    })

    it("adds warning class when near limit", () => {
      controller.messageInputTarget.value = "a".repeat(9500)
      controller.updateCharCount()
      
      expect(controller.charCountTarget.classList.contains('text-yellow-600')).toBe(true)
    })

    it("adds error class when over limit", () => {
      controller.messageInputTarget.value = "a".repeat(10001)
      controller.updateCharCount()
      
      expect(controller.charCountTarget.classList.contains('text-red-600')).toBe(true)
    })
  })

  describe("#handleKeydown", () => {
    it("sends message on Ctrl+Enter", () => {
      const sendSpy = jest.spyOn(controller, 'sendMessage')
      controller.messageInputTarget.value = "Test"
      
      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        ctrlKey: true
      })
      controller.handleKeydown(event)
      
      expect(sendSpy).toHaveBeenCalled()
    })

    it("sends message on Cmd+Enter (Mac)", () => {
      const sendSpy = jest.spyOn(controller, 'sendMessage')
      controller.messageInputTarget.value = "Test"
      
      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        metaKey: true
      })
      controller.handleKeydown(event)
      
      expect(sendSpy).toHaveBeenCalled()
    })
  })

  describe("#mergeContent", () => {
    it("calls merge endpoint", async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ success: true })
      })
      
      await controller.mergeContent()
      
      expect(fetch).toHaveBeenCalledWith(
        "/documents/1/sub_agents/1/merge_content",
        expect.objectContaining({ method: "POST" })
      )
    })

    it("shows success message on successful merge", async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ success: true, message: "Content merged" })
      })
      const alertSpy = jest.spyOn(window, 'alert').mockImplementation()
      
      await controller.mergeContent()
      
      expect(alertSpy).toHaveBeenCalledWith("Content merged")
    })
  })

  describe("#exportConversation", () => {
    it("downloads conversation export", async () => {
      const mockData = {
        agent_name: "Test Agent",
        messages: [{ role: "user", content: "Hello" }]
      }
      
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockData
      })
      
      // Mock creating download link
      const createElementSpy = jest.spyOn(document, 'createElement')
      const clickSpy = jest.fn()
      
      await controller.exportConversation()
      
      expect(fetch).toHaveBeenCalledWith(
        "/documents/1/sub_agents/1/export.json"
      )
    })
  })

  describe("#clearMessages", () => {
    it("confirms before clearing", async () => {
      const confirmSpy = jest.spyOn(window, 'confirm').mockReturnValue(true)
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ success: true })
      })
      
      await controller.clearMessages()
      
      expect(confirmSpy).toHaveBeenCalledWith("Are you sure you want to clear all messages?")
      expect(fetch).toHaveBeenCalled()
    })

    it("does not clear if not confirmed", async () => {
      jest.spyOn(window, 'confirm').mockReturnValue(false)
      
      await controller.clearMessages()
      
      expect(fetch).not.toHaveBeenCalled()
    })
  })

  describe("#received", () => {
    it("adds new message to the list", () => {
      const messageData = {
        id: 2,
        role: "assistant",
        content: "New message",
        html: '<div class="message">New message</div>'
      }
      
      controller.received({ message: messageData })
      
      expect(controller.messagesListTarget.innerHTML).toContain("New message")
    })

    it("scrolls to bottom after receiving message", () => {
      const scrollSpy = jest.spyOn(controller, 'scrollToBottom')
      
      controller.received({
        message: {
          html: '<div>Test</div>'
        }
      })
      
      expect(scrollSpy).toHaveBeenCalled()
    })

    it("handles status changes", () => {
      const statusData = {
        type: "status_change",
        status: "completed"
      }
      
      controller.received(statusData)
      
      expect(controller.messageInputTarget.disabled).toBe(true)
    })
  })

  describe("#scrollToBottom", () => {
    it("scrolls messages container to bottom", () => {
      controller.messagesListTarget.scrollHeight = 1000
      controller.messagesListTarget.scrollTop = 0
      
      controller.scrollToBottom()
      
      expect(controller.messagesListTarget.scrollTop).toBe(1000)
    })
  })

  describe("auto-save draft", () => {
    it("saves draft to localStorage", () => {
      const setItemSpy = jest.spyOn(Storage.prototype, 'setItem')
      
      controller.messageInputTarget.value = "Draft message"
      controller.saveDraft()
      
      expect(setItemSpy).toHaveBeenCalledWith(
        "sub_agent_1_draft",
        "Draft message"
      )
    })

    it("restores draft on connect", () => {
      localStorage.setItem("sub_agent_1_draft", "Restored draft")
      
      controller.connect()
      
      expect(controller.messageInputTarget.value).toBe("Restored draft")
    })
  })
})