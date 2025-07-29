import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "snippetList", "draftList", "versionList"]

  connect() {
    this.setupDragAndDrop()
  }

  setupDragAndDrop() {
    const contextItems = this.element.querySelectorAll('.context-item[draggable="true"]')
    
    contextItems.forEach(item => {
      item.addEventListener('dragstart', this.handleDragStart.bind(this))
      item.addEventListener('dragend', this.handleDragEnd.bind(this))
    })

    // Set up drop zones if needed
    const lists = [this.snippetListTarget, this.draftListTarget]
    lists.forEach(list => {
      if (list) {
        list.addEventListener('dragover', this.handleDragOver.bind(this))
        list.addEventListener('drop', this.handleDrop.bind(this))
      }
    })
  }

  handleDragStart(event) {
    event.dataTransfer.effectAllowed = 'copy'
    event.dataTransfer.setData('contextItemId', event.target.dataset.contextItemId)
    event.dataTransfer.setData('contextItemType', event.target.dataset.contextItemType)
    event.target.classList.add('opacity-50')
  }

  handleDragEnd(event) {
    event.target.classList.remove('opacity-50')
  }

  handleDragOver(event) {
    if (event.preventDefault) {
      event.preventDefault()
    }
    event.dataTransfer.dropEffect = 'copy'
    return false
  }

  handleDrop(event) {
    if (event.stopPropagation) {
      event.stopPropagation()
    }
    
    const contextItemId = event.dataTransfer.getData('contextItemId')
    // Handle the drop - could be reordering or inserting into document
    
    return false
  }

  search(event) {
    const searchTerm = event.target.value.toLowerCase()
    const allItems = this.element.querySelectorAll('.context-item')
    
    allItems.forEach(item => {
      const title = item.querySelector('h4').textContent.toLowerCase()
      const content = item.querySelector('p').textContent.toLowerCase()
      
      if (title.includes(searchTerm) || content.includes(searchTerm)) {
        item.style.display = 'block'
      } else {
        item.style.display = 'none'
      }
    })
  }

  insertItem(event) {
    event.preventDefault()
    const contextItemId = event.target.dataset.contextItemId
    
    // Dispatch a custom event that the editor can listen to
    const insertEvent = new CustomEvent('context-item:insert', {
      detail: { contextItemId: contextItemId },
      bubbles: true
    })
    this.element.dispatchEvent(insertEvent)
  }

  restoreVersion(event) {
    event.preventDefault()
    const versionId = event.target.dataset.versionId
    
    if (confirm('Are you sure you want to restore this version? This will replace the current document content.')) {
      // Make an AJAX call to restore the version
      fetch(`/documents/${this.getDocumentId()}/context_items/${versionId}/restore`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          // Reload the page to show restored content
          window.location.reload()
        } else {
          alert('Failed to restore version: ' + (data.error || 'Unknown error'))
        }
      })
      .catch(error => {
        console.error('Error restoring version:', error)
        alert('Failed to restore version')
      })
    }
  }

  compareVersion(event) {
    event.preventDefault()
    const versionId = event.target.dataset.versionId
    
    // Open a modal or side-by-side comparison view
    const compareEvent = new CustomEvent('context-item:compare', {
      detail: { versionId: versionId },
      bubbles: true
    })
    this.element.dispatchEvent(compareEvent)
  }

  getDocumentId() {
    // Extract document ID from the URL or a data attribute
    const match = window.location.pathname.match(/documents\/(\d+)/)
    return match ? match[1] : null
  }
}