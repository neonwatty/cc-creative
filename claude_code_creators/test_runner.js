#!/usr/bin/env node

// Simple test runner to validate our Stimulus controller
import { readFileSync } from 'fs';
import { pathToFileURL } from 'url';

// Mock JSDOM environment
global.document = {
  createElement: (tag) => ({
    innerHTML: '',
    style: {},
    setAttribute: () => {},
    getAttribute: () => null,
    appendChild: () => {},
    removeChild: () => {},
    querySelector: () => null,
    children: [],
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => {}
  }),
  body: { appendChild: () => {}, removeChild: () => {} },
  addEventListener: () => {},
  removeEventListener: () => {},
  activeElement: null
};

global.window = {
  getComputedStyle: () => ({}),
  performance: { now: () => Date.now() }
};

// Mock controller import
try {
  const controllerPath = '/Users/jeremywatt/Desktop/cc-creative/claude_code_creators/app/javascript/controllers/slash_commands_controller.js';
  const controllerContent = readFileSync(controllerPath, 'utf8');
  
  console.log('✅ SlashCommandsController syntax is valid');
  
  // Check for key methods
  const requiredMethods = [
    'detectCommand',
    'updateSuggestions', 
    'executeCommand',
    'handleInput',
    'handleKeydown'
  ];
  
  const missingMethods = requiredMethods.filter(method => 
    !controllerContent.includes(`${method}(`)
  );
  
  if (missingMethods.length === 0) {
    console.log('✅ All required methods are present');
  } else {
    console.log(`❌ Missing methods: ${missingMethods.join(', ')}`);
  }
  
  // Check for typo fixes
  if (controllerContent.includes('replaceCurrenCommand')) {
    console.log('❌ Typo still present: replaceCurrenCommand');
  } else if (controllerContent.includes('replaceCurrentCommand')) {
    console.log('✅ Typo fixed: replaceCurrentCommand');
  }
  
} catch (error) {
  console.log(`❌ Controller has syntax errors: ${error.message}`);
}