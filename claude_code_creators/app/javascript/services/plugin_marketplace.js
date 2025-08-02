/**
 * PluginMarketplace - Frontend service for discovering, installing, and managing plugins
 * Integrates with Rails ExtensionsController and WidgetFramework
 */
export class PluginMarketplace {
  constructor(options = {}) {
    this.options = {
      baseUrl: "/extensions",
      autoRefresh: true,
      cacheTimeout: 5 * 60 * 1000, // 5 minutes
      maxRetries: 3,
      ...options
    }
    
    this.plugins = new Map()
    this.installedPlugins = new Map()
    this.categories = new Set()
    this.widgetFramework = null
    this.eventEmitter = new EventTarget()
    this.cache = new Map()
    this.isOpen = false
    this.currentView = "marketplace"
    
    this.init()
  }

  async init() {
    try {
      // Create marketplace UI
      this.createMarketplaceUI()
      
      // Load initial data
      await this.refreshData()
      
      // Setup auto-refresh if enabled
      if (this.options.autoRefresh) {
        this.setupAutoRefresh()
      }
      
      this.emit("marketplace:initialized")
    } catch (error) {
      console.error("Failed to initialize PluginMarketplace:", error)
      this.emit("marketplace:error", { error })
    }
  }

  createMarketplaceUI() {
    // Create main marketplace container
    this.container = document.createElement("div")
    this.container.className = "plugin-marketplace"
    this.container.style.display = "none"
    this.container.innerHTML = `
      <div class="marketplace-backdrop"></div>
      <div class="marketplace-content">
        <div class="marketplace-header">
          <h2>Plugin Marketplace</h2>
          <button type="button" class="btn-close" data-action="close">&times;</button>
        </div>
        
        <nav class="marketplace-nav">
          <button type="button" class="nav-btn active" data-view="marketplace">
            <span class="icon">🏪</span> Browse
          </button>
          <button type="button" class="nav-btn" data-view="installed">
            <span class="icon">📦</span> Installed
          </button>
          <button type="button" class="nav-btn" data-view="widgets">
            <span class="icon">⊞</span> My Widgets
          </button>
        </nav>
        
        <div class="marketplace-toolbar">
          <div class="search-section">
            <input type="text" class="search-input" placeholder="Search plugins..." />
            <button type="button" class="search-btn">🔍</button>
          </div>
          <div class="filter-section">
            <select class="category-filter">
              <option value="">All Categories</option>
            </select>
            <select class="sort-filter">
              <option value="name">Sort by Name</option>
              <option value="author">Sort by Author</option>
              <option value="category">Sort by Category</option>
              <option value="created_at">Sort by Date</option>
            </select>
          </div>
          <button type="button" class="btn btn-primary" data-action="refresh">
            <span class="icon">🔄</span> Refresh
          </button>
        </div>
        
        <div class="marketplace-body">
          <div class="marketplace-view" data-view="marketplace">
            <div class="featured-section">
              <h3>Featured Plugins</h3>
              <div class="plugin-grid featured-grid"></div>
            </div>
            <div class="plugins-section">
              <h3>All Plugins</h3>
              <div class="plugin-grid main-grid"></div>
            </div>
          </div>
          
          <div class="marketplace-view" data-view="installed" style="display: none;">
            <div class="installed-section">
              <h3>Installed Plugins</h3>
              <div class="plugin-list installed-list"></div>
            </div>
          </div>
          
          <div class="marketplace-view" data-view="widgets" style="display: none;">
            <div class="widgets-section">
              <h3>Active Widgets</h3>
              <div class="widget-list active-widgets"></div>
            </div>
          </div>
        </div>
        
        <div class="marketplace-status">
          <div class="status-text"></div>
          <div class="loading-indicator" style="display: none;">Loading...</div>
        </div>
      </div>
    `
    
    document.body.appendChild(this.container)
    this.bindMarketplaceEvents()
  }

