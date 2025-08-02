/**
 * PermissionManager - Manages plugin permissions and user consent
 * Provides UI for managing plugin permissions with granular controls
 */
export class PermissionManager {
  constructor(options = {}) {
    this.options = {
      baseUrl: "/extensions",
      autoSave: true,
      strictMode: true,
      showPermissionReasons: true,
      ...options
    }
    
    this.permissions = new Map()
    this.userPreferences = new Map()
    this.permissionDefinitions = new Map()
    this.eventEmitter = new EventTarget()
    this.isInitialized = false
    
    this.init()
  }

  async init() {
    try {
      // Load permission definitions
      await this.loadPermissionDefinitions()
      
      // Load user preferences
      await this.loadUserPreferences()
      
      // Setup UI components
      this.createPermissionUI()
      
      this.isInitialized = true
      this.emit("permission-manager:initialized")
    } catch (error) {
      console.error("Failed to initialize PermissionManager:", error)
      this.emit("permission-manager:error", { error })
    }
  }

  loadPermissionDefinitions() {
    // Define available permissions and their properties
    const definitions = [
      {
        id: "read_files",
        name: "Read Files",
        description: "Allow plugin to read file contents",
        category: "file_system",
        riskLevel: "medium",
        reason: "Plugin needs to analyze or process file contents",
        examples: ["Reading configuration files", "Processing text documents"]
      },
      {
        id: "write_files",
        name: "Write Files",
        description: "Allow plugin to create or modify files",
        category: "file_system",
        riskLevel: "high",
        reason: "Plugin needs to save output or modify existing files",
        examples: ["Saving processed data", "Creating backup files"]
      },
      {
        id: "delete_files",
        name: "Delete Files",
        description: "Allow plugin to delete files",
        category: "file_system",
        riskLevel: "high",
        reason: "Plugin needs to clean up temporary files or manage storage",
        examples: ["Removing temporary files", "Cleaning up caches"]
      },
      {
        id: "network_access",
        name: "Network Access",
        description: "Allow plugin to make network requests",
        category: "network",
        riskLevel: "high",
        reason: "Plugin needs to communicate with external services",
        examples: ["Fetching remote data", "API integrations"]
      },
      {
        id: "api_access",
        name: "API Access",
        description: "Allow plugin to access application APIs",
        category: "application",
        riskLevel: "medium",
        reason: "Plugin needs to interact with application features",
        examples: ["Creating documents", "Managing user settings"]
      },
      {
        id: "clipboard_access",
        name: "Clipboard Access",
        description: "Allow plugin to read from and write to clipboard",
        category: "system",
        riskLevel: "low",
        reason: "Plugin needs to copy data to clipboard or read copied content",
        examples: ["Copying generated code", "Processing clipboard content"]
      },
      {
        id: "system_notifications",
        name: "System Notifications",
        description: "Allow plugin to show system notifications",
        category: "system",
        riskLevel: "low",
        reason: "Plugin needs to notify user of important events",
        examples: ["Task completion alerts", "Error notifications"]
      },
      {
        id: "user_data_access",
        name: "User Data Access",
        description: "Allow plugin to access user profile and preferences",
        category: "privacy",
        riskLevel: "high",
        reason: "Plugin needs user information for personalization",
        examples: ["Customizing interface", "User-specific features"]
      },
      {
        id: "editor_integration",
        name: "Editor Integration",
        description: "Allow plugin to modify editor content and behavior",
        category: "application",
        riskLevel: "medium",
        reason: "Plugin provides editor enhancements or automation",
        examples: ["Code formatting", "Syntax highlighting"]
      },
      {
        id: "command_execution",
        name: "Command Execution",
        description: "Allow plugin to execute system commands",
        category: "system",
        riskLevel: "critical",
        reason: "Plugin needs to run external tools or scripts",
        examples: ["Running build tools", "Git operations"]
      }
    ]
    
    definitions.forEach(def => {
      this.permissionDefinitions.set(def.id, def)
    })
  }

