import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list", "item", "dropzone"]
  static values = { 
    reorderUrl: String,
    documentId: Number,
    editorSelector: String 
  }
  
  connect() {
    console.log('DragDropController connected')
    this.initializeSortable()
    this.initializeDraggableItems()
  }
  
  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }
  
  initializeSortable() {
    if (!this.hasListTarget) return
    
    this.sortable = new Sortable(this.listTarget, {
      group: {
        name: 'context-items',
        pull: 'clone',
        put: false
      },
      sort: true,
      animation: 150,
      handle: '.drag-handle',
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      onEnd: (evt) => {
        if (evt.from === evt.to) {
          // Items were reordered within the list
          this.handleReorder(evt)
        }
      }
    })
  }
  
  initializeDraggableItems() {
    // Add drag handles to items if they don't exist
    this.itemTargets.forEach(item => {
      if (!item.querySelector('.drag-handle')) {
        const handle = document.createElement('div')
        handle.className = 'drag-handle absolute left-0 top-0 bottom-0 w-8 flex items-center justify-center cursor-move opacity-0 group-hover:opacity-100 transition-opacity'
        handle.innerHTML = `
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"></path>
          </svg>
        `
        item.style.position = 'relative'
        item.appendChild(handle)
      }
      
      // Make items draggable for drop into editor
      item.setAttribute('draggable', 'true')
      item.addEventListener('dragstart', this.handleDragStart.bind(this))
      item.addEventListener('dragend', this.handleDragEnd.bind(this))
    })
  }
  
  handleDragStart(event) {
    const item = event.currentTarget
    const contextItem = {
      id: item.dataset.contextItemId,
      title: item.querySelector('[data-item-title]')?.textContent.trim(),
      content: item.querySelector('[data-item-content]')?.textContent.trim(),
      fullContent: item.dataset.contextItemContent
    }
    
    // Store the dragged item data
    event.dataTransfer.effectAllowed = 'copy'
    event.dataTransfer.setData('text/plain', contextItem.fullContent || contextItem.content)
    event.dataTransfer.setData('application/json', JSON.stringify(contextItem))
    
    // Add visual feedback
    item.classList.add('opacity-50')
    document.body.classList.add('dragging-context-item')
    
    // Highlight drop zones
    this.highlightDropZones()
  }
  
  handleDragEnd(event) {
    const item = event.currentTarget
    item.classList.remove('opacity-50')
    document.body.classList.remove('dragging-context-item')
    
    // Remove drop zone highlights
    this.removeDropZoneHighlights()
  }
  
  handleReorder(evt) {
    const itemIds = Array.from(this.listTarget.querySelectorAll('[data-context-item-id]'))
      .map(item => item.dataset.contextItemId)
    
    // Send reorder request to server
    fetch(this.reorderUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ item_ids: itemIds })
    })
    .then(response => {
      if (!response.ok) {
        // Revert the order if the request failed
        this.sortable.sort(evt.oldIndicies)
      }
    })
    .catch(error => {
      console.error('Failed to reorder items:', error)
      // Revert the order
      this.sortable.sort(evt.oldIndicies)
    })
  }
  
  highlightDropZones() {
    // Find the Trix editor
    const editor = document.querySelector(this.editorSelectorValue || 'trix-editor')
    if (editor) {
      editor.classList.add('drop-zone-active')
      
      // Set up drop event listeners
      editor.addEventListener('dragover', this.handleDragOver)
      editor.addEventListener('drop', this.handleDrop.bind(this))
      editor.addEventListener('dragleave', this.handleDragLeave)
    }
  }
  
  removeDropZoneHighlights() {
    const editor = document.querySelector(this.editorSelectorValue || 'trix-editor')
    if (editor) {
      editor.classList.remove('drop-zone-active', 'drop-zone-hover')
      
      // Remove drop event listeners
      editor.removeEventListener('dragover', this.handleDragOver)
      editor.removeEventListener('drop', this.handleDrop)
      editor.removeEventListener('dragleave', this.handleDragLeave)
    }
  }
  
  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    event.currentTarget.classList.add('drop-zone-hover')
  }
  
  handleDragLeave(event) {
    event.currentTarget.classList.remove('drop-zone-hover')
  }
  
  handleDrop(event) {
    event.preventDefault()
    const editor = event.currentTarget
    editor.classList.remove('drop-zone-hover')
    
    try {
      // Get the dropped data
      const contextItemData = event.dataTransfer.getData('application/json')
      const contextItem = JSON.parse(contextItemData)
      
      // Insert content into Trix editor
      if (editor.editor) {
        const content = contextItem.fullContent || contextItem.content
        
        // Create a formatted insertion with title
        const insertion = `<h3>${contextItem.title}</h3><p>${content}</p><hr>`
        
        // Insert at current cursor position
        editor.editor.insertHTML(insertion)
        
        // Show success feedback
        this.showDropFeedback(event.clientX, event.clientY, 'Inserted successfully!')
      }
    } catch (error) {
      console.error('Failed to insert content:', error)
      this.showDropFeedback(event.clientX, event.clientY, 'Failed to insert', true)
    }
  }
  
  showDropFeedback(x, y, message, isError = false) {
    const feedback = document.createElement('div')
    feedback.className = `fixed z-50 px-4 py-2 rounded-lg text-white text-sm font-medium transition-all duration-300 ${
      isError ? 'bg-red-500' : 'bg-green-500'
    }`
    feedback.style.left = `${x}px`
    feedback.style.top = `${y}px`
    feedback.textContent = message
    
    document.body.appendChild(feedback)
    
    // Animate and remove
    setTimeout(() => {
      feedback.style.transform = 'translateY(-20px)'
      feedback.style.opacity = '0'
    }, 100)
    
    setTimeout(() => {
      feedback.remove()
    }, 1500)
  }
}