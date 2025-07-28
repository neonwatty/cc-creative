import { Application } from "@hotwired/stimulus"
import SubAgentSidebarController from "controllers/sub_agent_sidebar_controller"

describe("SubAgentSidebarController", () => {
  let application
  let controller
  let element

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="sub-agent-sidebar" 
           data-sub-agent-sidebar-document-id-value="1">
        <div data-sub-agent-sidebar-target="agentsList" class="sortable-container">
          <div class="sub-agent-item" data-sub-agent-id="1">
            <span data-sub-agent-sidebar-target="dragHandle">≡</span>
            Agent 1
          </div>
          <div class="sub-agent-item" data-sub-agent-id="2">
            <span data-sub-agent-sidebar-target="dragHandle">≡</span>
            Agent 2
          </div>
        </div>
        <button data-action="click->sub-agent-sidebar#createAgent">New Agent</button>
      </div>
    `

    application = Application.start()
    application.register("sub-agent-sidebar", SubAgentSidebarController)
    
    element = document.querySelector('[data-controller="sub-agent-sidebar"]')
    controller = application.getControllerForElementAndIdentifier(element, "sub-agent-sidebar")
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("#connect", () => {
    it("initializes Sortable on the agents list", () => {
      expect(controller.sortable).toBeDefined()
      expect(controller.sortable.el).toBe(controller.agentsListTarget)
    })

    it("sets correct Sortable options", () => {
      const options = controller.sortable.options
      expect(options.handle).toBe('[data-sub-agent-sidebar-target="dragHandle"]')
      expect(options.animation).toBe(150)
      expect(options.ghostClass).toBe('opacity-50')
    })
  })

  describe("#selectAgent", () => {
    it("dispatches agent-selected event with correct detail", () => {
      const eventSpy = jest.fn()
      element.addEventListener("agent-selected", eventSpy)
      
      const agentItem = element.querySelector('[data-sub-agent-id="1"]')
      agentItem.click()
      
      expect(eventSpy).toHaveBeenCalledTimes(1)
      expect(eventSpy.mock.calls[0][0].detail).toEqual({
        agentId: "1",
        documentId: "1"
      })
    })

    it("updates active state on agent items", () => {
      const agent1 = element.querySelector('[data-sub-agent-id="1"]')
      const agent2 = element.querySelector('[data-sub-agent-id="2"]')
      
      agent1.click()
      expect(agent1.classList.contains('active')).toBe(true)
      expect(agent2.classList.contains('active')).toBe(false)
      
      agent2.click()
      expect(agent1.classList.contains('active')).toBe(false)
      expect(agent2.classList.contains('active')).toBe(true)
    })
  })

  describe("#createAgent", () => {
    it("dispatches create-agent event", () => {
      const eventSpy = jest.fn()
      element.addEventListener("create-agent", eventSpy)
      
      const button = element.querySelector('[data-action="click->sub-agent-sidebar#createAgent"]')
      button.click()
      
      expect(eventSpy).toHaveBeenCalledTimes(1)
      expect(eventSpy.mock.calls[0][0].detail).toEqual({
        documentId: "1"
      })
    })
  })

  describe("#handleSort", () => {
    it("saves order after drag and drop", async () => {
      // Mock fetch
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ success: true })
      })
      
      // Simulate sort event
      const evt = {
        oldIndex: 0,
        newIndex: 1,
        item: element.querySelector('[data-sub-agent-id="1"]')
      }
      
      await controller.handleSort(evt)
      
      expect(fetch).toHaveBeenCalledWith(
        "/documents/1/sub_agents/reorder",
        expect.objectContaining({
          method: "PATCH",
          headers: expect.objectContaining({
            "Content-Type": "application/json"
          }),
          body: expect.stringContaining("agent_ids")
        })
      )
    })
  })

  describe("#refreshList", () => {
    it("fetches and updates the agents list", async () => {
      const mockHTML = '<div class="sub-agent-item" data-sub-agent-id="3">Agent 3</div>'
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        text: async () => mockHTML
      })
      
      await controller.refreshList()
      
      expect(fetch).toHaveBeenCalledWith("/documents/1/sub_agents")
      expect(controller.agentsListTarget.innerHTML).toContain("Agent 3")
    })
  })

  describe("keyboard navigation", () => {
    it("selects next agent on ArrowDown", () => {
      const agent1 = element.querySelector('[data-sub-agent-id="1"]')
      agent1.click() // Select first agent
      
      const event = new KeyboardEvent('keydown', { key: 'ArrowDown' })
      element.dispatchEvent(event)
      
      const agent2 = element.querySelector('[data-sub-agent-id="2"]')
      expect(agent2.classList.contains('active')).toBe(true)
    })

    it("selects previous agent on ArrowUp", () => {
      const agent2 = element.querySelector('[data-sub-agent-id="2"]')
      agent2.click() // Select second agent
      
      const event = new KeyboardEvent('keydown', { key: 'ArrowUp' })
      element.dispatchEvent(event)
      
      const agent1 = element.querySelector('[data-sub-agent-id="1"]')
      expect(agent1.classList.contains('active')).toBe(true)
    })
  })

  describe("filtering", () => {
    beforeEach(() => {
      document.body.innerHTML += `
        <select data-sub-agent-sidebar-target="statusFilter">
          <option value="">All</option>
          <option value="active">Active</option>
          <option value="completed">Completed</option>
        </select>
      `
    })

    it("filters agents by status", () => {
      const agent1 = element.querySelector('[data-sub-agent-id="1"]')
      const agent2 = element.querySelector('[data-sub-agent-id="2"]')
      
      agent1.dataset.status = "active"
      agent2.dataset.status = "completed"
      
      const filter = document.querySelector('[data-sub-agent-sidebar-target="statusFilter"]')
      filter.value = "active"
      filter.dispatchEvent(new Event('change'))
      
      expect(agent1.style.display).not.toBe('none')
      expect(agent2.style.display).toBe('none')
    })
  })
})