import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

// Connects to data-controller="plugin-marketplace"
export default class extends Controller {
  static targets = [
    "marketplace", "content", "closeButton", "navButton", "view",
    "searchInput", "categoryFilter", "sortFilter", "refreshButton",
    "featuredGrid", "mainGrid", "installedList", "widgetsList",
    "installedEmptyState", "widgetsEmptyState", "loadingState", "errorState",
    "installedCount", "widgetCount", "pagination", "paginationStart", 
    "paginationEnd", "paginationTotal", "prevButton", "nextButton",
    "statusText", "lastUpdated", "errorMessage"
  ]

  static values = {
    userId: Number,
    defaultView: { type: String, default: "marketplace" },
    enableSearch: { type: Boolean, default: true },
    enableFilters: { type: Boolean, default: true },
    itemsPerPage: { type: Number, default: 12 }
  }

  static classes = [
    "marketplaceVisible", "contentVisible"
  ]

  connect() {
    // State management
    this.isOpen = false
    this.currentView = this.defaultViewValue
    this.currentPage = 1
    this.totalPages = 1
    this.searchQuery = ""
    this.selectedCategory = ""
    this.sortBy = "name"
    this.isLoading = false
    
    // Data storage
    this.plugins = new Map()
    this.installedPlugins = new Map()
    this.activeWidgets = new Map()
    this.cache = new Map()
    
    // Debounced functions
    this.debouncedSearch = debounce(300, this.performSearch.bind(this))
    
    // Initialize widget framework connection
    this.connectToWidgetFramework()
    
    // Setup global marketplace access
    this.setupGlobalAccess()
    
    // Setup event listeners
    this.setupEventListeners()
    
    // Load initial data
    this.loadInitialData()
  }

  disconnect() {
    this.cleanup()
  }

  // === INITIALIZATION ===

  setupGlobalAccess() {
    // Make marketplace globally accessible
    if (!window.PluginMarketplace) {
      window.PluginMarketplace = {
        open: this.open.bind(this),
        close: this.close.bind(this),
        isOpen: () => this.isOpen,
        refresh: this.refresh.bind(this),
        installPlugin: this.installPlugin.bind(this),
        createWidget: this.createWidget.bind(this)
      }
    }
  }

  connectToWidgetFramework() {
    // Connect to widget framework if available
    if (window.widgetFrameworks) {
      // Find the active widget framework (there might be multiple for different documents)
      const frameworks = Array.from(window.widgetFrameworks.values())
      if (frameworks.length > 0) {
        this.widgetFramework = frameworks[0] // Use the first available framework
        this.widgetFramework.registerMarketplace?.(this)
      }
    }
  }

  setupEventListeners() {
    // Close on escape key
    document.addEventListener("keydown", this.handleGlobalKeydown.bind(this))
    
    // Widget framework events
    document.addEventListener("widget-framework:widget-created", this.handleWidgetCreated.bind(this))
    document.addEventListener("widget-framework:widget-closed", this.handleWidgetClosed.bind(this))
    
    // Plugin installation events
    document.addEventListener("plugin:installed", this.handlePluginInstalled.bind(this))
    document.addEventListener("plugin:uninstalled", this.handlePluginUninstalled.bind(this))
  }

  async loadInitialData() {
    try {
      await this.loadMarketplaceData()
      await this.loadInstalledPlugins()
      await this.loadActiveWidgets()
      this.updateCounts()
    } catch (error) {
      console.error("Failed to load initial marketplace data:", error)
      this.showError("Failed to load marketplace data")
    }
  }

  // === PUBLIC API ===

  async open() {
    if (this.isOpen) return
    
    this.isOpen = true
    this.showMarketplace()
    
    // Focus search input if available
    if (this.hasSearchInputTarget && this.enableSearchValue) {
      setTimeout(() => this.searchInputTarget.focus(), 100)
    }
    
    // Refresh data if stale
    await this.refreshIfStale()
    
    this.dispatch("opened")
  }

  close() {
    if (!this.isOpen) return
    
    this.isOpen = false
    this.hideMarketplace()
    this.dispatch("closed")
  }

