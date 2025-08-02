# Commands and Customization Tasks

This document outlines the slash commands, custom tools, and review functionality for the Claude Code Creators Rails application.

## ⏳ Task 7: Implement Context Control Commands
**Status:** pending  
**Priority:** medium  
**Dependencies:** Tasks 2, 3

### Todo List:
- [ ] Create CommandParserService:
  - [ ] Define COMMANDS constant array
  - [ ] Create initialize method with document and user
  - [ ] Set up ClaudeService integration
  - [ ] Implement process_command method
  - [ ] Add command validation
  - [ ] Create error handling
  - [ ] Return structured responses

- [ ] Implement /compact command:
  - [ ] Create process_compact method
  - [ ] Integrate with Claude SDK
  - [ ] Compress conversation context
  - [ ] Preserve important information
  - [ ] Update UI to show compaction
  - [ ] Return success confirmation

- [ ] Implement /clear command:
  - [ ] Create process_clear method
  - [ ] Clear conversation history
  - [ ] Reset Claude context
  - [ ] Preserve document content
  - [ ] Update UI state
  - [ ] Show clear confirmation

- [ ] Implement /include command:
  - [ ] Create process_include method
  - [ ] Parse file/content references
  - [ ] Load specified content
  - [ ] Add to Claude context
  - [ ] Handle multiple includes
  - [ ] Show included items

- [ ] Implement /snippet command:
  - [ ] Create process_snippet method
  - [ ] Extract selected content
  - [ ] Save as context item
  - [ ] Generate snippet metadata
  - [ ] Add to sidebar
  - [ ] Return snippet ID

- [ ] Create slash_commands_controller.js:
  - [ ] Set up Stimulus controller
  - [ ] Add keydown event listener
  - [ ] Detect slash at line start
  - [ ] Show command suggestions
  - [ ] Handle command selection
  - [ ] Execute commands via AJAX

- [ ] Implement command detection:
  - [ ] Monitor editor input
  - [ ] Detect slash character
  - [ ] Check for valid position
  - [ ] Extract command text
  - [ ] Parse command arguments
  - [ ] Validate command syntax

- [ ] Create command execution endpoints:
  - [ ] Add routes for commands
  - [ ] Create controller actions
  - [ ] Process command requests
  - [ ] Call CommandParserService
  - [ ] Return JSON responses
  - [ ] Handle errors gracefully

- [ ] Create UI for command suggestions:
  - [ ] Design suggestion dropdown
  - [ ] Show available commands
  - [ ] Display command descriptions
  - [ ] Add keyboard navigation
  - [ ] Highlight active selection
  - [ ] Auto-complete commands

- [ ] Add visual feedback:
  - [ ] Show command processing
  - [ ] Display success messages
  - [ ] Show error notifications
  - [ ] Update context indicators
  - [ ] Animate UI changes
  - [ ] Add loading states

- [ ] Create command history:
  - [ ] Track executed commands
  - [ ] Store command results
  - [ ] Enable command replay
  - [ ] Show recent commands
  - [ ] Add command search
  - [ ] Export command log

### Test Checklist:
- [ ] Test command parsing and detection
- [ ] Verify each command functions correctly
- [ ] Test command suggestion UI
- [ ] Verify visual feedback for command execution
- [ ] Test error handling for invalid commands
- [ ] Ensure commands interact correctly with Claude SDK

---

## ⏳ Task 8: Implement Custom Tools & Widgets
**Status:** pending  
**Priority:** medium  
**Dependencies:** Tasks 2, 3, 7

### Todo List:
- [ ] Create CustomTool model:
  - [ ] Generate model with fields
  - [ ] Add name validation
  - [ ] Validate command format (alphanumeric + hyphens)
  - [ ] Validate prompt_template presence
  - [ ] Add user association
  - [ ] Create tool categories
  - [ ] Add usage tracking

