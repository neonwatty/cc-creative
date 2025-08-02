import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

export default class extends Controller {
  static targets = ["messageForm", "messageInput", "messagesList", "sendButton", "loadingIndicator", "errorMessage", "retryButton"]
  static values = { 
    documentId: Number,
    subAgentId: Number,
    sendUrl: String,
    channelId: String
  }
  
  connect() {
    console.log('SubAgentConversationController connected')
    this.setupAutoSave()
    this.setupKeyboardShortcuts()
    this.setupDragAndDrop()
    this.scrollToBottom()
    this.restoreDraft()
    this.connectToChannel()
  }
  
  disconnect() {
    this.removeKeyboardShortcuts()
    this.removeDragAndDrop()
    this.saveDraft()
  }
  
  // Handle message form submission
  async sendMessage(event) {
    event?.preventDefault()
    
    const message = this.messageInputTarget.value.trim()
    if (!message) return
    
    // Disable form and show loading state
    this.setLoadingState(true)
    
    // Add user message to UI immediately
    this.addMessageToUI({
      content: message,
      role: 'user',
      created_at: new Date().toISOString()
    })
    
    // Clear input and draft
    this.messageInputTarget.value = ''
    this.clearDraft()
    
    try {
      const response = await fetch(this.sendUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          message: {
            content: message
          }
        })
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      // Add assistant response to UI
      if (data.message) {
        this.addMessageToUI(data.message)
      }
      
      // Clear any error states
      this.clearError()
      
    } catch (error) {
      console.error('Failed to send message:', error)
      this.showError('Failed to send message. Please try again.')
      
      // Remove the user message that failed
      const lastMessage = this.messagesListTarget.lastElementChild
      if (lastMessage && lastMessage.dataset.role === 'user') {
        lastMessage.remove()
      }
      
      // Restore the message to input for retry
      this.messageInputTarget.value = message
    } finally {
      this.setLoadingState(false)
    }
  }
  
  // Add message to conversation UI
  addMessageToUI(message) {
    if (!this.hasMessagesListTarget) return
    
    const isUser = message.role === 'user'
    const messageHtml = `
      <div class="flex ${isUser ? 'justify-end' : 'justify-start'} mb-4 message-item"
           data-role="${message.role}"
           data-message-id="${message.id || 'temp-' + Date.now()}">
        <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
          isUser 
            ? 'bg-blue-500 text-white' 
            : 'bg-gray-200 text-gray-800'
        }">
          <p class="text-sm whitespace-pre-wrap">${this.escapeHtml(message.content)}</p>
          <p class="text-xs ${isUser ? 'text-blue-100' : 'text-gray-500'} mt-1">
            ${new Date(message.created_at).toLocaleTimeString()}
          </p>
        </div>
      </div>
    `
    
    // Add with animation
    const messageElement = document.createElement('div')
    messageElement.innerHTML = messageHtml
    const messageItem = messageElement.firstElementChild
    
    messageItem.style.opacity = '0'
    messageItem.style.transform = 'translateY(10px)'
    
    this.messagesListTarget.appendChild(messageItem)
    
    // Animate in
    requestAnimationFrame(() => {
      messageItem.style.transition = 'all 0.3s ease-out'
      messageItem.style.opacity = '1'
      messageItem.style.transform = 'translateY(0)'
    })
    
    // Scroll to bottom
    this.scrollToBottom()
  }
  
  // Show typing indicator for assistant
  showTypingIndicator() {
    if (!this.hasMessagesListTarget) return
    
    const typingHtml = `
      <div class="flex justify-start mb-4 typing-indicator" data-role="typing">
        <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg bg-gray-200">
          <div class="flex space-x-2">
            <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 0ms"></div>
            <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 150ms"></div>
            <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 300ms"></div>
          </div>
        </div>
      </div>
    `
    
    const typingElement = document.createElement('div')
    typingElement.innerHTML = typingHtml
    this.messagesListTarget.appendChild(typingElement.firstElementChild)
    
    this.scrollToBottom()
  }
  
  hideTypingIndicator() {
    const typingIndicator = this.messagesListTarget.querySelector('.typing-indicator')
    if (typingIndicator) {
      typingIndicator.remove()
    }
  }
  
  // Auto-scroll to bottom of conversation
  scrollToBottom() {
    if (!this.hasMessagesListTarget) return
    
    requestAnimationFrame(() => {
      this.messagesListTarget.scrollTop = this.messagesListTarget.scrollHeight
    })
  }
  
  // Error handling
  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove('hidden')
    }
  }
  
  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('hidden')
      this.errorMessageTarget.textContent = ''
    }
  }
  
  retryLastMessage() {
    this.clearError()
    this.sendMessage()
  }
  
  // Loading states
  setLoadingState(loading) {
    if (this.hasMessageInputTarget) {
      this.messageInputTarget.disabled = loading
    }
    
    if (this.hasSendButtonTarget) {
      this.sendButtonTarget.disabled = loading
      
      if (loading) {
        this.sendButtonTarget.innerHTML = `
          <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        `
        this.showTypingIndicator()
      } else {
        this.sendButtonTarget.innerHTML = `
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
          </svg>
        `
        this.hideTypingIndicator()
      }
    }
    
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.style.display = loading ? 'flex' : 'none'
    }
  }
  
  // Draft management
  setupAutoSave() {
    this.saveDraft = debounce(1000, () => {
      const content = this.messageInputTarget?.value
      if (content) {
        const draftKey = `sub-agent-draft-${this.documentIdValue}-${this.subAgentIdValue}`
        localStorage.setItem(draftKey, content)
      }
    })
    
    if (this.hasMessageInputTarget) {
      this.messageInputTarget.addEventListener('input', this.saveDraft)
    }
  }
  
  restoreDraft() {
    if (!this.hasMessageInputTarget) return
    
    const draftKey = `sub-agent-draft-${this.documentIdValue}-${this.subAgentIdValue}`
    const draft = localStorage.getItem(draftKey)
    
    if (draft) {
      this.messageInputTarget.value = draft
      this.showDraftNotification()
    }
  }
  
  clearDraft() {
    const draftKey = `sub-agent-draft-${this.documentIdValue}-${this.subAgentIdValue}`
    localStorage.removeItem(draftKey)
  }
  
  showDraftNotification() {
    const notification = document.createElement('div')
    notification.className = 'absolute top-0 left-0 right-0 bg-yellow-100 text-yellow-800 text-xs px-3 py-1 text-center'
    notification.textContent = 'Draft restored'
    
    this.messageFormTarget.style.position = 'relative'
    this.messageFormTarget.appendChild(notification)
    
    setTimeout(() => {
      notification.style.transition = 'opacity 0.3s'
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 300)
    }, 2000)
  }
  
  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    this.keyboardHandler = (event) => {
      // Cmd/Ctrl + Enter to send message
      if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
        event.preventDefault()
        if (this.messageInputTarget?.value.trim()) {
          this.sendMessage()
        }
      }
      
      // Escape to clear input
      if (event.key === 'Escape' && document.activeElement === this.messageInputTarget) {
        event.preventDefault()
        this.messageInputTarget.value = ''
        this.clearDraft()
      }
    }
    
    if (this.hasMessageInputTarget) {
      this.messageInputTarget.addEventListener('keydown', this.keyboardHandler)
    }
  }
  
  removeKeyboardShortcuts() {
    if (this.keyboardHandler && this.hasMessageInputTarget) {
      this.messageInputTarget.removeEventListener('keydown', this.keyboardHandler)
    }
  }
  
  // Handle incoming messages from ActionCable
  receiveMessage(data) {
    if (data.message && data.message.sub_agent_id === this.subAgentIdValue) {
      // Hide typing indicator first
      this.hideTypingIndicator()
      
      // Add message to UI
      this.addMessageToUI(data.message)
    }
  }
  
  // Utility methods
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  insertTextAtCursor(text) {
    if (!this.hasMessageInputTarget) return

    const textarea = this.messageInputTarget
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const currentValue = textarea.value

    // Insert text at cursor position
    const newValue = currentValue.slice(0, start) + text + currentValue.slice(end)
    textarea.value = newValue

    // Move cursor to end of inserted text
    const newCursorPosition = start + text.length
    textarea.setSelectionRange(newCursorPosition, newCursorPosition)

    // Focus the textarea
    textarea.focus()
  }
  
  // Drag and drop support
  setupDragAndDrop() {
    if (!this.hasMessageInputTarget) return
    
    // Make input area a drop zone
    this.messageInputTarget.addEventListener('dragover', this.handleDragOver.bind(this))
    this.messageInputTarget.addEventListener('drop', this.handleDrop.bind(this))
    this.messageInputTarget.addEventListener('dragleave', this.handleDragLeave.bind(this))
  }
  
  removeDragAndDrop() {
    if (!this.hasMessageInputTarget) return
    
    this.messageInputTarget.removeEventListener('dragover', this.handleDragOver)
    this.messageInputTarget.removeEventListener('drop', this.handleDrop)
    this.messageInputTarget.removeEventListener('dragleave', this.handleDragLeave)
  }
  
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    this.messageInputTarget.classList.add('border-blue-500', 'bg-blue-50')
  }
  
  handleDragLeave(event) {
    this.messageInputTarget.classList.remove('border-blue-500', 'bg-blue-50')
  }
  
  handleDrop(event) {
    event.preventDefault()
    this.messageInputTarget.classList.remove('border-blue-500', 'bg-blue-50')
    
    try {
      // Check if it's a context item being dropped
      const contextItemData = event.dataTransfer.getData('application/json')
      if (contextItemData) {
        const contextItem = JSON.parse(contextItemData)
        
        // Insert content at cursor position
        const currentValue = this.messageInputTarget.value
        const cursorPos = this.messageInputTarget.selectionStart
        
        const textToInsert = `\n[Context: ${contextItem.title}]\n${contextItem.content}\n`
        
        const newValue = 
          currentValue.slice(0, cursorPos) + 
          textToInsert + 
          currentValue.slice(cursorPos)
        
        this.messageInputTarget.value = newValue
        
        // Move cursor after inserted text
        const newCursorPos = cursorPos + textToInsert.length
        this.messageInputTarget.setSelectionRange(newCursorPos, newCursorPos)
        
        // Save draft
        this.saveDraft()
        
        // Show feedback
        this.showDropFeedback('Content added to message')
      } else {
        // Handle text drop
        const text = event.dataTransfer.getData('text/plain')
        if (text) {
          this.insertTextAtCursor(text)
          this.saveDraft()
        }
      }
    } catch (error) {
      console.error('Failed to handle drop:', error)
    }
  }
  
  showDropFeedback(message) {
    const feedback = document.createElement('div')
    feedback.className = 'absolute bottom-full left-0 mb-2 px-3 py-1 bg-green-500 text-white text-sm rounded-lg shadow-lg'
    feedback.textContent = message
    
    this.messageInputTarget.parentElement.style.position = 'relative'
    this.messageInputTarget.parentElement.appendChild(feedback)
    
    setTimeout(() => {
      feedback.style.transition = 'opacity 0.3s'
      feedback.style.opacity = '0'
      setTimeout(() => feedback.remove(), 300)
    }, 2000)
  }
  
  // Connect to ActionCable channel
  connectToChannel() {
    if (window.subAgentChannel && this.subAgentIdValue) {
      // The global channel is already connected in sub_agent_channel.js
      console.log('Connected to SubAgentChannel for conversation')
    }
  }
}