  async loadUserPreferences() {
    try {
      const stored = localStorage.getItem("plugin-permission-preferences")
      if (stored) {
        const preferences = JSON.parse(stored)
        Object.entries(preferences).forEach(([key, value]) => {
          this.userPreferences.set(key, value)
        })
      }
    } catch (error) {
      console.warn("Failed to load user preferences:", error)
    }
  }

  async saveUserPreferences() {
    try {
      const preferences = Object.fromEntries(this.userPreferences)
      localStorage.setItem("plugin-permission-preferences", JSON.stringify(preferences))
    } catch (error) {
      console.error("Failed to save user preferences:", error)
    }
  }

  createPermissionUI() {
    // Create permission management modal
    this.permissionModal = document.createElement("div")
    this.permissionModal.className = "permission-modal"
    this.permissionModal.style.display = "none"
    this.permissionModal.innerHTML = `
      <div class="modal-backdrop"></div>
      <div class="modal-content permission-modal-content">
        <div class="modal-header">
          <h3>Plugin Permissions</h3>
          <button type="button" class="btn-close" data-action="close">&times;</button>
        </div>
        
        <div class="modal-body">
          <div class="permission-tabs">
            <button type="button" class="tab-btn active" data-tab="request">Permission Request</button>
            <button type="button" class="tab-btn" data-tab="manage">Manage Permissions</button>
            <button type="button" class="tab-btn" data-tab="audit">Audit Log</button>
          </div>
          
          <div class="permission-tab-content" data-tab="request">
            <div class="permission-request-section">
              <div class="plugin-info">
                <div class="plugin-name"></div>
                <div class="plugin-description"></div>
              </div>
              
              <div class="permission-explanation">
                <h4>This plugin is requesting the following permissions:</h4>
                <div class="permission-list">
                  <!-- Permission items will be inserted here -->
                </div>
              </div>
              
              <div class="risk-assessment">
                <div class="risk-indicator">
                  <span class="risk-level"></span>
                  <span class="risk-text"></span>
                </div>
                <div class="risk-details"></div>
              </div>
            </div>
          </div>
          
          <div class="permission-tab-content" data-tab="manage" style="display: none;">
            <div class="permission-management-section">
              <div class="search-section">
                <input type="text" class="permission-search" placeholder="Search plugins...">
              </div>
              
              <div class="installed-plugins-list">
                <!-- Installed plugins will be listed here -->
              </div>
            </div>
          </div>
          
          <div class="permission-tab-content" data-tab="audit" style="display: none;">
            <div class="permission-audit-section">
              <div class="audit-filters">
                <select class="audit-filter-type">
                  <option value="">All Events</option>
                  <option value="granted">Permissions Granted</option>
                  <option value="denied">Permissions Denied</option>
                  <option value="revoked">Permissions Revoked</option>
                </select>
                <input type="date" class="audit-filter-date">
              </div>
              
              <div class="audit-log">
                <!-- Audit entries will be listed here -->
              </div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer permission-modal-footer">
          <div class="permission-actions">
            <!-- Action buttons will be inserted based on current tab -->
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(this.permissionModal)
    this.bindPermissionModalEvents()
  }

  bindPermissionModalEvents() {
    // Tab switching
    this.permissionModal.querySelectorAll(".tab-btn").forEach(btn => {
      btn.addEventListener("click", (e) => this.switchTab(e.target.dataset.tab))
    })
    
    // Close modal
    this.permissionModal.querySelector("[data-action=\"close\"]").addEventListener("click", () => {
      this.closePermissionModal()
    })
    
    this.permissionModal.querySelector(".modal-backdrop").addEventListener("click", () => {
      this.closePermissionModal()
    })
    
    // Search functionality
    const searchInput = this.permissionModal.querySelector(".permission-search")
    searchInput.addEventListener("input", (e) => this.filterPlugins(e.target.value))
    
    // Audit filters
    const auditTypeFilter = this.permissionModal.querySelector(".audit-filter-type")
    const auditDateFilter = this.permissionModal.querySelector(".audit-filter-date")
    
    auditTypeFilter.addEventListener("change", () => this.updateAuditLog())
    auditDateFilter.addEventListener("change", () => this.updateAuditLog())
  }

  // Public API
  async requestPermission(pluginId, permissions) {
    if (!Array.isArray(permissions)) {
      permissions = [permissions]
    }
    
    // Check if permissions are already granted
    const existingPermissions = await this.getPluginPermissions(pluginId)
    const newPermissions = permissions.filter(p => !existingPermissions.includes(p))
    
    if (newPermissions.length === 0) {
      return { granted: true, permissions: permissions }
    }
    
    // Show permission request UI
    return await this.showPermissionRequest(pluginId, newPermissions)
  }

  async showPermissionRequest(pluginId, permissions) {
    return new Promise((resolve) => {
      this.currentRequest = {
        pluginId: pluginId,
        permissions: permissions,
        resolve: resolve
      }
      
      this.populatePermissionRequest(pluginId, permissions)
      this.openPermissionModal("request")
    })
  }

  async populatePermissionRequest(pluginId, permissions) {
    try {
      // Get plugin info
      const pluginInfo = await this.getPluginInfo(pluginId)
      
      // Update plugin info section
      const nameEl = this.permissionModal.querySelector(".plugin-name")
      const descEl = this.permissionModal.querySelector(".plugin-description")
      
      nameEl.textContent = pluginInfo.name || `Plugin ${pluginId}`
      descEl.textContent = pluginInfo.description || "No description available"
      
      // Populate permission list
      const permissionList = this.permissionModal.querySelector(".permission-list")
      permissionList.innerHTML = ""
      
      permissions.forEach(permissionId => {
        const definition = this.permissionDefinitions.get(permissionId)
        if (!definition) return
        
        const item = this.createPermissionItem(definition, true)
        permissionList.appendChild(item)
      })
      
      // Update risk assessment
      this.updateRiskAssessment(permissions)
      
      // Update action buttons
      this.updateRequestActions(pluginId, permissions)
      
    } catch (error) {
      console.error("Failed to populate permission request:", error)
    }
  }

  createPermissionItem(definition, isRequest = false) {
    const item = document.createElement("div")
    item.className = `permission-item risk-${definition.riskLevel}`
    item.dataset.permission = definition.id
    
    item.innerHTML = `
      <div class="permission-header">
        <div class="permission-icon ${definition.category}"></div>
        <div class="permission-info">
          <div class="permission-name">${definition.name}</div>
          <div class="permission-description">${definition.description}</div>
        </div>
        <div class="permission-risk">
          <span class="risk-badge risk-${definition.riskLevel}">${definition.riskLevel}</span>
        </div>
      </div>
      
      ${this.options.showPermissionReasons ? `
      <div class="permission-details">
        <div class="permission-reason">
          <strong>Why this permission is needed:</strong>
          <p>${definition.reason}</p>
        </div>
        <div class="permission-examples">
          <strong>Examples:</strong>
          <ul>
            ${definition.examples.map(ex => `<li>${ex}</li>`).join("")}
          </ul>
        </div>
      </div>
      ` : ""}
      
      ${!isRequest ? `
      <div class="permission-controls">
        <label class="permission-toggle">
          <input type="checkbox" class="permission-checkbox" ${this.isPermissionGranted(definition.id) ? "checked" : ""}>
          <span class="toggle-slider"></span>
          <span class="toggle-label">${this.isPermissionGranted(definition.id) ? "Granted" : "Denied"}</span>
        </label>
        <button type="button" class="btn btn-sm btn-danger revoke-btn" data-permission="${definition.id}">Revoke</button>
      </div>
      ` : ""}
    `
    
    return item
  }

  updateRiskAssessment(permissions) {
    const riskLevels = ["low", "medium", "high", "critical"]
    let maxRisk = 0
    
    permissions.forEach(permissionId => {
      const definition = this.permissionDefinitions.get(permissionId)
      if (definition) {
        const riskIndex = riskLevels.indexOf(definition.riskLevel)
        maxRisk = Math.max(maxRisk, riskIndex)
      }
    })
    
    const overallRisk = riskLevels[maxRisk]
    const riskColors = {
      low: "#28a745",
      medium: "#ffc107", 
      high: "#fd7e14",
      critical: "#dc3545"
    }
    
    const riskIndicator = this.permissionModal.querySelector(".risk-level")
    const riskText = this.permissionModal.querySelector(".risk-text")
    const riskDetails = this.permissionModal.querySelector(".risk-details")
    
    riskIndicator.textContent = overallRisk.toUpperCase()
    riskIndicator.style.backgroundColor = riskColors[overallRisk]
    
    riskText.textContent = this.getRiskDescription(overallRisk)
    riskDetails.innerHTML = this.getRiskRecommendations(overallRisk, permissions)
  }

  getRiskDescription(riskLevel) {
    const descriptions = {
      low: "Low risk - These permissions have minimal security impact",
      medium: "Medium risk - These permissions may access sensitive data",
      high: "High risk - These permissions can significantly affect your system",
      critical: "Critical risk - These permissions have extensive system access"
    }
    return descriptions[riskLevel] || "Unknown risk level"
  }

  getRiskRecommendations(riskLevel, permissions) {
    const recommendations = {
      low: "<p>These permissions are generally safe to grant.</p>",
      medium: "<p>Review the specific permissions and ensure you trust this plugin.</p>",
      high: "<p><strong>Caution:</strong> Only grant these permissions if you fully trust this plugin and understand the risks.</p>",
      critical: "<p><strong>Warning:</strong> These permissions provide extensive system access. Only grant to plugins from trusted sources.</p>"
    }
    
    return recommendations[riskLevel] || ""
  }

  updateRequestActions(pluginId, permissions) {
    const actions = this.permissionModal.querySelector(".permission-actions")
    actions.innerHTML = `
      <button type="button" class="btn btn-secondary" data-action="deny">Deny All</button>
      <button type="button" class="btn btn-warning" data-action="deny-and-remember">Deny & Remember</button>
      <button type="button" class="btn btn-primary" data-action="grant">Grant Permissions</button>
    `
    
    // Bind action events
    actions.addEventListener("click", (e) => {
      const action = e.target.dataset.action
      if (action) {
        this.handlePermissionAction(action, pluginId, permissions)
      }
    })
  }

  async handlePermissionAction(action, pluginId, permissions) {
    let result = { granted: false, permissions: [] }
    
    switch (action) {
    case "grant":
      result = await this.grantPermissions(pluginId, permissions)
      break
    case "deny":
      result = { granted: false, permissions: [] }
      break
    case "deny-and-remember":
      await this.rememberDenial(pluginId, permissions)
      result = { granted: false, permissions: [] }
      break
    }
    
    // Log the decision
    this.logPermissionDecision(pluginId, permissions, action)
    
    // Resolve the request
    if (this.currentRequest && this.currentRequest.resolve) {
      this.currentRequest.resolve(result)
      this.currentRequest = null
    }
    
    this.closePermissionModal()
  }

  async grantPermissions(pluginId, permissions) {
    try {
      // Update backend
      const response = await fetch(`${this.options.baseUrl}/${pluginId}/permissions`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({ permissions: permissions })
      })
      
      if (!response.ok) {
        throw new Error("Failed to update permissions")
      }
      
      // Update local permissions
      const existingPermissions = this.permissions.get(pluginId) || []
      const updatedPermissions = [...new Set([...existingPermissions, ...permissions])]
      this.permissions.set(pluginId, updatedPermissions)
      
      this.emit("permissions:granted", { pluginId, permissions })
      
      return { granted: true, permissions: permissions }
      
    } catch (error) {
      console.error("Failed to grant permissions:", error)
      throw error
    }
  }

  async revokePermissions(pluginId, permissions) {
    try {
      const response = await fetch(`${this.options.baseUrl}/${pluginId}/permissions`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
        },
        body: JSON.stringify({ permissions: permissions })
      })
      
      if (!response.ok) {
        throw new Error("Failed to revoke permissions")
      }
      
      // Update local permissions
      const existingPermissions = this.permissions.get(pluginId) || []
      const updatedPermissions = existingPermissions.filter(p => !permissions.includes(p))
      this.permissions.set(pluginId, updatedPermissions)
      
      this.emit("permissions:revoked", { pluginId, permissions })
      
    } catch (error) {
      console.error("Failed to revoke permissions:", error)
      throw error
    }
  }

  async getPluginPermissions(pluginId) {
    // Try to get from local cache first
    if (this.permissions.has(pluginId)) {
      return this.permissions.get(pluginId)
    }
    
    // Fetch from backend
    try {
      const response = await fetch(`${this.options.baseUrl}/${pluginId}/permissions`)
      if (response.ok) {
        const data = await response.json()
        const permissions = data.permissions || []
        this.permissions.set(pluginId, permissions)
        return permissions
      }
    } catch (error) {
      console.warn("Failed to fetch plugin permissions:", error)
    }
    
    return []
  }

  async getPluginInfo(pluginId) {
    try {
      const response = await fetch(`${this.options.baseUrl}/${pluginId}`)
      if (response.ok) {
        return await response.json()
      }
    } catch (error) {
      console.warn("Failed to fetch plugin info:", error)
    }
    
    return { name: `Plugin ${pluginId}`, description: "No description available" }
  }

  isPermissionGranted(pluginId, permission) {
    const permissions = this.permissions.get(pluginId) || []
    return permissions.includes(permission)
  }

  logPermissionDecision(pluginId, permissions, action) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      pluginId: pluginId,
      permissions: permissions,
      action: action,
      userAgent: navigator.userAgent
    }
    
    // Store in local audit log
    const auditLog = JSON.parse(localStorage.getItem("plugin-permission-audit") || "[]")
    auditLog.push(logEntry)
    
    // Keep only last 100 entries
    if (auditLog.length > 100) {
      auditLog.shift()
    }
    
    localStorage.setItem("plugin-permission-audit", JSON.stringify(auditLog))
    
    this.emit("permissions:logged", logEntry)
  }

  // Modal Management
  openPermissionModal(tab = "request") {
    this.permissionModal.style.display = "flex"
    this.switchTab(tab)
    
    // Focus management
    const firstInput = this.permissionModal.querySelector("input, button")
    if (firstInput) firstInput.focus()
  }

  closePermissionModal() {
    this.permissionModal.style.display = "none"
    
    // Reject pending request if modal is closed without action
    if (this.currentRequest && this.currentRequest.resolve) {
      this.currentRequest.resolve({ granted: false, permissions: [] })
      this.currentRequest = null
    }
  }

  switchTab(tabName) {
    // Update tab buttons
    this.permissionModal.querySelectorAll(".tab-btn").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.tab === tabName)
    })
    
    // Update tab content
    this.permissionModal.querySelectorAll(".permission-tab-content").forEach(content => {
      content.style.display = content.dataset.tab === tabName ? "block" : "none"
    })
    
    // Load tab-specific content
    switch (tabName) {
    case "manage":
      this.loadManageTab()
      break
    case "audit":
      this.loadAuditTab()
      break
    }
  }

  async loadManageTab() {
    // Implementation for manage tab
  }

  async loadAuditTab() {
    // Implementation for audit tab
  }

  // Utility Methods
  async rememberDenial(pluginId, permissions) {
    const key = `denied-${pluginId}`
    const deniedPermissions = this.userPreferences.get(key) || []
    const updatedDenied = [...new Set([...deniedPermissions, ...permissions])]
    
    this.userPreferences.set(key, updatedDenied)
    await this.saveUserPreferences()
  }

  // Event System
  emit(eventName, detail = {}) {
    const event = new CustomEvent(eventName, { detail })
    this.eventEmitter.dispatchEvent(event)
  }

  on(eventName, callback) {
    this.eventEmitter.addEventListener(eventName, callback)
  }

  off(eventName, callback) {
    this.eventEmitter.removeEventListener(eventName, callback)
  }
}

// Export for module usage
export default PermissionManager

// Create global instance
window.PermissionManager = new PermissionManager()