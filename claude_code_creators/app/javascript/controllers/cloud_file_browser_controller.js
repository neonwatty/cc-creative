import { Controller } from "@hotwired/stimulus"
import { debounce } from "throttle-debounce"

// Connects to data-controller="cloud-file-browser"
export default class extends Controller {
  static targets = [
    "container", 
    "searchInput", 
    "fileList", 
    "loadingSpinner", 
    "emptyState",
    "viewToggle",
    "sortSelect",
    "filterSelect",
    "selectedCount",
    "batchActions",
    "pagination",
    "syncButton",
    "syncStatus"
  ]
  
  static values = {
    integrationId: String,
    viewMode: { type: String, default: "grid" }, // grid or list
    sortBy: { type: String, default: "name" }, // name, date, size, type
    sortOrder: { type: String, default: "asc" }, // asc or desc
    filter: { type: String, default: "all" }, // all, importable, synced
    page: { type: Number, default: 1 },
    perPage: { type: Number, default: 20 },
    searchQuery: String,
    syncInProgress: { type: Boolean, default: false }
  }

  static classes = [
    "loading",
    "error", 
    "empty",
    "gridView",
    "listView",
    "selected",
    "sortAsc",
    "sortDesc"
  ]

  connect() {
    // Initialize debounced search
    this.debouncedSearch = debounce(500, this.performSearch.bind(this))
    
    // Track selected files
    this.selectedFiles = new Set()
    
    // Initialize view
    this.initializeView()
    
    // Load initial data
    this.loadFiles()
    
    // Listen for file selection events
    this.element.addEventListener('file:selected', this.handleFileSelection.bind(this))
    this.element.addEventListener('file:deselected', this.handleFileDeselection.bind(this))
    
    // Listen for sync completion events
    this.element.addEventListener('sync:completed', this.handleSyncCompleted.bind(this))
  }

  disconnect() {
    if (this.syncPollingInterval) {
      clearInterval(this.syncPollingInterval)
    }
  }

  // Initialize view settings
  initializeView() {
    this.updateViewMode()
    this.updateSortIndicators()
    this.updateSelectedCount()
  }

