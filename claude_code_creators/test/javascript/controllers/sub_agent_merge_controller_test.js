import { Application } from "@hotwired/stimulus"
import SubAgentMergeController from "controllers/sub_agent_merge_controller"

describe("SubAgentMergeController", () => {
  let application
  let controller
  let element

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="sub-agent-merge"
           data-sub-agent-merge-sub-agent-id-value="1"
           data-sub-agent-merge-document-id-value="1">
        <div data-sub-agent-merge-target="preview">
          <div class="message">First response</div>
          <div class="message">Second response</div>
        </div>
        <div data-sub-agent-merge-target="formatPreview" class="hidden">
          <!-- Format preview will be shown here -->
        </div>
        <form>
          <input type="radio" name="merge_position" value="end" checked>
          <input type="radio" name="merge_position" value="cursor">
          <input type="radio" name="merge_position" value="beginning">
          
          <input type="checkbox" name="include_timestamps" data-action="change->sub-agent-merge#updatePreview">
          <input type="checkbox" name="include_agent_name" data-action="change->sub-agent-merge#updatePreview">
          <input type="checkbox" name="add_separator" data-action="change->sub-agent-merge#updatePreview">
          
          <input type="text" name="custom_separator" 
                 data-sub-agent-merge-target="customSeparator"
                 value="---">
        </form>
        
        <button data-action="click->sub-agent-merge#merge">Merge Content</button>
        <button data-action="click->sub-agent-merge#cancel">Cancel</button>
        
        <div data-sub-agent-merge-target="loadingState" class="hidden">
          Merging...
        </div>
        <div data-sub-agent-merge-target="successMessage" class="hidden">
          Success!
        </div>
        <div data-sub-agent-merge-target="confirmDialog" class="hidden">
          Are you sure?
        </div>
      </div>
    `

    application = Application.start()
    application.register("sub-agent-merge", SubAgentMergeController)
    
    element = document.querySelector('[data-controller="sub-agent-merge"]')
    controller = application.getControllerForElementAndIdentifier(element, "sub-agent-merge")
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("#connect", () => {
    it("initializes with correct values", () => {
      expect(controller.subAgentIdValue).toBe("1")
      expect(controller.documentIdValue).toBe("1")
    })

    it("sets up initial preview", () => {
      expect(controller.previewTarget).toBeDefined()
      expect(controller.previewTarget.children.length).toBe(2)
    })
  })

  describe("#merge", () => {
    beforeEach(() => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ 
          success: true, 
          message: "Content merged successfully",
          document_url: "/documents/1"
        })
      })
    })

    it("sends merge request with correct parameters", async () => {
      await controller.merge()

      expect(fetch).toHaveBeenCalledWith(
        "/documents/1/sub_agents/1/merge_content",
        expect.objectContaining({
          method: "POST",
          headers: expect.objectContaining({
            "Content-Type": "application/json"
          }),
          body: expect.stringContaining('"position":"end"')
        })
      )
    })

    it("includes selected options in merge request", async () => {
      // Select options
      element.querySelector('input[name="include_timestamps"]').checked = true
      element.querySelector('input[name="include_agent_name"]').checked = true
      element.querySelector('input[name="add_separator"]').checked = true
      
      await controller.merge()

      const body = JSON.parse(fetch.mock.calls[0][1].body)
      expect(body.include_timestamps).toBe(true)
      expect(body.include_agent_name).toBe(true)
      expect(body.add_separator).toBe(true)
      expect(body.custom_separator).toBe("---")
    })

    it("shows loading state during merge", async () => {
      const loadingState = controller.loadingStateTarget
      
      const mergePromise = controller.merge()
      expect(loadingState.classList.contains('hidden')).toBe(false)
      
      await mergePromise
      expect(loadingState.classList.contains('hidden')).toBe(true)
    })

    it("shows success message after merge", async () => {
      await controller.merge()
      
      expect(controller.successMessageTarget.classList.contains('hidden')).toBe(false)
      expect(controller.successMessageTarget.textContent).toContain("Content merged successfully")
    })

    it("handles merge errors", async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))
      const alertSpy = jest.spyOn(window, 'alert').mockImplementation()
      
      await controller.merge()
      
      expect(alertSpy).toHaveBeenCalledWith("Error merging content: Network error")
    })

    it("confirms before merging", async () => {
      const confirmSpy = jest.spyOn(controller, 'showConfirmDialog').mockResolvedValue(true)
      
      await controller.merge()
      
      expect(confirmSpy).toHaveBeenCalled()
      expect(fetch).toHaveBeenCalled()
    })

    it("cancels merge if not confirmed", async () => {
      jest.spyOn(controller, 'showConfirmDialog').mockResolvedValue(false)
      
      await controller.merge()
      
      expect(fetch).not.toHaveBeenCalled()
    })
  })

  describe("#cancel", () => {
    it("dispatches cancel event", () => {
      const eventSpy = jest.fn()
      element.addEventListener("merge-cancelled", eventSpy)
      
      controller.cancel()
      
      expect(eventSpy).toHaveBeenCalledTimes(1)
    })

    it("hides the merge interface", () => {
      controller.cancel()
      
      expect(element.style.display).toBe('none')
    })
  })

  describe("#updatePreview", () => {
    it("updates format preview when options change", () => {
      const formatPreview = controller.formatPreviewTarget
      
      element.querySelector('input[name="include_timestamps"]').checked = true
      element.querySelector('input[name="include_agent_name"]').checked = true
      
      controller.updatePreview()
      
      expect(formatPreview.classList.contains('hidden')).toBe(false)
      expect(formatPreview.innerHTML).toContain("Preview")
    })

    it("shows custom separator when option is selected", () => {
      element.querySelector('input[name="add_separator"]').checked = true
      
      controller.updatePreview()
      
      const preview = controller.formatPreviewTarget.textContent
      expect(preview).toContain("---")
    })

    it("generates correct preview format", () => {
      element.querySelector('input[name="include_agent_name"]').checked = true
      element.querySelector('input[name="include_timestamps"]').checked = true
      
      controller.updatePreview()
      
      const preview = controller.formatPreviewTarget.innerHTML
      expect(preview).toContain("Agent:")
      expect(preview).toContain("Timestamp:")
    })
  })

  describe("#showConfirmDialog", () => {
    it("shows confirmation dialog", async () => {
      const confirmDialog = controller.confirmDialogTarget
      
      const confirmPromise = controller.showConfirmDialog()
      expect(confirmDialog.classList.contains('hidden')).toBe(false)
      
      // Simulate clicking confirm
      confirmDialog.querySelector('[data-confirm="yes"]')?.click()
      
      const result = await confirmPromise
      expect(result).toBe(true)
    })
  })

  describe("position selection", () => {
    it("gets selected merge position", () => {
      element.querySelector('input[value="cursor"]').checked = true
      
      const position = controller.getSelectedPosition()
      expect(position).toBe("cursor")
    })

    it("defaults to 'end' position", () => {
      // Uncheck all radios
      element.querySelectorAll('input[name="merge_position"]').forEach(radio => {
        radio.checked = false
      })
      
      const position = controller.getSelectedPosition()
      expect(position).toBe("end")
    })
  })

  describe("content preparation", () => {
    it("prepares content with selected formatting", () => {
      const content = controller.prepareContent({
        include_timestamps: true,
        include_agent_name: true,
        add_separator: true,
        custom_separator: "==="
      })
      
      expect(content).toContain("First response")
      expect(content).toContain("Second response")
      expect(content).toContain("===")
    })

    it("excludes formatting when options not selected", () => {
      const content = controller.prepareContent({
        include_timestamps: false,
        include_agent_name: false,
        add_separator: false
      })
      
      expect(content).toBe("First response\n\nSecond response")
    })
  })

  describe("keyboard shortcuts", () => {
    it("triggers merge on Cmd+Enter", () => {
      const mergeSpy = jest.spyOn(controller, 'merge')
      
      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        metaKey: true
      })
      element.dispatchEvent(event)
      
      expect(mergeSpy).toHaveBeenCalled()
    })

    it("cancels on Escape", () => {
      const cancelSpy = jest.spyOn(controller, 'cancel')
      
      const event = new KeyboardEvent('keydown', {
        key: 'Escape'
      })
      element.dispatchEvent(event)
      
      expect(cancelSpy).toHaveBeenCalled()
    })
  })

  describe("error handling", () => {
    it("handles network errors gracefully", async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error("Network error"))
      
      await controller.merge()
      
      expect(controller.loadingStateTarget.classList.contains('hidden')).toBe(true)
      expect(controller.successMessageTarget.classList.contains('hidden')).toBe(true)
    })

    it("handles server errors", async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: false,
        status: 422,
        json: async () => ({ error: "Invalid merge parameters" })
      })
      const alertSpy = jest.spyOn(window, 'alert').mockImplementation()
      
      await controller.merge()
      
      expect(alertSpy).toHaveBeenCalledWith("Error: Invalid merge parameters")
    })
  })

  describe("large content handling", () => {
    it("warns about large merges", async () => {
      // Add many messages to simulate large content
      for (let i = 0; i < 100; i++) {
        const message = document.createElement('div')
        message.className = 'message'
        message.textContent = 'A'.repeat(1000)
        controller.previewTarget.appendChild(message)
      }
      
      const warningSpy = jest.spyOn(window, 'confirm').mockReturnValue(true)
      
      await controller.merge()
      
      expect(warningSpy).toHaveBeenCalledWith(
        expect.stringContaining("large amount of content")
      )
    })
  })
})