import consumer from "./consumer"

export default class SubAgentChannel {
  constructor(documentId, callbacks = {}) {
    this.documentId = documentId
    this.callbacks = callbacks
    this.subscription = null
  }
  
  connect() {
    this.subscription = consumer.subscriptions.create(
      { 
        channel: "SubAgentChannel",
        document_id: this.documentId
      },
      {
        connected: () => {
          console.log(`Connected to SubAgentChannel for document ${this.documentId}`)
          if (this.callbacks.connected) {
            this.callbacks.connected()
          }
        },
        
        disconnected: () => {
          console.log(`Disconnected from SubAgentChannel for document ${this.documentId}`)
          if (this.callbacks.disconnected) {
            this.callbacks.disconnected()
          }
        },
        
        received: (data) => {
          console.log("Received data from SubAgentChannel:", data)
          
          // Handle different message types
          switch(data.type) {
          case "new_message":
            this.handleNewMessage(data)
            break
              
          case "sub_agent_created":
            this.handleSubAgentCreated(data)
            break
              
          case "sub_agent_deleted":
            this.handleSubAgentDeleted(data)
            break
              
          case "typing_indicator":
            this.handleTypingIndicator(data)
            break
              
          case "merge_completed":
            this.handleMergeCompleted(data)
            break
              
          default:
            console.warn("Unknown message type:", data.type)
          }
        }
      }
    )
    
    return this.subscription
  }
  
  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }
  
  // Send message through the channel
  sendMessage(subAgentId, content) {
    if (!this.subscription) return
    
    this.subscription.perform("send_message", {
      sub_agent_id: subAgentId,
      content: content
    })
  }
  
  // Start typing indicator
  startTyping(subAgentId) {
    if (!this.subscription) return
    
    this.subscription.perform("typing", {
      sub_agent_id: subAgentId,
      typing: true
    })
  }
  
  // Stop typing indicator
  stopTyping(subAgentId) {
    if (!this.subscription) return
    
    this.subscription.perform("typing", {
      sub_agent_id: subAgentId,
      typing: false
    })
  }
  
  // Handle incoming new message
  handleNewMessage(data) {
    if (this.callbacks.onNewMessage) {
      this.callbacks.onNewMessage(data)
    }
    
    // Find and update the conversation controller
    const conversationController = document.querySelector("[data-controller~=\"sub-agent-conversation\"]")
    if (conversationController && conversationController._stimulusController) {
      conversationController._stimulusController.receiveMessage(data)
    }
  }
  
  // Handle sub-agent created
  handleSubAgentCreated(data) {
    if (this.callbacks.onSubAgentCreated) {
      this.callbacks.onSubAgentCreated(data)
    }
    
    // Update sidebar if exists
    const sidebarController = document.querySelector("[data-controller~=\"sub-agent-sidebar\"]")
    if (sidebarController && sidebarController._stimulusController) {
      sidebarController._stimulusController.addSubAgentToList(data.sub_agent)
    }
  }
  
  // Handle sub-agent deleted
  handleSubAgentDeleted(data) {
    if (this.callbacks.onSubAgentDeleted) {
      this.callbacks.onSubAgentDeleted(data)
    }
    
    // Remove from sidebar if exists
    const agentElement = document.querySelector(`[data-sub-agent-id="${data.sub_agent_id}"]`)
    if (agentElement) {
      agentElement.style.transition = "all 0.3s ease-out"
      agentElement.style.opacity = "0"
      agentElement.style.transform = "translateX(-20px)"
      
      setTimeout(() => agentElement.remove(), 300)
    }
  }
  
  // Handle typing indicator
  handleTypingIndicator(data) {
    if (this.callbacks.onTypingIndicator) {
      this.callbacks.onTypingIndicator(data)
    }
    
    const conversationController = document.querySelector("[data-controller~=\"sub-agent-conversation\"]")
    if (conversationController && conversationController._stimulusController) {
      if (data.typing) {
        conversationController._stimulusController.showTypingIndicator()
      } else {
        conversationController._stimulusController.hideTypingIndicator()
      }
    }
  }
  
  // Handle merge completed
  handleMergeCompleted(data) {
    if (this.callbacks.onMergeCompleted) {
      this.callbacks.onMergeCompleted(data)
    }
    
    // Show success notification
    this.showNotification("Content merged successfully!", "success")
    
    // Refresh page if needed
    if (data.refresh) {
      window.Turbo.visit(window.location.href)
    }
  }
  
  // Utility method for notifications
  showNotification(message, type = "info") {
    const notification = document.createElement("div")
    notification.className = `fixed top-4 right-4 z-50 px-6 py-3 rounded-lg text-white font-medium shadow-lg transition-all duration-300 ${
      type === "success" ? "bg-green-500" : 
        type === "error" ? "bg-red-500" : 
          "bg-blue-500"
    }`
    notification.style.transform = "translateX(400px)"
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Animate in
    requestAnimationFrame(() => {
      notification.style.transform = "translateX(0)"
    })
    
    // Auto dismiss
    setTimeout(() => {
      notification.style.transform = "translateX(400px)"
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
}

// Initialize sub-agent channel when document is ready
document.addEventListener("turbo:load", () => {
  const documentElement = document.querySelector("[data-document-id]")
  if (documentElement) {
    const documentId = documentElement.dataset.documentId
    
    // Check if we already have a channel for this document
    if (window.subAgentChannel) {
      window.subAgentChannel.disconnect()
    }
    
    // Create new channel
    window.subAgentChannel = new SubAgentChannel(documentId, {
      connected: () => {
        console.log("SubAgentChannel connected and ready")
      },
      onNewMessage: (data) => {
        console.log("New message received:", data)
      },
      onSubAgentCreated: (data) => {
        console.log("New sub-agent created:", data)
      },
      onSubAgentDeleted: (data) => {
        console.log("Sub-agent deleted:", data)
      }
    })
    
    // Connect to the channel
    window.subAgentChannel.connect()
  }
})

// Disconnect on page unload
document.addEventListener("turbo:before-cache", () => {
  if (window.subAgentChannel) {
    window.subAgentChannel.disconnect()
    window.subAgentChannel = null
  }
})