  async refresh() {
    this.showLoading("Refreshing marketplace data...")
    
    try {
      // Clear cache
      this.cache.clear()
      
      // Reload all data
      await Promise.all([
        this.loadMarketplaceData(),
        this.loadInstalledPlugins(),
        this.loadActiveWidgets()
      ])
      
      this.renderCurrentView()
      this.updateCounts()
      this.updateLastUpdated()
      this.showStatus("Marketplace refreshed successfully", "success")
    } catch (error) {
      console.error("Failed to refresh marketplace:", error)
      this.showError("Failed to refresh marketplace data")
    } finally {
      this.hideLoading()
    }
  }

  // === UI MANAGEMENT ===

  showMarketplace() {
    this.marketplaceTarget.classList.add(...this.marketplaceVisibleClasses)
    setTimeout(() => {
      this.contentTarget.classList.add(...this.contentVisibleClasses)
    }, 50)
  }

  hideMarketplace() {
    this.contentTarget.classList.remove(...this.contentVisibleClasses)
    setTimeout(() => {
      this.marketplaceTarget.classList.remove(...this.marketplaceVisibleClasses)
    }, 300)
  }

  switchView(event) {
    const newView = event.currentTarget.dataset.view || event.detail?.view
    if (newView === this.currentView) return
    
    // Update navigation
    this.navButtonTargets.forEach(btn => {
      const isActive = btn.dataset.view === newView
      btn.classList.toggle("text-blue-600", isActive)
      btn.classList.toggle("dark:text-blue-400", isActive)
      btn.classList.toggle("border-blue-600", isActive)
      btn.classList.toggle("dark:border-blue-400", isActive)
      btn.classList.toggle("bg-white", isActive)
      btn.classList.toggle("dark:bg-gray-700", isActive)
    })
    
    // Update views
    this.viewTargets.forEach(view => {
      view.style.display = view.dataset.view === newView ? "block" : "none"
    })
    
    this.currentView = newView
    this.renderCurrentView()
    
    this.dispatch("view-changed", { detail: { view: newView } })
  }

  async renderCurrentView() {
    switch (this.currentView) {
    case "marketplace":
      await this.renderMarketplaceView()
      break
    case "installed":
      await this.renderInstalledView()
      break
    case "widgets":
      await this.renderWidgetsView()
      break
    }
  }

  // === DATA LOADING ===

  async loadMarketplaceData() {
    const cacheKey = "marketplace_plugins"
    const cached = this.getFromCache(cacheKey)
    
    if (cached) {
      this.processMarketplaceData(cached)
      return
    }
    
    try {
      const response = await this.apiCall("/extensions/marketplace")
      this.setCache(cacheKey, response)
      this.processMarketplaceData(response)
    } catch (error) {
      console.error("Failed to load marketplace data:", error)
      throw error
    }
  }

  async loadInstalledPlugins() {
    const cacheKey = "installed_plugins"
    const cached = this.getFromCache(cacheKey)
    
    if (cached) {
      this.processInstalledPlugins(cached)
      return
    }
    
    try {
      const response = await this.apiCall("/extensions/installed")
      this.setCache(cacheKey, response)
      this.processInstalledPlugins(response)
    } catch (error) {
      console.error("Failed to load installed plugins:", error)
      throw error
    }
  }

  async loadActiveWidgets() {
    if (!this.widgetFramework) {
      this.activeWidgets.clear()
      return
    }
    
    // Get widgets from widget framework
    const widgets = Array.from(this.widgetFramework.widgets.values())
    this.activeWidgets.clear()
    widgets.forEach(widget => {
      this.activeWidgets.set(widget.id, widget)
    })
  }

  processMarketplaceData(data) {
    this.plugins.clear()
    
    // Process plugins data
    if (data.plugins) {
      data.plugins.forEach(plugin => {
        this.plugins.set(plugin.id, plugin)
      })
    }
    
    // Update category filter if available
    if (this.hasCategoryFilterTarget && data.categories) {
      this.updateCategoryFilter(data.categories)
    }
  }

  processInstalledPlugins(data) {
    this.installedPlugins.clear()
    
    if (data.installations) {
      data.installations.forEach(installation => {
        this.installedPlugins.set(installation.plugin_id, installation)
      })
    }
  }