- [ ] Implement tool wizard UI:
  - [ ] Create multi-step wizard
  - [ ] Design step navigation
  - [ ] Add form validation
  - [ ] Create preview functionality
  - [ ] Implement save/draft options
  - [ ] Add wizard completion

- [ ] Create tool_wizard_controller.js:
  - [ ] Implement step navigation
  - [ ] Add form validation
  - [ ] Handle step transitions
  - [ ] Save progress locally
  - [ ] Submit tool creation
  - [ ] Show success message

- [ ] Create widget components:
  - [ ] Design base widget class
  - [ ] Implement common functionality
  - [ ] Add resize capabilities
  - [ ] Create minimize/maximize
  - [ ] Add close functionality
  - [ ] Implement state persistence

- [ ] Implement OutlineWidgetComponent:
  - [ ] Create component structure
  - [ ] Design outline UI
  - [ ] Add section management
  - [ ] Implement drag to reorder
  - [ ] Add expand/collapse
  - [ ] Sync with document

- [ ] Implement ResearchWidgetComponent:
  - [ ] Create research UI
  - [ ] Add source management
  - [ ] Implement note-taking
  - [ ] Create citation tools
  - [ ] Add search functionality
  - [ ] Export research data

- [ ] Implement WorldBuildingWidgetComponent:
  - [ ] Design world-building UI
  - [ ] Create entity management
  - [ ] Add relationship mapping
  - [ ] Implement timeline features
  - [ ] Create location tracker
  - [ ] Add character sheets

- [ ] Implement drag-and-dock:
  - [ ] Create docking zones
  - [ ] Implement drag detection
  - [ ] Add dock preview
  - [ ] Handle dock/undock events
  - [ ] Save dock positions
  - [ ] Restore layout on load

- [ ] Create widget data controllers:
  - [ ] Implement data persistence
  - [ ] Add auto-save functionality
  - [ ] Create data export
  - [ ] Handle data updates
  - [ ] Implement undo/redo
  - [ ] Add version tracking

- [ ] Implement widget state persistence:
  - [ ] Save widget positions
  - [ ] Store widget sizes
  - [ ] Persist widget data
  - [ ] Save open/closed state
  - [ ] Restore on page load
  - [ ] Sync across sessions

- [ ] Add Claude SDK integration:
  - [ ] Connect widgets to Claude
  - [ ] Send widget context
  - [ ] Receive AI suggestions
  - [ ] Update widget content
  - [ ] Handle AI errors
  - [ ] Add AI indicators

- [ ] Create standard tool library:
  - [ ] Develop common tools
  - [ ] Create tool templates
  - [ ] Add tool categories
  - [ ] Implement tool search
  - [ ] Enable tool sharing
  - [ ] Add ratings/reviews

- [ ] Implement custom tool execution:
  - [ ] Parse tool commands
  - [ ] Load tool configuration
  - [ ] Execute prompt template
  - [ ] Process with Claude SDK
  - [ ] Return formatted results
  - [ ] Handle execution errors

### Test Checklist:
- [ ] Test custom tool creation and validation
- [ ] Verify tool wizard UI functionality
- [ ] Test widget rendering and interaction
- [ ] Verify drag-and-dock functionality
- [ ] Test widget state persistence
- [ ] Ensure widgets interact correctly with Claude SDK
- [ ] Test custom tool execution

---

## ⏳ Task 16: Implement Custom Review Slash Commands
**Status:** pending  
**Priority:** medium  
**Dependencies:** Tasks 7, 8

### Todo List:
- [ ] Extend CommandParserService for review commands:
  - [ ] Add REVIEW_COMMANDS array
  - [ ] Create process_review_command method
  - [ ] Implement command routing
  - [ ] Handle review arguments
  - [ ] Return review results
  - [ ] Add error handling

- [ ] Implement /review_for_clarity:
  - [ ] Create review_for_clarity method
  - [ ] Design clarity review prompt
  - [ ] Identify unclear passages
  - [ ] Suggest improvements
  - [ ] Highlight problem areas
  - [ ] Return structured feedback

