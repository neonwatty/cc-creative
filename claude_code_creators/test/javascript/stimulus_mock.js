// Mock Stimulus Controller class for testing
export class Controller {
  constructor() {
    this.element = null;
    this.targets = new Proxy({}, {
      get(target, prop) {
        if (prop.endsWith('Target')) {
          const targetName = prop.replace('Target', '');
          return document.querySelector(`[data-slash-commands-target="${targetName}"]`);
        }
        return target[prop];
      }
    });
  }

  connect() {}
  disconnect() {}
  
  dispatch(eventName, options = {}) {
    const event = new CustomEvent(eventName, options);
    if (this.element) {
      this.element.dispatchEvent(event);
    }
  }
}

export class Application {
  static start() {
    return new Application();
  }
  
  register(name, controllerClass) {
    this._controllers = this._controllers || {};
    this._controllers[name] = controllerClass;
  }
  
  getControllerForElementAndIdentifier(element, identifier) {
    const Controller = this._controllers[identifier];
    if (!Controller) return null;
    
    const controller = new Controller();
    controller.element = element;
    
    // Set up targets manually for slash-commands controller
    if (identifier === 'slash-commands') {
      controller.inputTarget = element.querySelector('[data-slash-commands-target="input"]');
      controller.suggestionsTarget = element.querySelector('[data-slash-commands-target="suggestions"]');
      controller.statusTarget = element.querySelector('[data-slash-commands-target="status"]');
      
      // Ensure targets exist, create mocks if not found
      if (!controller.inputTarget) {
        controller.inputTarget = document.createElement('textarea');
      }
      if (!controller.suggestionsTarget) {
        controller.suggestionsTarget = document.createElement('div');
        controller.suggestionsTarget.style = { display: 'none' };
      }
      if (!controller.statusTarget) {
        controller.statusTarget = document.createElement('div');
      }
      
      // Set up values
      const documentIdValue = element.getAttribute('data-slash-commands-document-id-value');
      if (documentIdValue !== null) {
        controller.documentIdValue = parseInt(documentIdValue);
      }
      
      // Call connect method if it exists
      if (typeof controller.connect === 'function') {
        controller.connect();
      }
    } else {
      // Set up targets for other controllers
      Object.keys(Controller.targets || []).forEach(targetName => {
        const targetElement = element.querySelector(`[data-${identifier}-target="${targetName}"]`);
        controller[`${targetName}Target`] = targetElement;
      });
      
      // Set up values
      Object.keys(Controller.values || {}).forEach(valueName => {
        const valueAttr = element.getAttribute(`data-${identifier}-${valueName.toLowerCase()}-value`);
        if (valueAttr !== null) {
          controller[`${valueName}Value`] = Controller.values[valueName] === Number ? parseInt(valueAttr) : valueAttr;
        }
      });
    }
    
    return controller;
  }
  
  stop() {}
}