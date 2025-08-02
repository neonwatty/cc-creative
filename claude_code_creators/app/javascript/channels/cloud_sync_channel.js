import consumer from "channels/consumer"

class CloudSyncChannel {
  constructor() {
    this.channel = null
    this.callbacks = new Map()
    this.currentUser = null
    this.integrationId = null
  }

  // Connect to the channel
  connect(userId, integrationId = null) {
    if (this.channel) {
      this.disconnect()
    }

    this.currentUser = userId
    this.integrationId = integrationId

    const params = { user_id: userId }
    if (integrationId) {
      params.integration_id = integrationId
    }

    this.channel = consumer.subscriptions.create(
      { channel: "CloudSyncChannel", ...params },
      {
        connected: () => {
          console.log("Connected to CloudSyncChannel")
          this.trigger("connected")
        },

        disconnected: () => {
          console.log("Disconnected from CloudSyncChannel")
          this.trigger("disconnected")
        },

        received: (data) => {
          console.log("Received cloud sync data:", data)
          this.handleMessage(data)
        }
      }
    )
  }

  // Disconnect from the channel
  disconnect() {
    if (this.channel) {
      consumer.subscriptions.remove(this.channel)
      this.channel = null
    }
  }

  // Handle incoming messages
  handleMessage(data) {
    const { event, integration_id, error } = data

    if (error) {
      this.trigger("error", { error, integration_id })
      return
    }

    switch (event) {
    case "sync_started":
      this.trigger("sync_started", data)
      break
    case "sync_progress":
      this.trigger("sync_progress", data)
      break
    case "sync_completed":
      this.trigger("sync_completed", data)
      break
    case "sync_error":
      this.trigger("sync_error", data)
      break
    case "file_imported":
      this.trigger("file_imported", data)
      break
    case "file_exported":
      this.trigger("file_exported", data)
      break
    default:
      // Handle status updates and other messages
      if (data.integrations) {
        this.trigger("status_update", data)
      } else if (integration_id) {
        this.trigger("integration_status", data)
      }
    }
  }

  // Request sync status
  getSyncStatus(integrationId = null) {
    if (!this.channel) return

    this.channel.perform("get_sync_status", {
      integration_id: integrationId
    })
  }

  // Trigger sync for an integration
  triggerSync(integrationId) {
    if (!this.channel) return

    this.channel.perform("trigger_sync", {
      integration_id: integrationId
    })
  }

  // Subscribe to events
  on(event, callback) {
    if (!this.callbacks.has(event)) {
      this.callbacks.set(event, [])
    }
    this.callbacks.get(event).push(callback)
  }

  // Unsubscribe from events
  off(event, callback) {
    if (this.callbacks.has(event)) {
      const callbacks = this.callbacks.get(event)
      const index = callbacks.indexOf(callback)
      if (index > -1) {
        callbacks.splice(index, 1)
      }
    }
  }

  // Trigger event callbacks
  trigger(event, data = {}) {
    if (this.callbacks.has(event)) {
      this.callbacks.get(event).forEach(callback => {
        try {
          callback(data)
        } catch (error) {
          console.error(`Error in CloudSyncChannel callback for ${event}:`, error)
        }
      })
    }
  }

  // Helper method to check if connected
  isConnected() {
    return this.channel && this.channel.consumer.connection.isOpen()
  }
}

// Create global instance
window.cloudSyncChannel = new CloudSyncChannel()

// Auto-connect if user data is available
document.addEventListener("DOMContentLoaded", () => {
  const userIdElement = document.querySelector("[data-user-id]")
  const integrationIdElement = document.querySelector("[data-integration-id]")
  
  if (userIdElement) {
    const userId = userIdElement.dataset.userId
    const integrationId = integrationIdElement?.dataset.integrationId
    
    window.cloudSyncChannel.connect(userId, integrationId)
  }
})

// Integrate with Stimulus controllers
document.addEventListener("cloud-sync:connect", (event) => {
  const { userId, integrationId } = event.detail
  window.cloudSyncChannel.connect(userId, integrationId)
})

document.addEventListener("cloud-sync:disconnect", () => {
  window.cloudSyncChannel.disconnect()
})

document.addEventListener("cloud-sync:get-status", (event) => {
  const { integrationId } = event.detail
  window.cloudSyncChannel.getSyncStatus(integrationId)
})

document.addEventListener("cloud-sync:trigger-sync", (event) => {
  const { integrationId } = event.detail
  window.cloudSyncChannel.triggerSync(integrationId)
})

export default window.cloudSyncChannel