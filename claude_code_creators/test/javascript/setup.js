// Jest setup for JavaScript testing
// Note: using global instead of import for jest-dom

// Make jest available globally for controller detection
global.jest = true;

// Override document.createElement to return fully mocked elements
const originalCreateElement = document.createElement.bind(document);
document.createElement = function(tagName) {
  const element = originalCreateElement(tagName);
  
  // Add default mock properties
  element._innerHTML = '';
  element._children = [];
  element._value = '';
  element._selectionStart = 0;
  element._selectionEnd = 0;
  element.style = element.style || {};
  element.classList = element.classList || {
    add: jest.fn(),
    remove: jest.fn(),
    contains: jest.fn(() => false)
  };
  element.setAttribute = element.setAttribute || jest.fn();
  element.getAttribute = element.getAttribute || jest.fn();
  element.addEventListener = element.addEventListener || jest.fn();
  element.removeEventListener = element.removeEventListener || jest.fn();
  element.dispatchEvent = element.dispatchEvent || jest.fn();
  
  // Mock focus/blur to set activeElement
  const originalFocus = element.focus || function() {};
  element.focus = function() {
    document.activeElement = this;
    originalFocus.call(this);
  };
  
  const originalBlur = element.blur || function() {};
  element.blur = function() {
    if (document.activeElement === this) {
      document.activeElement = null;
    }
    originalBlur.call(this);
  };
  
  return element;
};

// Mock Stimulus application
global.Application = {
  start: jest.fn(() => ({
    register: jest.fn(),
    getControllerForElementAndIdentifier: jest.fn((element, identifier) => ({
      // Mock controller properties and methods
      inputTarget: element.querySelector('[data-slash-commands-target="input"]'),
      suggestionsTarget: element.querySelector('[data-slash-commands-target="suggestions"]'),
      suggestionsList: element.querySelector('[data-slash-commands-target="suggestionsList"]'),
      statusTarget: element.querySelector('[data-slash-commands-target="status"]'),
      
      // Mock controller state
      currentCommand: null,
      commandPosition: null,
      commandParameters: [],
      selectedSuggestionIndex: -1,
      
      // Mock controller methods
      isValidCommand: jest.fn((command) => {
        const validCommands = ['save', 'load', 'compact', 'clear', 'include', 'snippet']
        return validCommands.includes(command)
      }),
      
      suggest_commands: jest.fn((filter) => {
        const allCommands = ['save', 'load', 'compact', 'clear', 'include', 'snippet']
        return allCommands.filter(cmd => cmd.startsWith(filter))
      }),
      
      suggest_commands_with_metadata: jest.fn((filter) => {
        const commands = [
          { command: 'save', description: 'Save document to various formats', category: 'context' },
          { command: 'load', description: 'Load external content', category: 'context' },
          { command: 'compact', description: 'Compress/optimize document', category: 'context' },
          { command: 'clear', description: 'Clear document sections', category: 'context' },
          { command: 'include', description: 'Include external files/content', category: 'content' },
          { command: 'snippet', description: 'Create reusable code snippets', category: 'content' }
        ]
        return commands.filter(cmd => cmd.command.startsWith(filter))
      }),
      
      getCursorPosition: jest.fn(() => ({ x: 100, y: 200 })),
      updateSuggestions: jest.fn(),
      selectSuggestion: jest.fn(),
      
      valid_parameters: jest.fn(() => true),
      validate_permissions: jest.fn(() => ({ allowed: true })),
      validate_document_access: jest.fn(() => ({ allowed: true })),
      build_execution_context: jest.fn(() => ({}))
    })),
    stop: jest.fn()
  }))
}

// Mock DOM methods and properties
Object.defineProperty(HTMLElement.prototype, 'setSelectionRange', {
  value: function(start, end) {
    this._selectionStart = start;
    this._selectionEnd = end;
  },
  writable: true
})

Object.defineProperty(HTMLElement.prototype, 'selectionStart', {
  get: function() { return this._selectionStart || 0; },
  set: function(value) { this._selectionStart = value; }
})

Object.defineProperty(HTMLElement.prototype, 'selectionEnd', {
  get: function() { return this._selectionEnd || 0; },
  set: function(value) { this._selectionEnd = value; }
})

Object.defineProperty(HTMLElement.prototype, 'value', {
  get: function() { return this._value || ''; },
  set: function(value) { this._value = value; }
})

Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
  get: function() { return 100; }
})

Object.defineProperty(HTMLElement.prototype, 'offsetHeight', {
  get: function() { return 20; }
})