  updateCategoryFilter(categories) {
    const filter = this.categoryFilterTarget
    const currentValue = filter.value
    
    // Clear existing options (except "All Categories")
    while (filter.children.length > 1) {
      filter.removeChild(filter.lastChild)
    }
    
    // Add category options
    categories.forEach(category => {
      const option = document.createElement("option")
      option.value = category
      option.textContent = category
      filter.appendChild(option)
    })
    
    // Restore previous selection
    filter.value = currentValue
  }

  // === VIEW RENDERING ===

  async renderMarketplaceView() {
    if (!this.hasFeaturedGridTarget || !this.hasMainGridTarget) return
    
    const filteredPlugins = this.getFilteredPlugins()
    
    // Render featured plugins
    const featuredPlugins = filteredPlugins.filter(p => p.featured).slice(0, 6)
    this.renderPluginGrid(this.featuredGridTarget, featuredPlugins, true)
    
    // Render main grid with pagination
    const regularPlugins = filteredPlugins.filter(p => !p.featured)
    const paginatedPlugins = this.paginatePlugins(regularPlugins)
    this.renderPluginGrid(this.mainGridTarget, paginatedPlugins, false)
    
    this.updatePagination(regularPlugins.length)
  }

  async renderInstalledView() {
    if (!this.hasInstalledListTarget) return
    
    const installed = Array.from(this.installedPlugins.values())
    
    if (installed.length === 0) {
      this.installedListTarget.innerHTML = ""
      this.installedEmptyStateTarget.style.display = "block"
      return
    }
    
    this.installedEmptyStateTarget.style.display = "none"
    this.renderInstalledList(installed)
  }

  async renderWidgetsView() {
    if (!this.hasWidgetsListTarget) return
    
    const widgets = Array.from(this.activeWidgets.values())
    
    if (widgets.length === 0) {
      this.widgetsListTarget.innerHTML = ""
      this.widgetsEmptyStateTarget.style.display = "block"
      return
    }
    
    this.widgetsEmptyStateTarget.style.display = "none"
    this.renderWidgetsList(widgets)
  }

  renderPluginGrid(container, plugins, featured = false) {
    container.innerHTML = ""
    
    plugins.forEach(plugin => {
      const card = this.createPluginCard(plugin, featured)
      container.appendChild(card)
    })
    
    if (plugins.length === 0 && !featured) {
      container.innerHTML = `
        <div class="col-span-full text-center py-12">
          <div class="text-gray-400 dark:text-gray-600 mb-4">
            <svg class="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No plugins found</h3>
          <p class="text-gray-500 dark:text-gray-400">Try adjusting your search or filters.</p>
        </div>
      `
    }
  }

  renderInstalledList(installations) {
    this.installedListTarget.innerHTML = ""
    
    installations.forEach(installation => {
      const item = this.createInstalledItem(installation)
      this.installedListTarget.appendChild(item)
    })
  }

  renderWidgetsList(widgets) {
    this.widgetsListTarget.innerHTML = ""
    
    widgets.forEach(widget => {
      const item = this.createWidgetItem(widget)
      this.widgetsListTarget.appendChild(item)
    })
  }

  // === CARD CREATION ===