  bindMarketplaceEvents() {
    // Navigation
    this.container.querySelectorAll(".nav-btn").forEach(btn => {
      btn.addEventListener("click", (e) => this.switchView(e.target.dataset.view))
    })
    
    // Close
    this.container.querySelector("[data-action=\"close\"]").addEventListener("click", () => this.close())
    this.container.querySelector(".marketplace-backdrop").addEventListener("click", () => this.close())
    
    // Toolbar actions
    this.container.querySelector("[data-action=\"refresh\"]").addEventListener("click", () => this.refreshData())
    
    // Search and filters
    const searchInput = this.container.querySelector(".search-input")
    const categoryFilter = this.container.querySelector(".category-filter")
    const sortFilter = this.container.querySelector(".sort-filter")
    
    searchInput.addEventListener("input", () => this.debounceSearch())
    categoryFilter.addEventListener("change", () => this.applyFilters())
    sortFilter.addEventListener("change", () => this.applyFilters())
    
    // Escape key to close
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.isOpen) {
        this.close()
      }
    })
  }

  // Public API
  async open() {
    this.isOpen = true
    this.container.style.display = "flex"
    
    // Focus search input
    const searchInput = this.container.querySelector(".search-input")
    setTimeout(() => searchInput.focus(), 100)
    
    // Refresh data if stale
    await this.refreshDataIfStale()
    
    this.emit("marketplace:opened")
  }

  close() {
    this.isOpen = false
    this.container.style.display = "none"
    this.emit("marketplace:closed")
  }

  async refreshData() {
    this.showLoading("Loading marketplace data...")
    
    try {
      // Load marketplace data
      await Promise.all([
        this.loadMarketplaceData(),
        this.loadInstalledPlugins()
      ])
      
      this.updateUI()
      this.showStatus("Marketplace data updated", "success")
    } catch (error) {
      console.error("Failed to refresh marketplace data:", error)
      this.showStatus("Failed to load marketplace data", "error")
      this.emit("marketplace:error", { error })
    } finally {
      this.hideLoading()
    }
  }

  async loadMarketplaceData() {
    const cacheKey = "marketplace_data"
    const cached = this.getFromCache(cacheKey)
    
    if (cached) {
      this.processMarketplaceData(cached)
      return
    }
    
    const response = await this.apiCall("/marketplace")
    this.setCache(cacheKey, response)
    this.processMarketplaceData(response)
  }

  async loadInstalledPlugins() {
    const cacheKey = "installed_plugins"
    const cached = this.getFromCache(cacheKey)
    
    if (cached) {
      this.processInstalledPlugins(cached)
      return
    }
    
    const response = await this.apiCall("/installed")
    this.setCache(cacheKey, response)
    this.processInstalledPlugins(response)
  }

  processMarketplaceData(data) {
    // Update plugins map
    this.plugins.clear()
    this.categories.clear()
    
    // Process featured plugins
    if (data.featured) {
      data.featured.forEach(plugin => {
        this.plugins.set(plugin.id, { ...plugin, featured: true })
        this.categories.add(plugin.category)
      })
    }
    
    // Process recent plugins
    if (data.recent) {
      data.recent.forEach(plugin => {
        if (!this.plugins.has(plugin.id)) {
          this.plugins.set(plugin.id, { ...plugin, featured: false })
        }
        this.categories.add(plugin.category)
      })
    }
    
    // Update categories in filter
    this.updateCategoryFilter()
  }

  processInstalledPlugins(data) {
    this.installedPlugins.clear()
    
    if (data.plugins) {
      data.plugins.forEach(installation => {
        this.installedPlugins.set(installation.id, installation)
      })
    }
  }

  updateCategoryFilter() {
    const filter = this.container.querySelector(".category-filter")
    const currentValue = filter.value
    
    // Clear existing options (except "All Categories")
    while (filter.children.length > 1) {
      filter.removeChild(filter.lastChild)
    }
    
    // Add category options
    Array.from(this.categories).sort().forEach(category => {
      const option = document.createElement("option")
      option.value = category
      option.textContent = category
      filter.appendChild(option)
    })
    
    // Restore previous selection
    filter.value = currentValue
  }

  updateUI() {
    switch (this.currentView) {
    case "marketplace":
      this.renderMarketplaceView()
      break
    case "installed":
      this.renderInstalledView()
      break
    case "widgets":
      this.renderWidgetsView()
      break
    }
  }

  renderMarketplaceView() {
    const featuredGrid = this.container.querySelector(".featured-grid")
    const mainGrid = this.container.querySelector(".main-grid")
    
    // Clear existing content
    featuredGrid.innerHTML = ""
    mainGrid.innerHTML = ""
    
    // Get filtered plugins
    const { featured, regular } = this.getFilteredPlugins()
    
    // Render featured plugins
    featured.forEach(plugin => {
      featuredGrid.appendChild(this.createPluginCard(plugin, true))
    })
    
    // Render regular plugins
    regular.forEach(plugin => {
      mainGrid.appendChild(this.createPluginCard(plugin, false))
    })
    
    // Show empty state if no plugins
    if (featured.length === 0 && regular.length === 0) {
      mainGrid.innerHTML = "<div class=\"empty-state\">No plugins found matching your criteria.</div>"
    }
  }

  renderInstalledView() {
    const installedList = this.container.querySelector(".installed-list")
    installedList.innerHTML = ""
    
    const installed = Array.from(this.installedPlugins.values())
    
    if (installed.length === 0) {
      installedList.innerHTML = "<div class=\"empty-state\">No plugins installed yet.</div>"
      return
    }
    
    installed.forEach(installation => {
      installedList.appendChild(this.createInstalledPluginCard(installation))
    })
  }

  renderWidgetsView() {
    const activeWidgets = this.container.querySelector(".active-widgets")
    activeWidgets.innerHTML = ""
    
    if (!this.widgetFramework) {
      activeWidgets.innerHTML = "<div class=\"empty-state\">Widget framework not connected.</div>"
      return
    }
    
    const widgets = Array.from(this.widgetFramework.widgets.values())
    
    if (widgets.length === 0) {
      activeWidgets.innerHTML = "<div class=\"empty-state\">No active widgets.</div>"
      return
    }
    
    widgets.forEach(widget => {
      activeWidgets.appendChild(this.createWidgetCard(widget))
    })
  }

  createPluginCard(plugin, isFeatured = false) {
    const card = document.createElement("div")
    card.className = `plugin-card ${isFeatured ? "featured" : ""}`
    card.dataset.pluginId = plugin.id
    
    const isInstalled = this.installedPlugins.has(plugin.id)
    const installStatus = isInstalled ? this.installedPlugins.get(plugin.id).status : "not_installed"
    
    card.innerHTML = `
      <div class="plugin-header">
        <div class="plugin-icon">
          ${plugin.icon_url ? `<img src="${plugin.icon_url}" alt="${plugin.name}">` : "🔌"}
        </div>
        <div class="plugin-info">
          <h4 class="plugin-name">${this.escapeHtml(plugin.name)}</h4>
          <div class="plugin-meta">
            <span class="plugin-author">by ${this.escapeHtml(plugin.author)}</span>
            <span class="plugin-version">v${this.escapeHtml(plugin.version)}</span>
          </div>
        </div>
      </div>
      
      <div class="plugin-body">
        <p class="plugin-description">${this.escapeHtml(plugin.description)}</p>
        <div class="plugin-tags">
          <span class="tag category">${this.escapeHtml(plugin.category)}</span>
          ${plugin.keywords ? plugin.keywords.split(",").map(k => 
    `<span class="tag">${this.escapeHtml(k.trim())}</span>`
  ).join("") : ""}
        </div>
      </div>
      
      <div class="plugin-footer">
        <div class="plugin-status status-${installStatus}">
          ${this.getStatusText(installStatus)}
        </div>
        <div class="plugin-actions">
          ${this.getPluginActions(plugin, installStatus)}
        </div>
      </div>
    `
    
    // Bind plugin actions
    this.bindPluginCardEvents(card, plugin)
    
    return card
  }

  createInstalledPluginCard(installation) {
    const card = document.createElement("div")
    card.className = "installed-plugin-card"
    card.dataset.pluginId = installation.id
    
    card.innerHTML = `
      <div class="plugin-header">
        <div class="plugin-info">
          <h4 class="plugin-name">${this.escapeHtml(installation.name)}</h4>
          <div class="plugin-meta">
            <span class="plugin-version">v${this.escapeHtml(installation.version)}</span>
            <span class="install-date">Installed ${this.formatDate(installation.installed_at)}</span>
          </div>
        </div>
        <div class="plugin-status status-${installation.status}">
          ${this.getStatusText(installation.status)}
        </div>
      </div>
      
      <div class="plugin-body">
        <div class="plugin-stats">
          <div class="stat">
            <label>Last Used:</label>
            <span>${installation.last_used_at ? this.formatDate(installation.last_used_at) : "Never"}</span>
          </div>
          <div class="stat">
            <label>Configuration:</label>
            <span>${Object.keys(installation.configuration || {}).length} settings</span>
          </div>
        </div>
      </div>
      
      <div class="plugin-footer">
        <div class="plugin-actions">
          ${this.getInstalledPluginActions(installation)}
        </div>
      </div>
    `
    
    // Bind installed plugin actions
    this.bindInstalledPluginCardEvents(card, installation)
    
    return card
  }

  createWidgetCard(widget) {
    const card = document.createElement("div")
    card.className = "widget-card"
    card.dataset.widgetId = widget.id
    
    card.innerHTML = `
      <div class="widget-header">
        <div class="widget-info">
          <h4 class="widget-title">${this.escapeHtml(widget.title)}</h4>
          <div class="widget-meta">
            <span class="widget-type">${this.escapeHtml(widget.type)}</span>
            <span class="widget-size">${widget.size.width}×${widget.size.height}</span>
          </div>
        </div>
        <div class="widget-status ${widget.minimized ? "minimized" : "active"}">
          ${widget.minimized ? "Minimized" : "Active"}
        </div>
      </div>
      
      <div class="widget-body">
        <div class="widget-stats">
          <div class="stat">
            <label>Created:</label>
            <span>${this.formatDate(widget.created)}</span>
          </div>
          <div class="stat">
            <label>Last Used:</label>
            <span>${this.formatDate(widget.lastUsed)}</span>
          </div>
          ${widget.pluginId ? `
          <div class="stat">
            <label>Plugin:</label>
            <span>${widget.pluginId}</span>
          </div>
          ` : ""}
        </div>
      </div>
      
      <div class="widget-footer">
        <div class="widget-actions">
          <button type="button" class="btn btn-sm" data-action="focus-widget">Focus</button>
          <button type="button" class="btn btn-sm" data-action="configure-widget">Settings</button>
          <button type="button" class="btn btn-sm btn-danger" data-action="close-widget">Close</button>
        </div>
      </div>
    `
    
    // Bind widget actions
    this.bindWidgetCardEvents(card, widget)
    
    return card
  }

  bindPluginCardEvents(card, plugin) {
    card.addEventListener("click", async (e) => {
      const action = e.target.dataset.action
      if (!action) return
      
      e.preventDefault()
      e.stopPropagation()
      
      try {
        await this.handlePluginAction(action, plugin)
      } catch (error) {
        console.error(`Plugin action '${action}' failed:`, error)
        this.showStatus(`Action failed: ${error.message}`, "error")
      }
    })
  }

  bindInstalledPluginCardEvents(card, installation) {
    card.addEventListener("click", async (e) => {
      const action = e.target.dataset.action
      if (!action) return
      
      e.preventDefault()
      e.stopPropagation()
      
      try {
        await this.handleInstalledPluginAction(action, installation)
      } catch (error) {
        console.error(`Installed plugin action '${action}' failed:`, error)
        this.showStatus(`Action failed: ${error.message}`, "error")
      }
    })
  }

  bindWidgetCardEvents(card, widget) {
    card.addEventListener("click", async (e) => {
      const action = e.target.dataset.action
      if (!action) return
      
      e.preventDefault()
      e.stopPropagation()
      
      try {
        await this.handleWidgetAction(action, widget)
      } catch (error) {
        console.error(`Widget action '${action}' failed:`, error)
        this.showStatus(`Action failed: ${error.message}`, "error")
      }
    })
  }

  async handlePluginAction(action, plugin) {
    switch (action) {
    case "install-plugin":
      await this.installPlugin(plugin)
      break
    case "view-details":
      await this.showPluginDetails(plugin)
      break
    case "create-widget":
      await this.createPluginWidget(plugin)
      break
    }
  }

  async handleInstalledPluginAction(action, installation) {
    switch (action) {
    case "enable-plugin":
      await this.enablePlugin(installation)
      break
    case "disable-plugin":
      await this.disablePlugin(installation)
      break
    case "uninstall-plugin":
      await this.uninstallPlugin(installation)
      break
    case "configure-plugin":
      await this.configurePlugin(installation)
      break
    case "view-health":
      await this.showPluginHealth(installation)
      break
    }
  }

  async handleWidgetAction(action, widget) {
    if (!this.widgetFramework) return
    
    switch (action) {
    case "focus-widget":
      this.widgetFramework.focusWidget(widget)
      this.close()
      break
    case "configure-widget":
      await this.widgetFramework.showWidgetSettings(widget)
      break
    case "close-widget":
      await this.widgetFramework.closeWidget(widget)
      this.renderWidgetsView() // Refresh the view
      break
    }
  }

  // Plugin Management
  async installPlugin(plugin) {
    this.showLoading(`Installing ${plugin.name}...`)
    
    try {
      const result = await this.apiCall(`/${plugin.id}/install`, "POST")
      
      if (result.success) {
        this.showStatus(`${plugin.name} installed successfully!`, "success")
        await this.refreshData()
        this.emit("plugin:installed", { plugin, result })
      } else {
        throw new Error(result.error || "Installation failed")
      }
    } catch (error) {
      this.showStatus(`Failed to install ${plugin.name}: ${error.message}`, "error")
      throw error
    } finally {
      this.hideLoading()
    }
  }

  async enablePlugin(installation) {
    const result = await this.apiCall(`/${installation.id}/enable`, "PATCH")
    
    if (result.success) {
      this.showStatus("Plugin enabled successfully!", "success")
      await this.refreshData()
      this.emit("plugin:enabled", { installation, result })
    } else {
      throw new Error(result.error || "Enable failed")
    }
  }

  async disablePlugin(installation) {
    const result = await this.apiCall(`/${installation.id}/disable`, "PATCH")
    
    if (result.success) {
      this.showStatus("Plugin disabled successfully!", "success")
      await this.refreshData()
      this.emit("plugin:disabled", { installation, result })
    } else {
      throw new Error(result.error || "Disable failed")
    }
  }

  async uninstallPlugin(installation) {
    const confirmed = confirm(`Are you sure you want to uninstall ${installation.name}?`)
    if (!confirmed) return
    
    const result = await this.apiCall(`/${installation.id}/uninstall`, "DELETE")
    
    if (result.success) {
      this.showStatus("Plugin uninstalled successfully!", "success")
      await this.refreshData()
      this.emit("plugin:uninstalled", { installation, result })
    } else {
      throw new Error(result.error || "Uninstall failed")
    }
  }

  async createPluginWidget(plugin) {
    if (!this.widgetFramework) {
      alert("Widget framework is not available")
      return
    }
    
    if (!this.installedPlugins.has(plugin.id)) {
      const install = confirm(`${plugin.name} is not installed. Install it now?`)
      if (install) {
        await this.installPlugin(plugin)
      } else {
        return
      }
    }
    
    await this.widgetFramework.createWidget("plugin", {
      title: `${plugin.name} Widget`,
      pluginId: plugin.id
    })
    
    this.close()
    this.emit("widget:created-from-plugin", { plugin })
  }

  // Filtering and Search
  getFilteredPlugins() {
    const searchTerm = this.container.querySelector(".search-input").value.toLowerCase()
    const categoryFilter = this.container.querySelector(".category-filter").value
    const sortBy = this.container.querySelector(".sort-filter").value
    
    let plugins = Array.from(this.plugins.values())
    
    // Apply search filter
    if (searchTerm) {
      plugins = plugins.filter(plugin => 
        plugin.name.toLowerCase().includes(searchTerm) ||
        plugin.description.toLowerCase().includes(searchTerm) ||
        plugin.author.toLowerCase().includes(searchTerm) ||
        (plugin.keywords && plugin.keywords.toLowerCase().includes(searchTerm))
      )
    }
    
    // Apply category filter
    if (categoryFilter) {
      plugins = plugins.filter(plugin => plugin.category === categoryFilter)
    }
    
    // Apply sorting
    plugins.sort((a, b) => {
      switch (sortBy) {
      case "name":
        return a.name.localeCompare(b.name)
      case "author":
        return a.author.localeCompare(b.author)
      case "category":
        return a.category.localeCompare(b.category)
      case "created_at":
        return new Date(b.created_at) - new Date(a.created_at)
      default:
        return 0
      }
    })
    
    // Separate featured and regular
    const featured = plugins.filter(p => p.featured)
    const regular = plugins.filter(p => !p.featured)
    
    return { featured, regular }
  }

  debounceSearch() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.applyFilters(), 300)
  }

  applyFilters() {
    if (this.currentView === "marketplace") {
      this.renderMarketplaceView()
    }
  }

  // Helper Methods
  getStatusText(status) {
    const statusMap = {
      "not_installed": "Not Installed",
      "installed": "Installed",
      "active": "Active",
      "disabled": "Disabled",
      "error": "Error",
      "updating": "Updating..."
    }
    return statusMap[status] || status
  }

  getPluginActions(plugin, status) {
    switch (status) {
    case "not_installed":
      return `
          <button type="button" class="btn btn-primary btn-sm" data-action="install-plugin">Install</button>
          <button type="button" class="btn btn-secondary btn-sm" data-action="view-details">Details</button>
        `
    case "installed":
    case "active":
      return `
          <button type="button" class="btn btn-primary btn-sm" data-action="create-widget">Create Widget</button>
          <button type="button" class="btn btn-secondary btn-sm" data-action="view-details">Details</button>
        `
    default:
      return `
          <button type="button" class="btn btn-secondary btn-sm" data-action="view-details">Details</button>
        `
    }
  }

  getInstalledPluginActions(installation) {
    const actions = []
    
    if (installation.status === "disabled") {
      actions.push("<button type=\"button\" class=\"btn btn-success btn-sm\" data-action=\"enable-plugin\">Enable</button>")
    } else if (installation.status === "installed" || installation.status === "active") {
      actions.push("<button type=\"button\" class=\"btn btn-warning btn-sm\" data-action=\"disable-plugin\">Disable</button>")
    }
    
    actions.push("<button type=\"button\" class=\"btn btn-secondary btn-sm\" data-action=\"configure-plugin\">Configure</button>")
    actions.push("<button type=\"button\" class=\"btn btn-info btn-sm\" data-action=\"view-health\">Health</button>")
    actions.push("<button type=\"button\" class=\"btn btn-danger btn-sm\" data-action=\"uninstall-plugin\">Uninstall</button>")
    
    return actions.join("")
  }

  formatDate(dateString) {
    const date = new Date(dateString)
    return date.toLocaleDateString() + " " + date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // View Management
  switchView(viewName) {
    if (this.currentView === viewName) return
    
    // Update navigation
    this.container.querySelectorAll(".nav-btn").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.view === viewName)
    })
    
    // Update view
    this.container.querySelectorAll(".marketplace-view").forEach(view => {
      view.style.display = view.dataset.view === viewName ? "block" : "none"
    })
    
    this.currentView = viewName
    this.updateUI()
    
    this.emit("marketplace:view-changed", { view: viewName })
  }

  // Status and Loading
  showStatus(message, type = "info") {
    const statusEl = this.container.querySelector(".status-text")
    statusEl.textContent = message
    statusEl.className = `status-text ${type}`
    
    // Auto-clear success messages
    if (type === "success") {
      setTimeout(() => {
        statusEl.textContent = ""
        statusEl.className = "status-text"
      }, 3000)
    }
  }

  showLoading(message = "Loading...") {
    const loadingEl = this.container.querySelector(".loading-indicator")
    loadingEl.textContent = message
    loadingEl.style.display = "block"
  }

  hideLoading() {
    const loadingEl = this.container.querySelector(".loading-indicator")
    loadingEl.style.display = "none"
  }

  // API Integration
  async apiCall(endpoint, method = "GET", body = null) {
    const url = `${this.options.baseUrl}${endpoint}`
    const options = {
      method: method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=\"csrf-token\"]")?.content
      }
    }
    
    if (body) {
      options.body = JSON.stringify(body)
    }
    
    let retries = 0
    while (retries < this.options.maxRetries) {
      try {
        const response = await fetch(url, options)
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        
        return await response.json()
      } catch (error) {
        retries++
        if (retries >= this.options.maxRetries) {
          throw error
        }
        await new Promise(resolve => setTimeout(resolve, 1000 * retries))
      }
    }
  }

  // Cache Management
  getFromCache(key) {
    const cached = this.cache.get(key)
    if (!cached) return null
    
    if (Date.now() - cached.timestamp > this.options.cacheTimeout) {
      this.cache.delete(key)
      return null
    }
    
    return cached.data
  }

  setCache(key, data) {
    this.cache.set(key, {
      data: data,
      timestamp: Date.now()
    })
  }

  async refreshDataIfStale() {
    const marketplaceStale = !this.getFromCache("marketplace_data")
    const installedStale = !this.getFromCache("installed_plugins")
    
    if (marketplaceStale || installedStale) {
      await this.refreshData()
    }
  }

  setupAutoRefresh() {
    // Refresh every 5 minutes when marketplace is open
    setInterval(() => {
      if (this.isOpen) {
        this.refreshDataIfStale()
      }
    }, 5 * 60 * 1000)
  }

  // Widget Framework Integration
  registerWidgetFramework(widgetFramework) {
    this.widgetFramework = widgetFramework
    this.emit("marketplace:widget-framework-connected", { widgetFramework })
  }

  async loadWidgetPlugin(pluginId, widget) {
    // This would load and initialize a plugin for a widget
    // Implementation depends on plugin architecture
    return {
      controller: null, // Plugin controller instance
      success: true
    }
  }

  async cleanupWidgetPlugin(widget) {
    // Cleanup plugin resources when widget is closed
    if (widget.controller) {
      widget.controller.destroy?.()
    }
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

// Create global instance
window.PluginMarketplace = new PluginMarketplace()

// Export for module usage
export default PluginMarketplace