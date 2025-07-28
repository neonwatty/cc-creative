import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cloud-file-uploader"
export default class extends Controller {
  static targets = [
    "dropZone",
    "fileInput", 
    "uploadButton",
    "progressContainer",
    "progressBar",
    "progressText",
    "fileList",
    "status",
    "errorContainer"
  ]

  static values = {
    integrationId: String,
    uploadUrl: String,
    maxFileSize: { type: Number, default: 50 * 1024 * 1024 }, // 50MB default
    allowedTypes: { type: Array, default: [] },
    multiple: { type: Boolean, default: true },
    autoUpload: { type: Boolean, default: false }
  }

  static classes = [
    "dragOver",
    "uploading", 
    "success",
    "error",
    "complete"
  ]

  connect() {
    this.uploads = new Map() // Track individual uploads
    this.setupDragAndDrop()
    this.initializeFileInput()
  }

  disconnect() {
    // Cancel any ongoing uploads
    this.uploads.forEach(upload => {
      if (upload.xhr && upload.xhr.readyState !== XMLHttpRequest.DONE) {
        upload.xhr.abort()
      }
    })
  }

  // Setup drag and drop functionality
  setupDragAndDrop() {
    if (!this.hasDropZoneTarget) return

    const dropZone = this.dropZoneTarget

    // Prevent default drag behaviors
    ;['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.preventDefaults.bind(this), false)
      document.body.addEventListener(eventName, this.preventDefaults.bind(this), false)
    })