  createPluginCard(plugin, featured = false) {
    const card = document.createElement("div")
    card.className = `plugin-card ${featured ? "featured" : ""} bg-white dark:bg-gray-800 rounded-xl shadow-md hover:shadow-xl transition-all duration-300 border border-gray-200 dark:border-gray-700 hover:border-blue-300 dark:hover:border-blue-600 overflow-hidden group cursor-pointer`
    card.dataset.pluginId = plugin.id
    
    const installation = this.installedPlugins.get(plugin.id)
    const status = installation ? installation.status : "not_installed"
    
    card.innerHTML = `
      <div class="plugin-header p-4 border-b border-gray-100 dark:border-gray-700">
        <div class="flex items-center">
          <div class="plugin-icon w-12 h-12 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white text-xl font-bold shadow-lg group-hover:scale-110 transition-transform duration-200">
            ${plugin.icon || "🔌"}
          </div>
          <div class="plugin-info flex-1 ml-4">
            <h4 class="plugin-name text-lg font-semibold text-gray-900 dark:text-gray-100 group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors duration-200">
              ${this.escapeHtml(plugin.name)}
            </h4>
            <div class="plugin-meta flex items-center space-x-2 text-sm text-gray-500 dark:text-gray-400 mt-1">
              <span>by ${this.escapeHtml(plugin.author)}</span>
              <span>•</span>
              <span>v${this.escapeHtml(plugin.version)}</span>
              ${featured ? '<span class="bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300 px-2 py-1 text-xs font-medium rounded-full">Featured</span>' : ""}
            </div>
          </div>
        </div>
      </div>
      
      <div class="plugin-body p-4 flex-1">
        <p class="plugin-description text-gray-600 dark:text-gray-300 text-sm line-clamp-2 mb-3">
          ${this.escapeHtml(plugin.description)}
        </p>
        
        <div class="plugin-tags flex flex-wrap gap-2 mb-3">
          <span class="tag bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300 px-2 py-1 text-xs font-medium rounded-full">
            ${this.escapeHtml(plugin.category)}
          </span>
          ${(plugin.keywords || []).map(keyword => 
    `<span class="tag bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300 px-2 py-1 text-xs font-medium rounded-full">${this.escapeHtml(keyword)}</span>`
  ).join("")}
        </div>
        
        <div class="flex items-center justify-between text-sm text-gray-500 dark:text-gray-400">
          <div class="flex items-center space-x-1">
            <svg class="w-4 h-4 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
            </svg>
            <span>${plugin.rating || "4.5"}</span>
          </div>
          <span>${plugin.downloads || "1k+"} downloads</span>
        </div>
      </div>
      
      <div class="plugin-footer p-4 bg-gray-50 dark:bg-gray-700/50 border-t border-gray-100 dark:border-gray-700 flex items-center justify-between">
        <div class="status-badge ${this.getStatusBadgeClass(status)}">
          ${this.getStatusText(status)}
        </div>
        
        <div class="flex space-x-2">
          ${this.getActionButtons(plugin, status).map(button => 
    `<button type="button" class="${this.getActionButtonClass(button.variant)}" data-action="click->plugin-marketplace#${button.action}" data-plugin-id="${plugin.id}">
              ${button.text}
            </button>`
  ).join("")}
        </div>
      </div>
    `
    
    return card
  }

  createInstalledItem(installation) {
    const div = document.createElement("div")
    div.className = "installed-item bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4"
    div.dataset.pluginId = installation.plugin_id
    
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold">
            ${installation.icon || "🔌"}
          </div>
          <div>
            <h4 class="font-semibold text-gray-900 dark:text-gray-100">
              ${this.escapeHtml(installation.name)}
            </h4>
            <div class="text-sm text-gray-500 dark:text-gray-400">
              v${this.escapeHtml(installation.version)} • Installed ${this.formatDate(installation.installed_at)}
            </div>
          </div>
        </div>
        
        <div class="flex items-center space-x-3">
          <div class="status-badge ${this.getStatusBadgeClass(installation.status)}">
            ${this.getStatusText(installation.status)}
          </div>
          
          <div class="flex space-x-2">
            ${this.getInstalledActionButtons(installation).map(button => 
    `<button type="button" class="${this.getActionButtonClass(button.variant)}" data-action="click->plugin-marketplace#${button.action}" data-plugin-id="${installation.plugin_id}">
                ${button.text}
              </button>`
  ).join("")}
          </div>
        </div>
      </div>
    `
    
    return div
  }

  createWidgetItem(widget) {
    const div = document.createElement("div")
    div.className = "widget-item bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4"
    div.dataset.widgetId = widget.id
    
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-green-500 to-blue-600 flex items-center justify-center text-white font-bold">
            ${this.getWidgetIcon(widget.type)}
          </div>
          <div>
            <h4 class="font-semibold text-gray-900 dark:text-gray-100">
              ${this.escapeHtml(widget.title)}
            </h4>
            <div class="text-sm text-gray-500 dark:text-gray-400">
              ${widget.type} • ${widget.size.width}×${widget.size.height} • Created ${this.formatDate(widget.created)}
            </div>
          </div>
        </div>
        
        <div class="flex items-center space-x-3">
          <div class="status-badge ${widget.minimized ? "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300" : "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"}">
            ${widget.minimized ? "Minimized" : "Active"}
          </div>
          
          <div class="flex space-x-2">
            <button type="button" class="${this.getActionButtonClass("secondary")}" data-action="click->plugin-marketplace#focusWidget" data-widget-id="${widget.id}">
              Focus
            </button>
            <button type="button" class="${this.getActionButtonClass("secondary")}" data-action="click->plugin-marketplace#configureWidget" data-widget-id="${widget.id}">
              Settings
            </button>
            <button type="button" class="${this.getActionButtonClass("danger")}" data-action="click->plugin-marketplace#closeWidget" data-widget-id="${widget.id}">
              Close
            </button>
          </div>
        </div>
      </div>
    `
    
    return div
  }