- [ ] Implement /review_for_brand_alignment:
  - [ ] Create review_for_brand_alignment method
  - [ ] Load brand guidelines
  - [ ] Check voice consistency
  - [ ] Verify tone alignment
  - [ ] Check terminology usage
  - [ ] Flag deviations
  - [ ] Suggest corrections

- [ ] Implement /review_for_proof:
  - [ ] Create review_for_proof method
  - [ ] Examine claims and data
  - [ ] Verify hyperlinks
  - [ ] Check factual accuracy
  - [ ] Identify missing evidence
  - [ ] Suggest sources
  - [ ] Flag unsubstantiated claims

- [ ] Implement /review_for_concision:
  - [ ] Create review_for_concision method
  - [ ] Identify verbose passages
  - [ ] Suggest shorter alternatives
  - [ ] Calculate reduction percentage
  - [ ] Preserve meaning
  - [ ] Highlight redundancies

- [ ] Create default prompt templates:
  - [ ] Design clarity template
  - [ ] Create brand alignment template
  - [ ] Build proof review template
  - [ ] Design concision template
  - [ ] Add customization options
  - [ ] Version control templates

- [ ] Implement brand guidelines loading:
  - [ ] Create guidelines storage
  - [ ] Parse guideline documents
  - [ ] Extract key rules
  - [ ] Create guideline index
  - [ ] Cache processed guidelines
  - [ ] Handle multiple brands

- [ ] Add UI for customizing prompts:
  - [ ] Create prompt editor
  - [ ] Add template variables
  - [ ] Preview prompt output
  - [ ] Save custom prompts
  - [ ] Share prompt library
  - [ ] Import/export prompts

- [ ] Create review results display:
  - [ ] Design results UI
  - [ ] Show inline annotations
  - [ ] Create summary view
  - [ ] Add severity levels
  - [ ] Implement filtering
  - [ ] Export review report

- [ ] Implement review history:
  - [ ] Store review results
  - [ ] Track changes over time
  - [ ] Compare review versions
  - [ ] Show improvement metrics
  - [ ] Generate progress reports
  - [ ] Archive old reviews

- [ ] Add review suggestions:
  - [ ] Auto-suggest reviews
  - [ ] Detect content changes
  - [ ] Recommend review types
  - [ ] Schedule periodic reviews
  - [ ] Create review reminders
  - [ ] Track review completion

- [ ] Create review command wizard:
  - [ ] Design wizard interface
  - [ ] Guide prompt creation
  - [ ] Provide examples
  - [ ] Test custom commands
  - [ ] Save to library
  - [ ] Share with team

### Test Checklist:
- [ ] Test each review command with sample content
- [ ] Verify brand guidelines loading works correctly
- [ ] Test custom prompt creation and editing
- [ ] Verify review results display correctly
- [ ] Test review history tracking
- [ ] Ensure review commands integrate with existing slash command system
- [ ] Test review command wizard functionality

---

## Summary

### Pending Tasks:
- ⏳ Context control commands (/compact, /clear, /include, /snippet)
- ⏳ Custom tools and widgets system
- ⏳ Review slash commands for content quality

### Key Features to Implement:
1. **Slash Commands** - Quick context control and document operations
2. **Custom Tools** - User-defined tools with prompt templates
3. **Widgets** - Draggable UI components for specialized tasks
4. **Review Commands** - AI-powered content quality checks
5. **Command Wizard** - Easy creation of custom commands

### Architecture Considerations:
- Ensure commands are discoverable and intuitive
- Make custom tools shareable between users
- Design widgets to be modular and reusable
- Keep review prompts flexible and customizable
- Plan for extensibility of command system

### User Experience Goals:
- Fast command execution with visual feedback
- Intuitive wizard interfaces for customization
- Seamless integration with existing editor
- Clear presentation of review results
- Persistent widget layouts across sessions