  // Load files from server
  async loadFiles(options = {}) {
    try {
      this.showLoading(true)
      
      const params = new URLSearchParams({
        page: options.page || this.pageValue,
        per_page: this.perPageValue,
        sort_by: this.sortByValue,
        sort_order: this.sortOrderValue,
        filter: this.filterValue,
        ...(this.searchQueryValue && { search: this.searchQueryValue })
      })

      const response = await fetch(`/cloud_integrations/${this.integrationIdValue}/cloud_files?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()
      this.renderFiles(data)
      this.updatePagination(data.pagination)
      
    } catch (error) {
      this.showError(`Failed to load files: ${error.message}`)
    } finally {
      this.showLoading(false)
    }
  }

  // Render files in the browser
  renderFiles(data) {
    if (!data.files || data.files.length === 0) {
      this.showEmptyState()
      return
    }

    this.hideEmptyState()
    
    const filesHtml = data.files.map(file => this.renderFileItem(file)).join('')
    this.fileListTarget.innerHTML = filesHtml
    
    // Clear selection
    this.selectedFiles.clear()
    this.updateSelectedCount()
  }

  // Render individual file item
  renderFileItem(file) {
    const sizeDisplay = this.formatFileSize(file.size)
    const dateDisplay = this.formatDate(file.updated_at)
    const isImportable = file.importable ? 'importable' : ''
    const syncStatus = file.synced ? 'synced' : 'needs-sync'
    
    if (this.viewModeValue === 'grid') {
      return `
        <div class="file-item file-item--grid" data-file-id="${file.id}" data-action="click->cloud-file-browser#toggleFileSelection">
          <div class="file-item__thumbnail">
            <i class="file-icon file-icon--${file.type}" data-type="${file.mime_type}"></i>
          </div>
          <div class="file-item__info">
            <h3 class="file-item__name" title="${file.name}">${file.name}</h3>
            <p class="file-item__meta">${sizeDisplay} • ${dateDisplay}</p>
            <div class="file-item__badges">
              ${file.importable ? '<span class="badge badge--importable">Importable</span>' : ''}
              <span class="badge badge--${syncStatus}">${file.synced ? 'Synced' : 'Needs Sync'}</span>
            </div>
          </div>
          <div class="file-item__actions">
            <input type="checkbox" class="file-checkbox" data-file-id="${file.id}">
            ${file.importable ? `<button class="btn btn--sm btn--primary" data-action="click->cloud-file-browser#importFile" data-file-id="${file.id}">Import</button>` : ''}
            <button class="btn btn--sm btn--secondary" data-action="click->cloud-file-browser#previewFile" data-file-id="${file.id}">Preview</button>
          </div>
        </div>
      `
    } else {
      return `
        <tr class="file-item file-item--list" data-file-id="${file.id}">
          <td class="file-item__checkbox">
            <input type="checkbox" class="file-checkbox" data-file-id="${file.id}" data-action="change->cloud-file-browser#toggleFileSelection">
          </td>
          <td class="file-item__name">
            <div class="file-name-wrapper">
              <i class="file-icon file-icon--${file.type}" data-type="${file.mime_type}"></i>
              <span class="file-name" title="${file.name}">${file.name}</span>
            </div>
          </td>
          <td class="file-item__size">${sizeDisplay}</td>
          <td class="file-item__date">${dateDisplay}</td>
          <td class="file-item__status">
            <span class="badge badge--${syncStatus}">${file.synced ? 'Synced' : 'Needs Sync'}</span>
            ${file.importable ? '<span class="badge badge--importable">Importable</span>' : ''}
          </td>
          <td class="file-item__actions">
            ${file.importable ? `<button class="btn btn--sm btn--primary" data-action="click->cloud-file-browser#importFile" data-file-id="${file.id}">Import</button>` : ''}
            <button class="btn btn--sm btn--secondary" data-action="click->cloud-file-browser#previewFile" data-file-id="${file.id}">Preview</button>
          </td>
        </tr>
      `
    }
  }

  // Search functionality
  search(event) {
    this.searchQueryValue = event.target.value
    this.debouncedSearch()
  }

  performSearch() {
    this.pageValue = 1 // Reset to first page
    this.loadFiles()
  }

  // View mode toggle
  toggleView(event) {
    const newMode = event.target.dataset.viewMode
    this.viewModeValue = newMode
    this.updateViewMode()
    this.loadFiles() // Reload with new view
  }

  updateViewMode() {
    this.element.classList.toggle('file-browser--grid', this.viewModeValue === 'grid')
    this.element.classList.toggle('file-browser--list', this.viewModeValue === 'list')
    
    if (this.hasViewToggleTarget) {
      this.viewToggleTarget.querySelectorAll('[data-view-mode]').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.viewMode === this.viewModeValue)
      })
    }
  }

  // Sorting
  changeSort(event) {
    const [sortBy, sortOrder] = event.target.value.split(':')
    this.sortByValue = sortBy
    this.sortOrderValue = sortOrder
    this.updateSortIndicators()
    this.loadFiles()
  }

  updateSortIndicators() {
    if (this.hasSortSelectTarget) {
      this.sortSelectTarget.value = `${this.sortByValue}:${this.sortOrderValue}`
    }
  }

  // Filtering
  changeFilter(event) {
    this.filterValue = event.target.value
    this.pageValue = 1 // Reset to first page
    this.loadFiles()
  }

  // File selection
  toggleFileSelection(event) {
    const fileItem = event.currentTarget.closest('.file-item')
    const fileId = fileItem.dataset.fileId
    const checkbox = fileItem.querySelector('.file-checkbox')
    
    if (this.selectedFiles.has(fileId)) {
      this.selectedFiles.delete(fileId)
      fileItem.classList.remove(this.selectedClass)
      checkbox.checked = false
      this.dispatch('file:deselected', { detail: { fileId } })
    } else {
      this.selectedFiles.add(fileId)
      fileItem.classList.add(this.selectedClass)
      checkbox.checked = true
      this.dispatch('file:selected', { detail: { fileId } })
    }
    
    this.updateSelectedCount()
  }

  // Select all files
  selectAll(event) {
    const checkboxes = this.fileListTarget.querySelectorAll('.file-checkbox')
    const isSelectAll = event.target.checked
    
    checkboxes.forEach(checkbox => {
      const fileId = checkbox.dataset.fileId
      const fileItem = checkbox.closest('.file-item')
      
      if (isSelectAll && !this.selectedFiles.has(fileId)) {
        this.selectedFiles.add(fileId)
        fileItem.classList.add(this.selectedClass)
        checkbox.checked = true
      } else if (!isSelectAll && this.selectedFiles.has(fileId)) {
        this.selectedFiles.delete(fileId)
        fileItem.classList.remove(this.selectedClass)
        checkbox.checked = false
      }
    })
    
    this.updateSelectedCount()
  }

  // Update selected count display
  updateSelectedCount() {
    const count = this.selectedFiles.size
    
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = count
    }
    
    if (this.hasBatchActionsTarget) {
      this.batchActionsTarget.style.display = count > 0 ? 'block' : 'none'
    }
  }

  // Batch operations
  batchImport(event) {
    event.preventDefault()
    if (this.selectedFiles.size === 0) return
    
    const fileIds = Array.from(this.selectedFiles)
    this.importMultipleFiles(fileIds)
  }

  batchDelete(event) {
    event.preventDefault()
    if (this.selectedFiles.size === 0) return
    
    if (confirm(`Delete ${this.selectedFiles.size} selected files?`)) {
      const fileIds = Array.from(this.selectedFiles)
      this.deleteMultipleFiles(fileIds)
    }
  }

  // Individual file operations
  async importFile(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const fileId = event.target.dataset.fileId
    await this.importSingleFile(fileId)
  }

  async importSingleFile(fileId) {
    try {
      const response = await fetch(`/cloud_integrations/${this.integrationIdValue}/cloud_files/${fileId}/import`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        this.showNotification('File import started', 'success')
        // Optionally refresh the file list
        this.loadFiles()
      } else {
        throw new Error('Import failed')
      }
    } catch (error) {
      this.showNotification(`Import failed: ${error.message}`, 'error')
    }
  }

  async importMultipleFiles(fileIds) {
    // Implementation for batch import
    this.showNotification(`Importing ${fileIds.length} files...`, 'info')
    
    for (const fileId of fileIds) {
      await this.importSingleFile(fileId)
    }
    
    this.selectedFiles.clear()
    this.updateSelectedCount()
  }

  // File preview
  previewFile(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const fileId = event.target.dataset.fileId
    // Dispatch event for file preview
    this.dispatch('file:preview', { detail: { fileId } })
  }

  // Sync operations
  async syncFiles(event) {
    event.preventDefault()
    
    if (this.syncInProgressValue) return
    
    this.syncInProgressValue = true
    this.updateSyncButton()
    
    try {
      const response = await fetch(`/cloud_integrations/${this.integrationIdValue}/cloud_files?sync=true`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        this.showNotification('File sync started', 'success')
        this.startSyncPolling()
      } else {
        throw new Error('Sync failed to start')
      }
    } catch (error) {
      this.showNotification(`Sync failed: ${error.message}`, 'error')
      this.syncInProgressValue = false
      this.updateSyncButton()
    }
  }

  startSyncPolling() {
    // Poll for sync completion every 5 seconds
    this.syncPollingInterval = setInterval(() => {
      this.checkSyncStatus()
    }, 5000)
  }

  async checkSyncStatus() {
    try {
      const response = await fetch(`/cloud_integrations/${this.integrationIdValue}/sync_status`, {
        headers: { 'Accept': 'application/json' }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (!data.syncing) {
          this.handleSyncCompleted()
        }
      }
    } catch (error) {
      console.error('Sync status check failed:', error)
    }
  }

  handleSyncCompleted() {
    this.syncInProgressValue = false
    this.updateSyncButton()
    
    if (this.syncPollingInterval) {
      clearInterval(this.syncPollingInterval)
      this.syncPollingInterval = null
    }
    
    this.showNotification('File sync completed', 'success')
    this.loadFiles() // Refresh file list
  }

  updateSyncButton() {
    if (this.hasSyncButtonTarget) {
      this.syncButtonTarget.disabled = this.syncInProgressValue
      this.syncButtonTarget.classList.toggle('loading', this.syncInProgressValue)
    }
    
    if (this.hasSyncStatusTarget) {
      this.syncStatusTarget.textContent = this.syncInProgressValue ? 'Syncing...' : 'Last synced: just now'
    }
  }

  // Pagination
  changePage(event) {
    event.preventDefault()
    const page = parseInt(event.target.dataset.page)
    if (page && page !== this.pageValue) {
      this.pageValue = page
      this.loadFiles()
    }
  }

  updatePagination(pagination) {
    if (this.hasPaginationTarget && pagination) {
      // Update pagination UI
      this.paginationTarget.innerHTML = this.renderPagination(pagination)
    }
  }

  renderPagination(pagination) {
    const { current_page, total_pages, prev_page, next_page } = pagination
    
    let html = '<div class="pagination">'
    
    if (prev_page) {
      html += `<button class="pagination__btn" data-action="click->cloud-file-browser#changePage" data-page="${prev_page}">Previous</button>`
    }
    
    html += `<span class="pagination__info">Page ${current_page} of ${total_pages}</span>`
    
    if (next_page) {
      html += `<button class="pagination__btn" data-action="click->cloud-file-browser#changePage" data-page="${next_page}">Next</button>`
    }
    
    html += '</div>'
    return html
  }

  // UI state management
  showLoading(show) {
    this.element.classList.toggle(this.loadingClass, show)
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.style.display = show ? 'block' : 'none'
    }
  }

  showError(message) {
    this.element.classList.add(this.errorClass)
    this.showNotification(message, 'error')
  }

  showEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.style.display = 'block'
    }
    if (this.hasFileListTarget) {
      this.fileListTarget.style.display = 'none'
    }
  }

  hideEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.style.display = 'none'
    }
    if (this.hasFileListTarget) {
      this.fileListTarget.style.display = 'block'
    }
  }

  showNotification(message, type = 'info') {
    // Dispatch notification event for global notification system
    this.dispatch('notification', {
      detail: { message, type }
    })
  }

  // Utility methods
  formatFileSize(bytes) {
    if (!bytes) return 'Unknown'
    
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`
  }

  formatDate(dateString) {
    if (!dateString) return 'Unknown'
    
    const date = new Date(dateString)
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
}