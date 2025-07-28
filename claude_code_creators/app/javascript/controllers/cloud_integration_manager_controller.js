import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cloud-integration-manager"
export default class extends Controller {
  static targets = [
    "integrationList",
    "statusContainer", 
    "addProviderModal",
    "providerCards",
    "syncStatusGlobal",
    "errorContainer",
    "loadingSpinner"
  ]

  static values = {
    userId: String,
    refreshInterval: { type: Number, default: 30000 }, // 30 seconds
    autoSync: { type: Boolean, default: true }
  }

  static classes = [
    "loading",
    "error",
    "success",
    "syncing",
    "connected",
    "disconnected"
  ]

  connect() {
    // Track integration states
    this.integrations = new Map()
    this.syncStatus = new Map()
    
    // Initialize periodic refresh
    this.startPeriodicRefresh()
    
    // Load initial data
    this.loadIntegrations()
    
    // Listen for integration events
    this.setupEventListeners()
    
    // Setup Action Cable connection
    this.setupActionCable()
  }

  disconnect() {
    this.stopPeriodicRefresh()
    this.cleanupEventListeners()
    this.disconnectActionCable()
  }

  // Setup event listeners
  setupEventListeners() {
    // Listen for OAuth completion events
    this.element.addEventListener('oauth:success', this.handleOAuthSuccess.bind(this))
    this.element.addEventListener('oauth:error', this.handleOAuthError.bind(this))
    
    // Listen for sync events
    this.element.addEventListener('sync:started', this.handleSyncStarted.bind(this))
    this.element.addEventListener('sync:completed', this.handleSyncCompleted.bind(this))
    this.element.addEventListener('sync:error', this.handleSyncError.bind(this))
    
    // Listen for file operation events
    this.element.addEventListener('file:imported', this.handleFileImported.bind(this))
    this.element.addEventListener('file:exported', this.handleFileExported.bind(this))
  }

  cleanupEventListeners() {
    // Remove event listeners to prevent memory leaks
    this.element.removeEventListener('oauth:success', this.handleOAuthSuccess.bind(this))
    this.element.removeEventListener('oauth:error', this.handleOAuthError.bind(this))
  }