  // === FILTERING AND PAGINATION ===

  getFilteredPlugins() {
    let plugins = Array.from(this.plugins.values())
    
    // Apply search filter
    if (this.searchQuery) {
      const query = this.searchQuery.toLowerCase()
      plugins = plugins.filter(plugin => 
        plugin.name.toLowerCase().includes(query) ||
        plugin.description.toLowerCase().includes(query) ||
        plugin.author.toLowerCase().includes(query) ||
        (plugin.keywords || []).some(k => k.toLowerCase().includes(query))
      )
    }
    
    // Apply category filter
    if (this.selectedCategory) {
      plugins = plugins.filter(plugin => plugin.category === this.selectedCategory)
    }
    
    // Apply sorting
    plugins.sort((a, b) => {
      switch (this.sortBy) {
      case "name":
        return a.name.localeCompare(b.name)
      case "author":
        return a.author.localeCompare(b.author)
      case "category":
        return a.category.localeCompare(b.category)
      case "rating":
        return (b.rating || 0) - (a.rating || 0)
      case "downloads":
        return this.parseDownloads(b.downloads) - this.parseDownloads(a.downloads)
      case "updated":
        return new Date(b.updated_at || 0) - new Date(a.updated_at || 0)
      default:
        return 0
      }
    })
    
    return plugins
  }

  paginatePlugins(plugins) {
    const startIndex = (this.currentPage - 1) * this.itemsPerPageValue
    const endIndex = startIndex + this.itemsPerPageValue
    return plugins.slice(startIndex, endIndex)
  }

