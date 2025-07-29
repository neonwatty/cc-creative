import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  insert(event) {
    const contextItemId = event.target.dataset.contextItemId
    
    // Dispatch the insert event
    const insertEvent = new CustomEvent('context-item:insert', {
      detail: { contextItemId: contextItemId },
      bubbles: true
    })
    document.dispatchEvent(insertEvent)
    
    // Close the modal
    const modalController = this.application.getControllerForElementAndIdentifier(
      this.element.closest('[data-controller~="modal"]'),
      'modal'
    )
    if (modalController) {
      modalController.close()
    }
  }
}