Object.defineProperty(HTMLElement.prototype, 'getBoundingClientRect', {
  value: function() {
    return {
      left: 0,
      top: 0,
      width: 100,
      height: 20,
      x: 0,
      y: 0
    };
  }
})

// Mock querySelector for finding child elements
Object.defineProperty(HTMLElement.prototype, 'querySelector', {
  value: function(selector) {
    if (selector === 'ul') {
      // Return a mock ul element
      const ul = document.createElement('ul');
      ul._children = [];
      ul.innerHTML = '';
      return ul;
    }
    return null;
  }
})

// Mock children property for lists
Object.defineProperty(HTMLElement.prototype, 'children', {
  get: function() {
    return this._children || [];
  },
  set: function(value) {
    this._children = value;
  }
})

// Mock innerHTML to actually create child elements
const originalInnerHTMLSetter = Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML').set;
Object.defineProperty(HTMLElement.prototype, 'innerHTML', {
  get: function() {
    return this._innerHTML || '';
  },
  set: function(value) {
    this._innerHTML = value;
    // Parse simple HTML and create mock children
    if (value.includes('<li')) {
      const liMatches = value.match(/<li[^>]*>/g) || [];
      this._children = liMatches.map((match, index) => {
        const li = document.createElement('li');
        li.setAttribute = jest.fn();
        li.getAttribute = jest.fn();
        li.addEventListener = jest.fn();
        li.classList = {
          add: jest.fn(),
          remove: jest.fn(),
          contains: jest.fn(() => false)
        };
        li.textContent = `item-${index}`;
        return li;
      });
    }
  }
})

// Mock performance API
global.performance = {
  now: jest.fn(() => Date.now())
}

// Mock fetch responses for different scenarios
const mockFetchSuccess = (data) => Promise.resolve({
  ok: true,
  json: async () => data
})

const mockFetchError = (status, data) => Promise.resolve({
  ok: false,
  status: status,
  json: async () => data
})

// Default mock implementations
global.fetch = jest.fn()

// Helper to setup common mock scenarios
global.setupMockFetch = {
  success: (commandData = {}) => {
    global.fetch.mockResolvedValue(mockFetchSuccess({
      status: 'success',
      command: 'save',
      result: { context_name: 'test' },
      execution_time: 0.05,
      timestamp: new Date().toISOString(),
      ...commandData
    }))
  },
  
  error: (errorMessage = 'Command failed', status = 400) => {
    global.fetch.mockResolvedValue(mockFetchError(status, {
      status: 'error',
      error: errorMessage,
      timestamp: new Date().toISOString()
    }))
  },
  
  networkError: () => {
    global.fetch.mockRejectedValue(new Error('Network error'))
  },
  
  timeout: () => {
    global.fetch.mockImplementation(() => 
      new Promise((resolve, reject) => {
        setTimeout(() => reject(new Error('Timeout')), 100)
      })
    )
  }
}

// Mock document.activeElement
Object.defineProperty(document, 'activeElement', {
  get: function() {
    return this._activeElement || null;
  },
  set: function(element) {
    this._activeElement = element;
  }
})

// Mock window methods
Object.defineProperty(window, 'innerWidth', {
  writable: true,
  configurable: true,
  value: 1024
})

Object.defineProperty(window, 'innerHeight', {
  writable: true,
  configurable: true,
  value: 768
})

// Mock Stimulus event system
global.dispatch = jest.fn()

// Helper functions for tests
global.createMockEditor = () => {
  const element = document.createElement('div')
  element.innerHTML = `
    <textarea data-slash-commands-target="input" class="editor-input"></textarea>
    <div data-slash-commands-target="suggestions" class="suggestions-dropdown" style="display: none;">
      <ul></ul>
    </div>
    <div data-slash-commands-target="status" class="command-status"></div>
  `
  return element
}

global.simulateKeyEvent = (element, key, options = {}) => {
  const event = new KeyboardEvent('keydown', {
    key: key,
    code: `Key${key.toUpperCase()}`,
    bubbles: true,
    ...options
  })
  
  // Add preventDefault mock
  event.preventDefault = jest.fn()
  
  element.dispatchEvent(event)
  return event
}

global.simulateInputEvent = (element, value) => {
  element.value = value
  const event = new Event('input', { bubbles: true })
  element.dispatchEvent(event)
  return event
}

// Cleanup after each test
afterEach(() => {
  jest.clearAllMocks()
  document.body.innerHTML = ''
})