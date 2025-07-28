import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "agentType", "newAgentButton", "form", "agentsList", "loadingSpinner"]
  static values = { 
    documentId: Number,
    createUrl: String
  }
  
  connect() {
    console.log('SubAgentSidebarController connected')
    this.setupKeyboardShortcuts()
    this.loadSubAgents()
  }
  
  disconnect() {
    this.removeKeyboardShortcuts()
  }
  
  // Toggle dropdown visibility
  toggleDropdown(event) {
    event?.preventDefault()
    event?.stopPropagation()
    
    if (this.hasDropdownTarget) {
      const isHidden = this.dropdownTarget.classList.contains('hidden')
      
      if (isHidden) {
        this.showDropdown()
      } else {
        this.hideDropdown()
      }
    }
  }
  
  showDropdown() {
    this.dropdownTarget.classList.remove('hidden')
    this.dropdownTarget.classList.add('animate-fade-in')
    
    // Close dropdown when clicking outside
    setTimeout(() => {
      document.addEventListener('click', this.outsideClickHandler)
    }, 0)
  }
  
  hideDropdown() {
    this.dropdownTarget.classList.add('hidden')
    this.dropdownTarget.classList.remove('animate-fade-in')
    document.removeEventListener('click', this.outsideClickHandler)
  }
  
  outsideClickHandler = (event) => {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }
  
  // Select agent type from dropdown
  selectAgentType(event) {
    event.preventDefault()
    const agentType = event.currentTarget.dataset.agentType
    const agentLabel = event.currentTarget.textContent.trim()
    
    // Update hidden input value
    if (this.hasAgentTypeTarget) {
      this.agentTypeTarget.value = agentType
    }
    
    // Update button text
    if (this.hasNewAgentButtonTarget) {
      this.newAgentButtonTarget.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
        </svg>
        New ${agentLabel} Agent
      `
    }
    
    // Hide dropdown
    this.hideDropdown()
    
    // Submit form to create new agent
    this.createSubAgent()
  }
  
  // Create new sub-agent
  async createSubAgent() {
    if (!this.hasAgentTypeTarget || !this.agentTypeTarget.value) {
      console.error('No agent type selected')
      return
    }
    
    // Show loading state
    this.setLoadingState(true)
    
    try {
      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          sub_agent: {
            agent_type: this.agentTypeTarget.value
          }
        })
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      // Add new sub-agent to list without page reload
      this.addSubAgentToList(data.sub_agent)
      
      // Reset form
      this.resetForm()
      
      // Show success notification
      this.showNotification('Sub-agent created successfully!', 'success')
      
    } catch (error) {
      console.error('Failed to create sub-agent:', error)
      this.showNotification('Failed to create sub-agent. Please try again.', 'error')
    } finally {
      this.setLoadingState(false)
    }
  }
  
  // Add new sub-agent to the UI
  addSubAgentToList(subAgent) {
    if (!this.hasAgentsListTarget) return
    
    const agentHtml = `
      <div class="p-4 bg-white border rounded-lg hover:shadow-sm transition-shadow duration-200" 
           data-sub-agent-id="${subAgent.id}">
        <div class="flex justify-between items-start mb-2">
          <h4 class="font-medium text-gray-900">${this.formatAgentType(subAgent.agent_type)}</h4>
          <span class="text-xs text-gray-500">${new Date(subAgent.created_at).toLocaleTimeString()}</span>
        </div>
        <p class="text-sm text-gray-600">Ready to assist with ${subAgent.agent_type} tasks</p>
        <div class="mt-3 flex gap-2">
          <a href="/documents/${this.documentIdValue}/sub_agents/${subAgent.id}" 
             class="text-sm text-blue-600 hover:text-blue-800"
             data-turbo-frame="sub_agent_conversation">
            Open Conversation
          </a>
          <button class="text-sm text-red-600 hover:text-red-800"
                  data-action="click->sub-agent-sidebar#deleteAgent"
                  data-sub-agent-id="${subAgent.id}">
            Delete
          </button>
        </div>
      </div>
    `
    
    // Add to top of list with animation
    const newElement = document.createElement('div')
    newElement.innerHTML = agentHtml
    const agentElement = newElement.firstElementChild
    
    agentElement.style.opacity = '0'
    agentElement.style.transform = 'translateY(-10px)'
    
    this.agentsListTarget.prepend(agentElement)
    
    // Animate in
    requestAnimationFrame(() => {
      agentElement.style.transition = 'all 0.3s ease-out'
      agentElement.style.opacity = '1'
      agentElement.style.transform = 'translateY(0)'
    })
    
    // Remove empty state if exists
    const emptyState = this.agentsListTarget.querySelector('.empty-state')
    if (emptyState) {
      emptyState.remove()
    }
  }
  
  // Delete sub-agent
  async deleteAgent(event) {
    event.preventDefault()
    
    const subAgentId = event.currentTarget.dataset.subAgentId
    const agentElement = this.element.querySelector(`[data-sub-agent-id="${subAgentId}"]`)
    
    if (!confirm('Are you sure you want to delete this sub-agent?')) {
      return
    }
    
    try {
      const response = await fetch(`/documents/${this.documentIdValue}/sub_agents/${subAgentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content,
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      // Animate out and remove
      if (agentElement) {
        agentElement.style.transition = 'all 0.3s ease-out'
        agentElement.style.opacity = '0'
        agentElement.style.transform = 'translateX(-20px)'
        
        setTimeout(() => {
          agentElement.remove()
          
          // Show empty state if no agents left
          if (this.agentsListTarget.children.length === 0) {
            this.showEmptyState()
          }
        }, 300)
      }
      
      this.showNotification('Sub-agent deleted successfully', 'success')
      
    } catch (error) {
      console.error('Failed to delete sub-agent:', error)
      this.showNotification('Failed to delete sub-agent', 'error')
    }
  }
  
  // Load existing sub-agents
  async loadSubAgents() {
    if (!this.hasAgentsListTarget) return
    
    try {
      const response = await fetch(`/documents/${this.documentIdValue}/sub_agents`, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      if (data.sub_agents && data.sub_agents.length > 0) {
        this.renderSubAgents(data.sub_agents)
      } else {
        this.showEmptyState()
      }
      
    } catch (error) {
      console.error('Failed to load sub-agents:', error)
      this.showEmptyState()
    }
  }
  
  renderSubAgents(subAgents) {
    if (!this.hasAgentsListTarget) return
    
    this.agentsListTarget.innerHTML = subAgents.map(agent => `
      <div class="p-4 bg-white border rounded-lg hover:shadow-sm transition-shadow duration-200" 
           data-sub-agent-id="${agent.id}">
        <div class="flex justify-between items-start mb-2">
          <h4 class="font-medium text-gray-900">${this.formatAgentType(agent.agent_type)}</h4>
          <span class="text-xs text-gray-500">${new Date(agent.created_at).toLocaleTimeString()}</span>
        </div>
        <p class="text-sm text-gray-600">Ready to assist with ${agent.agent_type} tasks</p>
        <div class="mt-3 flex gap-2">
          <a href="/documents/${this.documentIdValue}/sub_agents/${agent.id}" 
             class="text-sm text-blue-600 hover:text-blue-800"
             data-turbo-frame="sub_agent_conversation">
            Open Conversation
          </a>
          <button class="text-sm text-red-600 hover:text-red-800"
                  data-action="click->sub-agent-sidebar#deleteAgent"
                  data-sub-agent-id="${agent.id}">
            Delete
          </button>
        </div>
      </div>
    `).join('')
  }
  
  showEmptyState() {
    if (!this.hasAgentsListTarget) return
    
    this.agentsListTarget.innerHTML = `
      <div class="empty-state text-center py-8 text-gray-500">
        <svg class="mx-auto h-12 w-12 text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z">
          </path>
        </svg>
        <p class="text-sm">No sub-agents yet</p>
        <p class="text-xs mt-1">Create one using the dropdown above</p>
      </div>
    `
  }
  
  // Helper methods
  formatAgentType(type) {
    const typeMap = {
      'research': 'Research',
      'writing': 'Writing', 
      'analysis': 'Analysis',
      'coding': 'Coding',
      'review': 'Review'
    }
    return typeMap[type] || type
  }
  
  resetForm() {
    if (this.hasAgentTypeTarget) {
      this.agentTypeTarget.value = ''
    }
    
    if (this.hasNewAgentButtonTarget) {
      this.newAgentButtonTarget.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
        </svg>
        New Sub-Agent
      `
    }
  }
  
  setLoadingState(loading) {
    if (this.hasNewAgentButtonTarget) {
      this.newAgentButtonTarget.disabled = loading
      
      if (loading) {
        this.newAgentButtonTarget.classList.add('opacity-60', 'cursor-not-allowed')
      } else {
        this.newAgentButtonTarget.classList.remove('opacity-60', 'cursor-not-allowed')
      }
    }
    
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.style.display = loading ? 'block' : 'none'
    }
  }
  
  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-6 py-3 rounded-lg text-white font-medium shadow-lg transition-all duration-300 ${
      type === 'success' ? 'bg-green-500' : 
      type === 'error' ? 'bg-red-500' : 
      'bg-blue-500'
    }`
    notification.style.transform = 'translateX(400px)'
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Animate in
    requestAnimationFrame(() => {
      notification.style.transform = 'translateX(0)'
    })
    
    // Auto dismiss
    setTimeout(() => {
      notification.style.transform = 'translateX(400px)'
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
  
  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    this.keyboardHandler = (event) => {
      // Cmd/Ctrl + K for quick sub-agent access
      if ((event.metaKey || event.ctrlKey) && event.key === 'k' && event.shiftKey) {
        event.preventDefault()
        this.toggleDropdown()
      }
    }
    
    document.addEventListener('keydown', this.keyboardHandler)
  }
  
  removeKeyboardShortcuts() {
    if (this.keyboardHandler) {
      document.removeEventListener('keydown', this.keyboardHandler)
    }
  }
}