  // Load all integrations
  async loadIntegrations() {
    try {
      this.showLoading(true)
      
      const response = await fetch('/cloud_integrations', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()
      this.renderIntegrations(data)
      
    } catch (error) {
      this.showError(`Failed to load integrations: ${error.message}`)
    } finally {
      this.showLoading(false)
    }
  }

  // Render integrations in the UI
  renderIntegrations(data) {
    if (!data.integrations || !data.available_providers) {
      this.showError('Invalid integration data received')
      return
    }

    // Update integration tracking
    data.integrations.forEach(integration => {
      this.integrations.set(integration.id, integration)
    })

    // Render provider cards
    this.renderProviderCards(data.available_providers, data.integrations)
    
    // Update global sync status
    this.updateGlobalSyncStatus(data.integrations)
  }

  // Render provider connection cards
  renderProviderCards(availableProviders, connectedIntegrations) {
    if (!this.hasProviderCardsTarget) return

    const cardsHtml = availableProviders.map(provider => {
      const integration = connectedIntegrations.find(i => i.provider === provider.name)
      const isConnected = !!integration
      const lastSync = integration?.last_sync_at
      const fileCount = integration?.cloud_files_count || 0

      return `
        <div class="provider-card provider-card--${provider.name} ${isConnected ? 'provider-card--connected' : 'provider-card--disconnected'}" 
             data-provider="${provider.name}"
             data-integration-id="${integration?.id || ''}">
          
          <div class="provider-card__header">
            <div class="provider-card__icon">
              <i class="provider-icon provider-icon--${provider.name}"></i>
            </div>
            <div class="provider-card__info">
              <h3 class="provider-card__name">${provider.display_name}</h3>
              <div class="provider-card__status">
                ${isConnected ? 
                  `<span class="status-badge status-badge--connected">Connected</span>` :
                  `<span class="status-badge status-badge--disconnected">Not Connected</span>`
                }
              </div>
            </div>
          </div>

          <div class="provider-card__body">
            ${isConnected ? `
              <div class="provider-card__stats">
                <div class="stat">
                  <span class="stat__label">Files</span>
                  <span class="stat__value">${fileCount}</span>
                </div>
                <div class="stat">
                  <span class="stat__label">Last Sync</span>
                  <span class="stat__value">${lastSync ? this.formatDate(lastSync) : 'Never'}</span>
                </div>
              </div>
              
              <div class="provider-card__sync-status" data-target="cloud-integration-manager.syncStatus" data-integration-id="${integration.id}">
                <span class="sync-indicator"></span>
                <span class="sync-text">Ready</span>
              </div>
            ` : `
              <div class="provider-card__description">
                Connect your ${provider.display_name} account to import and export documents.
              </div>
            `}
          </div>

          <div class="provider-card__actions">
            ${isConnected ? `
              <button class="btn btn--secondary btn--sm" 
                      data-action="click->cloud-integration-manager#syncIntegration" 
                      data-integration-id="${integration.id}">
                <i class="icon icon--sync"></i> Sync
              </button>
              <button class="btn btn--secondary btn--sm" 
                      data-action="click->cloud-integration-manager#viewFiles" 
                      data-integration-id="${integration.id}">
                <i class="icon icon--files"></i> Browse Files
              </button>
              <button class="btn btn--danger btn--sm" 
                      data-action="click->cloud-integration-manager#disconnectProvider" 
                      data-integration-id="${integration.id}">
                <i class="icon icon--disconnect"></i> Disconnect
              </button>
            ` : `
              <button class="btn btn--primary" 
                      data-controller="cloud-oauth"
                      data-cloud-oauth-provider-value="${provider.name}"
                      data-cloud-oauth-auth-url-value="/cloud_integrations/new?provider=${provider.name}"
                      data-action="click->cloud-oauth#authorize">
                <i class="icon icon--connect"></i> Connect ${provider.display_name}
              </button>
            `}
          </div>
        </div>
      `
    }).join('')

    this.providerCardsTarget.innerHTML = cardsHtml
  }

  // Connect to a new provider
  async connectProvider(event) {
    const provider = event.target.dataset.provider
    
    if (!provider) {
      this.showError('Provider not specified')
      return
    }

    try {
      // This will be handled by the cloud-oauth controller
      this.dispatch('provider:connecting', { detail: { provider } })
      
    } catch (error) {
      this.showError(`Failed to connect to ${provider}: ${error.message}`)
    }
  }

  // Disconnect from a provider
  async disconnectProvider(event) {
    event.preventDefault()
    
    const integrationId = event.target.dataset.integrationId
    const providerName = this.integrations.get(integrationId)?.provider_name || 'provider'
    
    if (!confirm(`Are you sure you want to disconnect from ${providerName}? This will remove access to your files.`)) {
      return
    }

    try {
      const response = await fetch(`/cloud_integrations/${integrationId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        this.integrations.delete(integrationId)
        this.showNotification(`Disconnected from ${providerName}`, 'success')
        this.loadIntegrations() // Refresh the display
      } else {
        throw new Error('Failed to disconnect')
      }
      
    } catch (error) {
      this.showError(`Failed to disconnect: ${error.message}`)
    }
  }

  // Sync specific integration
  async syncIntegration(event) {
    event.preventDefault()
    
    const integrationId = event.target.dataset.integrationId
    const integration = this.integrations.get(integrationId)
    
    if (!integration) {
      this.showError('Integration not found')
      return
    }

    this.updateSyncStatus(integrationId, 'syncing', 'Syncing...')
    
    try {
      const response = await fetch(`/cloud_integrations/${integrationId}/cloud_files?sync=true`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        this.showNotification(`Sync started for ${integration.provider_name}`, 'success')
        this.startSyncPolling(integrationId)
      } else {
        throw new Error('Sync request failed')
      }
      
    } catch (error) {
      this.updateSyncStatus(integrationId, 'error', 'Sync failed')
      this.showError(`Sync failed: ${error.message}`)
    }
  }

  // Sync all connected integrations
  async syncAll() {
    const connectedIntegrations = Array.from(this.integrations.values()).filter(i => i.active)
    
    if (connectedIntegrations.length === 0) {
      this.showNotification('No connected integrations to sync', 'info')
      return
    }

    this.showNotification(`Starting sync for ${connectedIntegrations.length} integrations...`, 'info')
    
    // Sync all integrations
    for (const integration of connectedIntegrations) {
      this.updateSyncStatus(integration.id, 'syncing', 'Syncing...')
      
      try {
        await fetch(`/cloud_integrations/${integration.id}/cloud_files?sync=true`, {
          method: 'GET',
          headers: {
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
            'Accept': 'application/json'
          }
        })
        
        this.startSyncPolling(integration.id)
        
      } catch (error) {
        this.updateSyncStatus(integration.id, 'error', 'Sync failed')
      }
    }
  }

  // View files for an integration
  viewFiles(event) {
    event.preventDefault()
    
    const integrationId = event.target.dataset.integrationId
    const integration = this.integrations.get(integrationId)
    
    if (!integration) {
      this.showError('Integration not found')
      return
    }

    // Navigate to files page
    window.location.href = `/cloud_integrations/${integrationId}/cloud_files`
  }

  // Update sync status for specific integration
  updateSyncStatus(integrationId, status, message) {
    this.syncStatus.set(integrationId, { status, message, timestamp: Date.now() })
    
    // Update UI
    const statusElement = this.element.querySelector(`[data-integration-id="${integrationId}"] .provider-card__sync-status`)
    if (statusElement) {
      statusElement.className = `provider-card__sync-status sync-status--${status}`
      const textElement = statusElement.querySelector('.sync-text')
      if (textElement) {
        textElement.textContent = message
      }
    }

    // Update global status
    this.updateGlobalSyncStatus()
  }

  // Update global sync status display
  updateGlobalSyncStatus(integrations) {
    if (!this.hasSyncStatusGlobalTarget) return

    const allIntegrations = integrations || Array.from(this.integrations.values())
    const activeSyncs = Array.from(this.syncStatus.values()).filter(s => s.status === 'syncing')
    
    if (activeSyncs.length > 0) {
      this.syncStatusGlobalTarget.className = 'global-sync-status sync-status--syncing'
      this.syncStatusGlobalTarget.textContent = `Syncing ${activeSyncs.length} integration${activeSyncs.length > 1 ? 's' : ''}...`
    } else {
      const connectedCount = allIntegrations.filter(i => i.active).length
      this.syncStatusGlobalTarget.className = 'global-sync-status sync-status--ready'
      this.syncStatusGlobalTarget.textContent = `${connectedCount} integration${connectedCount !== 1 ? 's' : ''} connected`
    }
  }

  // Start polling for sync completion
  startSyncPolling(integrationId) {
    // Poll every 5 seconds for sync status
    const pollInterval = setInterval(async () => {
      try {
        const response = await fetch(`/cloud_integrations/${integrationId}/sync_status`, {
          headers: { 'Accept': 'application/json' }
        })
        
        if (response.ok) {
          const data = await response.json()
          
          if (!data.syncing) {
            clearInterval(pollInterval)
            this.updateSyncStatus(integrationId, 'complete', `Synced ${data.files_count} files`)
            
            // Reset status after delay
            setTimeout(() => {
              this.updateSyncStatus(integrationId, 'ready', 'Ready')
            }, 3000)
            
            // Refresh integration data
            this.refreshIntegration(integrationId)
          }
        }
      } catch (error) {
        clearInterval(pollInterval)
        this.updateSyncStatus(integrationId, 'error', 'Sync failed')
      }
    }, 5000)

    // Store interval for cleanup
    if (!this.syncPollers) this.syncPollers = new Map()
    this.syncPollers.set(integrationId, pollInterval)
  }

  // Refresh specific integration data
  async refreshIntegration(integrationId) {
    try {
      const response = await fetch(`/cloud_integrations/${integrationId}`, {
        headers: { 'Accept': 'application/json' }
      })
      
      if (response.ok) {
        const integration = await response.json()
        this.integrations.set(integrationId, integration)
      }
    } catch (error) {
      console.error('Failed to refresh integration:', error)
    }
  }

  // Periodic refresh of integration status
  startPeriodicRefresh() {
    if (this.refreshInterval > 0) {
      this.refreshTimer = setInterval(() => {
        this.loadIntegrations()
      }, this.refreshIntervalValue)
    }
  }

  stopPeriodicRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
    
    // Clear sync pollers
    if (this.syncPollers) {
      this.syncPollers.forEach(interval => clearInterval(interval))
      this.syncPollers.clear()
    }
  }

  // Event handlers
  handleOAuthSuccess(event) {
    const { provider } = event.detail
    this.showNotification(`Successfully connected to ${provider}`, 'success')
    
    // Refresh integrations after short delay
    setTimeout(() => {
      this.loadIntegrations()
    }, 1000)
  }

  handleOAuthError(event) {
    const { provider, error } = event.detail
    this.showError(`Failed to connect to ${provider}: ${error}`)
  }

  handleSyncStarted(event) {
    const { integrationId } = event.detail
    this.updateSyncStatus(integrationId, 'syncing', 'Syncing...')
  }

  handleSyncCompleted(event) {
    const { integrationId, filesCount } = event.detail
    this.updateSyncStatus(integrationId, 'complete', `Synced ${filesCount} files`)
  }

  handleSyncError(event) {
    const { integrationId, error } = event.detail
    this.updateSyncStatus(integrationId, 'error', `Error: ${error}`)
  }

  handleFileImported(event) {
    const { fileName, integrationId } = event.detail
    this.showNotification(`Imported "${fileName}"`, 'success')
  }

  handleFileExported(event) {
    const { fileName, integrationId } = event.detail
    this.showNotification(`Exported "${fileName}"`, 'success')
  }

  // UI helper methods
  showLoading(show) {
    this.element.classList.toggle(this.loadingClass, show)
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.style.display = show ? 'block' : 'none'
    }
  }

  showError(message) {
    this.element.classList.add(this.errorClass)
    
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.textContent = message
      this.errorContainerTarget.style.display = 'block'
      
      setTimeout(() => {
        this.errorContainerTarget.style.display = 'none'
        this.element.classList.remove(this.errorClass)
      }, 5000)
    }
    
    // Also dispatch as notification
    this.showNotification(message, 'error')
  }

  showNotification(message, type = 'info') {
    // Dispatch notification event for global notification system
    this.dispatch('notification', {
      detail: { message, type }
    })
  }

  // Utility methods
  formatDate(dateString) {
    if (!dateString) return 'Never'
    
    const date = new Date(dateString)
    const now = new Date()
    const diffMs = now - date
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)
    
    if (diffMins < 1) return 'Just now'
    if (diffMins < 60) return `${diffMins}m ago`
    if (diffHours < 24) return `${diffHours}h ago`
    if (diffDays < 7) return `${diffDays}d ago`
    
    return date.toLocaleDateString()
  }

  // Action Cable integration
  setupActionCable() {
    if (this.userIdValue && window.cloudSyncChannel) {
      // Connect to the sync channel
      window.cloudSyncChannel.connect(this.userIdValue)
      
      // Listen for sync events
      window.cloudSyncChannel.on('sync_started', this.handleCableSyncStarted.bind(this))
      window.cloudSyncChannel.on('sync_completed', this.handleCableSyncCompleted.bind(this))
      window.cloudSyncChannel.on('sync_error', this.handleCableSyncError.bind(this))
      window.cloudSyncChannel.on('sync_progress', this.handleCableSyncProgress.bind(this))
      window.cloudSyncChannel.on('status_update', this.handleCableStatusUpdate.bind(this))
      window.cloudSyncChannel.on('error', this.handleCableError.bind(this))
    }
  }

  disconnectActionCable() {
    if (window.cloudSyncChannel) {
      window.cloudSyncChannel.disconnect()
    }
  }

  // Action Cable event handlers
  handleCableSyncStarted(data) {
    const { integration_id, provider } = data
    this.updateSyncStatus(integration_id, 'syncing', 'Syncing...')
    this.showNotification(`Sync started for ${provider}`, 'info')
  }

  handleCableSyncCompleted(data) {
    const { integration_id, provider, files_count } = data
    this.updateSyncStatus(integration_id, 'complete', `Synced ${files_count} files`)
    this.showNotification(`Sync completed for ${provider}: ${files_count} files`, 'success')
    
    // Reset status after delay
    setTimeout(() => {
      this.updateSyncStatus(integration_id, 'ready', 'Ready')
    }, 3000)
    
    // Refresh integration data
    this.refreshIntegration(integration_id)
  }

  handleCableSyncError(data) {
    const { integration_id, provider, error } = data
    this.updateSyncStatus(integration_id, 'error', `Error: ${error}`)
    this.showNotification(`Sync failed for ${provider}: ${error}`, 'error')
  }

  handleCableSyncProgress(data) {
    const { integration_id, progress, message } = data
    this.updateSyncStatus(integration_id, 'syncing', message || `${progress}% complete`)
  }

  handleCableStatusUpdate(data) {
    const { integrations } = data
    if (integrations) {
      integrations.forEach(status => {
        const { integration_id, syncing, files_count, error } = status
        
        if (error) {
          this.updateSyncStatus(integration_id, 'error', error)
        } else if (syncing) {
          this.updateSyncStatus(integration_id, 'syncing', 'Syncing...')
        } else {
          this.updateSyncStatus(integration_id, 'ready', 'Ready')
        }
      })
    }
  }

  handleCableError(data) {
    const { error, integration_id } = data
    this.showError(`Real-time sync error: ${error}`)
    
    if (integration_id) {
      this.updateSyncStatus(integration_id, 'error', error)
    }
  }

  // Enhanced sync method to use Action Cable
  async syncIntegration(event) {
    event.preventDefault()
    
    const integrationId = event.target.dataset.integrationId
    const integration = this.integrations.get(integrationId)
    
    if (!integration) {
      this.showError('Integration not found')
      return
    }

    // Use Action Cable if available, fallback to direct API
    if (window.cloudSyncChannel && window.cloudSyncChannel.isConnected()) {
      window.cloudSyncChannel.triggerSync(integrationId)
    } else {
      // Fallback to original implementation
      await this.syncIntegrationDirect(integrationId, integration)
    }
  }

  // Original sync method as fallback
  async syncIntegrationDirect(integrationId, integration) {
    this.updateSyncStatus(integrationId, 'syncing', 'Syncing...')
    
    try {
      const response = await fetch(`/cloud_integrations/${integrationId}/cloud_files?sync=true`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        this.showNotification(`Sync started for ${integration.provider_name}`, 'success')
        this.startSyncPolling(integrationId)
      } else {
        throw new Error('Sync request failed')
      }
      
    } catch (error) {
      this.updateSyncStatus(integrationId, 'error', 'Sync failed')
      this.showError(`Sync failed: ${error.message}`)
    }
  }

  // Public API methods
  refresh() {
    this.loadIntegrations()
  }

  getIntegration(id) {
    return this.integrations.get(id)
  }

  getSyncStatus(id) {
    return this.syncStatus.get(id)
  }
}