  updatePagination(totalItems) {
    this.totalPages = Math.ceil(totalItems / this.itemsPerPageValue)
    
    if (this.hasPaginationTarget) {
      this.paginationTarget.style.display = this.totalPages > 1 ? "flex" : "none"
    }
    
    if (this.hasPaginationStartTarget) {
      const start = (this.currentPage - 1) * this.itemsPerPageValue + 1
      this.paginationStartTarget.textContent = start
    }
    
    if (this.hasPaginationEndTarget) {
      const end = Math.min(this.currentPage * this.itemsPerPageValue, totalItems)
      this.paginationEndTarget.textContent = end
    }
    
    if (this.hasPaginationTotalTarget) {
      this.paginationTotalTarget.textContent = totalItems
    }
    
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.disabled = this.currentPage <= 1
    }
    
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = this.currentPage >= this.totalPages
    }
  }

  // === EVENT HANDLERS ===

  handleBackdropClick(event) {
    if (event.target === this.marketplaceTarget) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  handleGlobalKeydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
    }
  }

  handleSearch(event) {
    this.searchQuery = event.target.value
    this.currentPage = 1
    this.debouncedSearch()
  }

  handleCategoryFilter(event) {
    this.selectedCategory = event.target.value
    this.currentPage = 1
    this.renderCurrentView()
  }

  handleSortFilter(event) {
    this.sortBy = event.target.value
    this.currentPage = 1
    this.renderCurrentView()
  }

  performSearch() {
    this.renderCurrentView()
  }

  nextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++
      this.renderCurrentView()
    }
  }

  previousPage() {
    if (this.currentPage > 1) {
      this.currentPage--
      this.renderCurrentView()
    }
  }

  // === PLUGIN ACTIONS ===

  async installPlugin(event) {
    const pluginId = event.currentTarget.dataset.pluginId
    const plugin = this.plugins.get(parseInt(pluginId))
    
    if (!plugin) return
    
    this.showLoading(`Installing ${plugin.name}...`)
    
    try {
      const response = await this.apiCall(`/extensions/${pluginId}/install`, "POST")
      
      if (response.success) {
        await this.loadInstalledPlugins()
        this.renderCurrentView()
        this.updateCounts()
        this.showStatus(`${plugin.name} installed successfully!`, "success")
        this.dispatch("plugin-installed", { detail: { plugin, installation: response.installation } })
      } else {
        throw new Error(response.error || "Installation failed")
      }
    } catch (error) {
      console.error("Plugin installation failed:", error)
      this.showStatus(`Failed to install ${plugin.name}: ${error.message}`, "error")
    } finally {
      this.hideLoading()
    }
  }

  async enablePlugin(event) {
    const pluginId = event.currentTarget.dataset.pluginId
    const installation = this.installedPlugins.get(parseInt(pluginId))
    
    if (!installation) return
    
    try {
      const response = await this.apiCall(`/extensions/${installation.id}/enable`, "PATCH")
      
      if (response.success) {
        await this.loadInstalledPlugins()
        this.renderCurrentView()
        this.showStatus("Plugin enabled successfully!", "success")
      } else {
        throw new Error(response.error || "Enable failed")
      }
    } catch (error) {
      console.error("Failed to enable plugin:", error)
      this.showStatus(`Failed to enable plugin: ${error.message}`, "error")
    }
  }

  async disablePlugin(event) {
    const pluginId = event.currentTarget.dataset.pluginId
    const installation = this.installedPlugins.get(parseInt(pluginId))
    
    if (!installation) return
    
    try {
      const response = await this.apiCall(`/extensions/${installation.id}/disable`, "PATCH")
      
      if (response.success) {
        await this.loadInstalledPlugins()
        this.renderCurrentView()
        this.showStatus("Plugin disabled successfully!", "success")
      } else {
        throw new Error(response.error || "Disable failed")
      }
    } catch (error) {
      console.error("Failed to disable plugin:", error)
      this.showStatus(`Failed to disable plugin: ${error.message}`, "error")
    }
  }

  async uninstall(event) {
    const pluginId = event.currentTarget.dataset.pluginId
    const installation = this.installedPlugins.get(parseInt(pluginId))
    
    if (!installation) return
    
    const confirmed = confirm(`Are you sure you want to uninstall ${installation.name}?`)
    if (!confirmed) return
    
    try {
      const response = await this.apiCall(`/extensions/${installation.id}`, "DELETE")
      
      if (response.success) {
        this.installedPlugins.delete(parseInt(pluginId))
        this.renderCurrentView()
        this.updateCounts()
        this.showStatus("Plugin uninstalled successfully!", "success")
        this.dispatch("plugin-uninstalled", { detail: { installation } })
      } else {
        throw new Error(response.error || "Uninstall failed")
      }
    } catch (error) {
      console.error("Failed to uninstall plugin:", error)
      this.showStatus(`Failed to uninstall plugin: ${error.message}`, "error")
    }
  }

  viewDetails(event) {
    const pluginId = event.currentTarget.dataset.pluginId
    const plugin = this.plugins.get(parseInt(pluginId))
    
    if (!plugin) return
    
    this.dispatch("show-plugin-details", { detail: { plugin } })
  }

  configure(event) {
    const pluginId = event.currentTarget.dataset.pluginId
    const installation = this.installedPlugins.get(parseInt(pluginId))
    
    if (!installation) return
    
    this.dispatch("show-plugin-config", { detail: { installation } })
  }

  // === WIDGET ACTIONS ===

  async createWidget(event) {
    const pluginId = event?.currentTarget?.dataset?.pluginId
    
    if (pluginId) {
      // Create widget from plugin
      const plugin = this.plugins.get(parseInt(pluginId))
      const installation = this.installedPlugins.get(parseInt(pluginId))
      
      if (!plugin || !installation) return
      
      if (installation.status !== "active" && installation.status !== "installed") {
        this.showStatus("Plugin must be active to create widgets", "error")
        return
      }
      
      if (!this.widgetFramework) {
        this.showStatus("Widget framework not available", "error")
        return
      }
      
      try {
        await this.widgetFramework.createWidget("plugin", {
          title: `${plugin.name} Widget`,
          pluginId: plugin.id
        })
        
        await this.loadActiveWidgets()
        this.updateCounts()
        this.close()
        this.showStatus(`${plugin.name} widget created successfully!`, "success")
      } catch (error) {
        console.error("Failed to create widget:", error)
        this.showStatus("Failed to create widget", "error")
      }
    } else {
      // Show widget creation wizard
      this.dispatch("show-widget-creator", { detail: {} })
    }
  }

  focusWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    const widget = this.activeWidgets.get(widgetId)
    
    if (widget && this.widgetFramework) {
      this.widgetFramework.focusWidget(widget)
      this.close()
    }
  }

  configureWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    const widget = this.activeWidgets.get(widgetId)
    
    if (widget && this.widgetFramework) {
      this.widgetFramework.showWidgetSettings(widget)
    }
  }

  async closeWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    const widget = this.activeWidgets.get(widgetId)
    
    if (widget && this.widgetFramework) {
      await this.widgetFramework.closeWidget(widget)
      await this.loadActiveWidgets()
      this.renderCurrentView()
      this.updateCounts()
    }
  }

  // === EVENT HANDLERS ===

  handleWidgetCreated(event) {
    // Widget was created externally
    setTimeout(() => {
      this.loadActiveWidgets()
      this.updateCounts()
    }, 100)
  }

  handleWidgetClosed(event) {
    // Widget was closed externally  
    setTimeout(() => {
      this.loadActiveWidgets()
      this.updateCounts()
    }, 100)
  }

  handlePluginInstalled(event) {
    // Plugin was installed externally
    setTimeout(() => {
      this.loadInstalledPlugins()
      this.updateCounts()
    }, 100)
  }

  handlePluginUninstalled(event) {
    // Plugin was uninstalled externally
    setTimeout(() => {
      this.loadInstalledPlugins()
      this.updateCounts()
    }, 100)
  }

  // === UTILITY METHODS ===

  updateCounts() {
    if (this.hasInstalledCountTarget) {
      this.installedCountTarget.textContent = this.installedPlugins.size
    }
    
    if (this.hasWidgetCountTarget) {
      this.widgetCountTarget.textContent = this.activeWidgets.size
    }
  }

  updateLastUpdated() {
    if (this.hasLastUpdatedTarget) {
      this.lastUpdatedTarget.textContent = new Date().toLocaleTimeString()
    }
  }

  showLoading(message = "Loading...") {
    this.isLoading = true
    if (this.hasLoadingStateTarget) {
      this.loadingStateTarget.style.display = "flex"
      this.loadingStateTarget.querySelector("span").textContent = message
    }
    
    this.hideError()
  }

  hideLoading() {
    this.isLoading = false
    if (this.hasLoadingStateTarget) {
      this.loadingStateTarget.style.display = "none"
    }
  }

  showError(message) {
    if (this.hasErrorStateTarget) {
      this.errorStateTarget.style.display = "block"
    }
    
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
    }
    
    this.hideLoading()
  }

  hideError() {
    if (this.hasErrorStateTarget) {
      this.errorStateTarget.style.display = "none"
    }
  }

  showStatus(message, type = "info") {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = message
      this.statusTextTarget.className = `status-text ${type}`
    }
    
    // Auto-clear success messages
    if (type === "success") {
      setTimeout(() => {
        if (this.hasStatusTextTarget) {
          this.statusTextTarget.textContent = "Ready"
          this.statusTextTarget.className = "status-text"
        }
      }, 3000)
    }
  }

  retry() {
    this.hideError()
    this.refresh()
  }

  showHelp() {
    this.dispatch("show-help", { detail: {} })
  }

  async refreshIfStale() {
    const lastRefresh = this.getFromCache("last_refresh")
    const now = Date.now()
    const staleThreshold = 5 * 60 * 1000 // 5 minutes
    
    if (!lastRefresh || (now - lastRefresh) > staleThreshold) {
      await this.refresh()
      this.setCache("last_refresh", now)
    }
  }

  // === HELPER METHODS ===

  getStatusBadgeClass(status) {
    const baseClasses = "px-2 py-1 text-xs font-medium rounded-full"
    
    switch (status) {
    case "installed":
    case "active":
      return `${baseClasses} bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300`
    case "disabled":
      return `${baseClasses} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300`
    case "error":
      return `${baseClasses} bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300`
    default:
      return `${baseClasses} bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300`
    }
  }

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

  getActionButtonClass(variant) {
    const baseClasses = "btn btn-sm px-3 py-1.5 text-xs font-medium rounded-lg transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2"
    
    switch (variant) {
    case "primary":
      return `${baseClasses} bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500`
    case "secondary":
      return `${baseClasses} bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 focus:ring-gray-500`
    case "success":
      return `${baseClasses} bg-green-600 text-white hover:bg-green-700 focus:ring-green-500`
    case "warning":
      return `${baseClasses} bg-yellow-600 text-white hover:bg-yellow-700 focus:ring-yellow-500`
    case "danger":
      return `${baseClasses} bg-red-600 text-white hover:bg-red-700 focus:ring-red-500`
    default:
      return `${baseClasses} bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600`
    }
  }

  getActionButtons(plugin, status) {
    switch (status) {
    case "not_installed":
      return [
        { text: "Install", action: "installPlugin", variant: "primary" },
        { text: "Details", action: "viewDetails", variant: "secondary" }
      ]
    case "installed":
    case "active":
      return [
        { text: "Create Widget", action: "createWidget", variant: "primary" },
        { text: "Configure", action: "configure", variant: "secondary" }
      ]
    case "disabled":
      return [
        { text: "Enable", action: "enablePlugin", variant: "success" },
        { text: "Remove", action: "uninstall", variant: "danger" }
      ]
    default:
      return [
        { text: "Details", action: "viewDetails", variant: "secondary" }
      ]
    }
  }

  getInstalledActionButtons(installation) {
    const buttons = []
    
    if (installation.status === "disabled") {
      buttons.push({ text: "Enable", action: "enablePlugin", variant: "success" })
    } else if (installation.status === "installed" || installation.status === "active") {
      buttons.push({ text: "Disable", action: "disablePlugin", variant: "warning" })
    }
    
    buttons.push({ text: "Configure", action: "configure", variant: "secondary" })
    buttons.push({ text: "Remove", action: "uninstall", variant: "danger" })
    
    return buttons
  }

  getWidgetIcon(type) {
    const iconMap = {
      "text": "📄",
      "notes": "📝",
      "todo": "✅",
      "timer": "⏰",
      "ai-review": "🤖",
      "console": "💻",
      "plugin": "🔌"
    }
    return iconMap[type] || "⊞"
  }

  formatDate(dateString) {
    const date = new Date(dateString)
    return date.toLocaleDateString()
  }

  parseDownloads(downloads) {
    if (!downloads) return 0
    const number = parseFloat(downloads)
    if (downloads.includes("k")) return number * 1000
    if (downloads.includes("M")) return number * 1000000
    return number
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // === API CALLS ===

  async apiCall(endpoint, method = "GET", body = null) {
    const url = endpoint.startsWith("http") ? endpoint : endpoint
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
    
    const response = await fetch(url, options)
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    return await response.json()
  }

  // === CACHE MANAGEMENT ===

  getFromCache(key) {
    const cached = this.cache.get(key)
    if (!cached) return null
    
    const cacheTimeout = 5 * 60 * 1000 // 5 minutes
    if (Date.now() - cached.timestamp > cacheTimeout) {
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

  dispatch(eventName, detail = {}) {
    const event = new CustomEvent(`plugin-marketplace:${eventName}`, {
      detail: { ...detail, controller: this },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  cleanup() {
    // Cancel any pending operations
    if (this.debouncedSearch?.cancel) {
      this.debouncedSearch.cancel()
    }
    
    // Clear cache
    this.cache.clear()
    
    // Remove global access
    if (window.PluginMarketplace?.open === this.open) {
      delete window.PluginMarketplace
    }
  }
}