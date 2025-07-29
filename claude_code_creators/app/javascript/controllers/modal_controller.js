import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Close modal on escape key
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
    
    // Close modal on backdrop click
    this.element.addEventListener('click', (event) => {
      if (event.target === this.element) {
        this.close()
      }
    })
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  close() {
    // Remove the modal by clearing the turbo frame
    const modalFrame = document.getElementById('modal')
    if (modalFrame) {
      modalFrame.innerHTML = ''
    }
  }
}