    // Highlight drop zone when item is dragged over
    ;['dragenter', 'dragover'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.highlight.bind(this), false)
    })

    ;['dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, this.unhighlight.bind(this), false)
    })

    // Handle dropped files
    dropZone.addEventListener('drop', this.handleDrop.bind(this), false)
  }

  // Initialize file input
  initializeFileInput() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.multiple = this.multipleValue
      if (this.allowedTypesValue.length > 0) {
        this.fileInputTarget.accept = this.allowedTypesValue.join(',')
      }
    }
  }

  // Drag and drop event handlers
  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight(e) {
    this.dropZoneTarget.classList.add(this.dragOverClass)
  }

  unhighlight(e) {
    this.dropZoneTarget.classList.remove(this.dragOverClass)
  }

  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    this.handleFiles(files)
  }

  // File input change handler
  handleFileSelect(event) {
    const files = event.target.files
    this.handleFiles(files)
  }

  // Process selected files
  handleFiles(fileList) {
    const files = Array.from(fileList)
    
    // Validate files
    const validFiles = files.filter(file => this.validateFile(file))
    
    if (validFiles.length === 0) {
      this.showError('No valid files selected')
      return
    }

    // Add files to upload queue
    validFiles.forEach(file => this.addFileToQueue(file))

    // Auto upload if enabled
    if (this.autoUploadValue) {
      this.startUploads()
    }
  }

  // Validate individual file
  validateFile(file) {
    // Check file size
    if (file.size > this.maxFileSizeValue) {
      this.showError(`File "${file.name}" is too large. Maximum size is ${this.formatFileSize(this.maxFileSizeValue)}.`)
      return false
    }

    // Check file type if restrictions exist
    if (this.allowedTypesValue.length > 0) {
      const isAllowed = this.allowedTypesValue.some(type => {
        if (type.startsWith('.')) {
          return file.name.toLowerCase().endsWith(type.toLowerCase())
        } else {
          return file.type.includes(type)
        }
      })

      if (!isAllowed) {
        this.showError(`File type "${file.type}" is not allowed for "${file.name}".`)
        return false
      }
    }

    return true
  }

  // Add file to upload queue
  addFileToQueue(file) {
    const fileId = this.generateFileId()
    const uploadInfo = {
      id: fileId,
      file: file,
      status: 'queued',
      progress: 0,
      xhr: null
    }

    this.uploads.set(fileId, uploadInfo)
    this.renderFileItem(uploadInfo)
  }

  // Render file item in the list
  renderFileItem(uploadInfo) {
    if (!this.hasFileListTarget) return

    const fileItem = document.createElement('div')
    fileItem.className = 'upload-item'
    fileItem.dataset.fileId = uploadInfo.id
    
    fileItem.innerHTML = `
      <div class="upload-item__info">
        <div class="upload-item__name">${uploadInfo.file.name}</div>
        <div class="upload-item__meta">${this.formatFileSize(uploadInfo.file.size)}</div>
      </div>
      <div class="upload-item__progress">
        <div class="progress-bar">
          <div class="progress-bar__fill" style="width: 0%"></div>
        </div>
        <div class="upload-item__status">${uploadInfo.status}</div>
      </div>
      <div class="upload-item__actions">
        <button class="btn btn--sm btn--secondary" data-action="click->cloud-file-uploader#removeFile" data-file-id="${uploadInfo.id}">Remove</button>
      </div>
    `

    this.fileListTarget.appendChild(fileItem)
  }

  // Start all queued uploads
  startUploads() {
    const queuedUploads = Array.from(this.uploads.values()).filter(upload => upload.status === 'queued')
    
    if (queuedUploads.length === 0) {
      this.showError('No files queued for upload')
      return
    }

    this.element.classList.add(this.uploadingClass)
    this.disableControls(true)

    // Start uploads (could be done in parallel or sequentially)
    queuedUploads.forEach(upload => {
      this.uploadFile(upload)
    })
  }

  // Upload individual file
  async uploadFile(uploadInfo) {
    const formData = new FormData()
    formData.append('file', uploadInfo.file)
    formData.append('integration_id', this.integrationIdValue)

    const xhr = new XMLHttpRequest()
    uploadInfo.xhr = xhr

    // Update upload status
    this.updateUploadStatus(uploadInfo.id, 'uploading')

    // Track progress
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) {
        const percentComplete = (e.loaded / e.total) * 100
        this.updateUploadProgress(uploadInfo.id, percentComplete)
      }
    })

    // Handle completion
    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const response = JSON.parse(xhr.responseText)
          this.handleUploadSuccess(uploadInfo.id, response)
        } catch (error) {
          this.handleUploadError(uploadInfo.id, 'Invalid response from server')
        }
      } else {
        this.handleUploadError(uploadInfo.id, `HTTP ${xhr.status}: ${xhr.statusText}`)
      }
    })

    // Handle errors
    xhr.addEventListener('error', () => {
      this.handleUploadError(uploadInfo.id, 'Network error occurred')
    })

    xhr.addEventListener('abort', () => {
      this.handleUploadError(uploadInfo.id, 'Upload cancelled')
    })

    // Start upload
    xhr.open('POST', this.uploadUrlValue || `/cloud_integrations/${this.integrationIdValue}/upload`)
    xhr.setRequestHeader('X-CSRF-Token', document.querySelector('[name="csrf-token"]').content)
    xhr.send(formData)
  }

  // Update upload progress
  updateUploadProgress(fileId, progress) {
    const upload = this.uploads.get(fileId)
    if (!upload) return

    upload.progress = progress

    const fileItem = this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
    if (fileItem) {
      const progressBar = fileItem.querySelector('.progress-bar__fill')
      const statusText = fileItem.querySelector('.upload-item__status')
      
      if (progressBar) {
        progressBar.style.width = `${progress}%`
      }
      
      if (statusText) {
        statusText.textContent = `${Math.round(progress)}%`
      }
    }

    // Update overall progress
    this.updateOverallProgress()
  }

  // Update upload status
  updateUploadStatus(fileId, status) {
    const upload = this.uploads.get(fileId)
    if (!upload) return

    upload.status = status

    const fileItem = this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
    if (fileItem) {
      fileItem.className = `upload-item upload-item--${status}`
      const statusText = fileItem.querySelector('.upload-item__status')
      if (statusText) {
        statusText.textContent = status
      }
    }
  }

  // Handle successful upload
  handleUploadSuccess(fileId, response) {
    this.updateUploadStatus(fileId, 'completed')
    this.updateUploadProgress(fileId, 100)

    // Dispatch success event
    this.dispatch('upload:success', {
      detail: {
        fileId: fileId,
        response: response
      }
    })

    this.checkAllUploadsComplete()
  }

  // Handle upload error
  handleUploadError(fileId, error) {
    this.updateUploadStatus(fileId, 'error')
    
    const upload = this.uploads.get(fileId)
    if (upload) {
      upload.error = error
    }

    // Show error in file item
    const fileItem = this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
    if (fileItem) {
      const statusText = fileItem.querySelector('.upload-item__status')
      if (statusText) {
        statusText.textContent = `Error: ${error}`
      }
    }

    // Dispatch error event
    this.dispatch('upload:error', {
      detail: {
        fileId: fileId,
        error: error
      }
    })

    this.checkAllUploadsComplete()
  }

  // Check if all uploads are complete
  checkAllUploadsComplete() {
    const uploads = Array.from(this.uploads.values())
    const activeUploads = uploads.filter(upload => 
      upload.status === 'uploading' || upload.status === 'queued'
    )

    if (activeUploads.length === 0) {
      this.element.classList.remove(this.uploadingClass)
      this.element.classList.add(this.completeClass)
      this.disableControls(false)

      // Show completion status
      const completedCount = uploads.filter(upload => upload.status === 'completed').length
      const errorCount = uploads.filter(upload => upload.status === 'error').length
      
      this.showStatus(`Upload complete: ${completedCount} successful, ${errorCount} errors`)

      // Dispatch completion event
      this.dispatch('upload:complete', {
        detail: {
          completed: completedCount,
          errors: errorCount,
          total: uploads.length
        }
      })
    }
  }

  // Update overall progress bar
  updateOverallProgress() {
    if (!this.hasProgressBarTarget) return

    const uploads = Array.from(this.uploads.values())
    const totalProgress = uploads.reduce((sum, upload) => sum + upload.progress, 0)
    const averageProgress = uploads.length > 0 ? totalProgress / uploads.length : 0

    this.progressBarTarget.style.width = `${averageProgress}%`
    
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${Math.round(averageProgress)}%`
    }
  }

  // Remove file from queue
  removeFile(event) {
    const fileId = event.target.dataset.fileId
    const upload = this.uploads.get(fileId)
    
    if (!upload) return

    // Cancel upload if in progress
    if (upload.xhr && upload.xhr.readyState !== XMLHttpRequest.DONE) {
      upload.xhr.abort()
    }

    // Remove from uploads map
    this.uploads.delete(fileId)

    // Remove from DOM
    const fileItem = this.fileListTarget.querySelector(`[data-file-id="${fileId}"]`)
    if (fileItem) {
      fileItem.remove()
    }

    this.updateOverallProgress()
  }

  // Clear all files
  clearAll() {
    // Cancel all uploads
    this.uploads.forEach(upload => {
      if (upload.xhr && upload.xhr.readyState !== XMLHttpRequest.DONE) {
        upload.xhr.abort()
      }
    })

    // Clear uploads map
    this.uploads.clear()

    // Clear DOM
    if (this.hasFileListTarget) {
      this.fileListTarget.innerHTML = ''
    }

    // Reset UI state
    this.element.classList.remove(this.uploadingClass, this.completeClass, this.errorClass)
    this.disableControls(false)
    this.clearStatus()
  }

  // Retry failed uploads
  retryFailed() {
    const failedUploads = Array.from(this.uploads.values()).filter(upload => upload.status === 'error')
    
    failedUploads.forEach(upload => {
      upload.status = 'queued'
      upload.progress = 0
      upload.xhr = null
      delete upload.error
      this.updateUploadStatus(upload.id, 'queued')
      this.updateUploadProgress(upload.id, 0)
    })

    if (failedUploads.length > 0) {
      this.startUploads()
    }
  }

  // UI helper methods
  disableControls(disabled) {
    if (this.hasUploadButtonTarget) {
      this.uploadButtonTarget.disabled = disabled
    }
    
    if (this.hasFileInputTarget) {
      this.fileInputTarget.disabled = disabled
    }
  }

  showStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.style.display = 'block'
    }
  }

  clearStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ''
      this.statusTarget.style.display = 'none'
    }
  }

  showError(message) {
    this.element.classList.add(this.errorClass)
    
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.textContent = message
      this.errorContainerTarget.style.display = 'block'
      
      // Auto-hide after 5 seconds
      setTimeout(() => {
        this.errorContainerTarget.style.display = 'none'
        this.element.classList.remove(this.errorClass)
      }, 5000)
    }
  }

  // Utility methods
  generateFileId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2)
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  // Public API methods for external control
  upload() {
    this.startUploads()
  }

  cancel() {
    this.clearAll()
  }

  addFiles(files) {
    this.handleFiles(files)
  }
}