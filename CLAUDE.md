# Claude Code Instructions

## Quick Agent Reference
- 🚂 Rails/Ruby → `ruby-rails-expert`
- 📦 JS/npm → `javascript-package-expert`  
- 🎨 CSS/UI → `tailwind-css-expert`
- 🧪 Tests → `test-runner-fixer`
- 🐛 Debug → `error-debugger`
- 📋 Planning → `project-orchestrator`
- 🔀 Git → `git-auto-commit`

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md

## Agent Assignment Guidelines

### Task Type to Agent Mapping
When working on tasks, use the appropriate specialized agent based on the task domain:

#### Backend Development
- **Ruby/Rails Tasks** → `ruby-rails-expert`
  - Models, controllers, migrations, ActiveRecord
  - Rails configuration, routing, Action Cable
  - Rails testing (RSpec, Minitest)
  - ViewComponents and Rails view logic
  
#### Frontend Development
- **JavaScript/TypeScript** → `javascript-package-expert`
  - npm/yarn package management
  - Stimulus controllers, JavaScript modules
  - Build tools and bundling
  - Frontend framework integration
  
- **Styling/UI** → `tailwind-css-expert`
  - Tailwind CSS utilities and components
  - Responsive design, dark mode
  - ViewComponent styling
  - CSS architecture and optimization

#### Quality Assurance
- **Testing** → `test-runner-fixer`
  - Writing new tests
  - Fixing failing tests
  - Test coverage improvements
  - Test performance optimization
  
- **Debugging** → `error-debugger`
  - Runtime errors, exceptions
  - Performance issues
  - Unexpected behavior
  - Stack trace analysis

#### Project Management
- **Planning/Coordination** → `project-orchestrator`
  - Breaking down complex tasks
  - Coordinating multi-agent work
  - Architectural decisions
  - Risk assessment and mitigation

#### Version Control
- **Git Operations** → `git-auto-commit`
  - Creating meaningful commits
  - Managing git workflow
  - Analyzing changes for commit messages

### Before Starting a Task
1. Read the task details carefully using `task-master show <id>`
2. Identify the primary technology domain (Rails, JS, CSS, etc.)
3. Check if the task involves multiple domains
4. Assign the appropriate agent(s) based on the mapping above
5. For multi-domain tasks, use `project-orchestrator` to coordinate

### Agent Usage Examples

#### Example 1: Creating a Rails Controller (Single Domain)
```bash
# For task 4.2: "Create ContextItems controller with CRUD actions"
# Use ruby-rails-expert
Task(description="Create Rails controller", 
     subagent_type="ruby-rails-expert", 
     prompt="Create ContextItems controller with CRUD actions, Pundit authorization...")
```

#### Example 2: Implementing ViewComponent with Styling (Multi-Domain)
```bash
# For task 4.3: "Implement ContextSidebarComponent"
# First use ruby-rails-expert for the component structure
Task(description="Create ViewComponent", 
     subagent_type="ruby-rails-expert", 
     prompt="Generate and implement ContextSidebarComponent...")

# Then use tailwind-css-expert for styling
Task(description="Style sidebar component", 
     subagent_type="tailwind-css-expert", 
     prompt="Style the context sidebar with Tailwind CSS...")
```

#### Example 3: Complex Feature with JS Interactivity
```bash
# For task 4.4: "Add drag-and-drop functionality"
# Use project-orchestrator to plan the approach
Task(description="Plan drag-and-drop", 
     subagent_type="project-orchestrator", 
     prompt="Plan implementation of drag-and-drop with Sortable.js...")

# Then execute with appropriate agents based on the plan
```

### Multi-Agent Workflows

For tasks spanning multiple domains, follow this pattern:

1. **Analyze** → Use your judgment or `project-orchestrator` for complex tasks
2. **Execute** → Use domain-specific agents for implementation
3. **Test** → Use `test-runner-fixer` to verify
4. **Debug** → Use `error-debugger` if issues arise
5. **Commit** → Use `git-auto-commit` when complete

#### Example Workflow: "Implement Context Sidebar with Drag-and-Drop"
```bash
1. project-orchestrator → Break down the feature into components
2. ruby-rails-expert → Create ViewComponent and controller logic
3. tailwind-css-expert → Design and style the UI
4. javascript-package-expert → Add Stimulus controllers for interactivity
5. test-runner-fixer → Write comprehensive tests
6. error-debugger → Fix any issues that arise
7. git-auto-commit → Commit the completed feature
```

### Agent Selection Quick Rules
- See Ruby/Rails code? → `ruby-rails-expert`
- See package.json or JS files? → `javascript-package-expert`
- Need styling or Tailwind? → `tailwind-css-expert`
- Tests failing? → `test-runner-fixer`
- Getting errors? → `error-debugger`
- Need to plan complex work? → `project-orchestrator`
- Ready to commit? → `git-auto-commit`

## Automatic Workflow Patterns

### Orchestrator-Managed Workflows

For complex tasks requiring multiple agents, use the `project-orchestrator` to create automatic handoff chains that eliminate manual intervention:

#### Pattern 1: Full-Stack Feature Implementation
```bash
# Start with orchestrator for planning and delegation
Task(description="Implement feature with automatic handoffs", 
     subagent_type="project-orchestrator", 
     prompt="Create automatic delegation chain for [feature description]. 
             Include Task Master integration and agent handoff protocols.")

# Orchestrator creates delegation plan and launches first agent
# Each agent automatically:
# 1. Completes their work
# 2. Updates Task Master status
# 3. Signals completion with structured report
# 4. Recommends next agent
# 5. Project orchestrator launches next phase
```

#### Pattern 2: Bug Fix with Testing
```bash
# For error scenarios requiring coordination
Task(description="Debug and fix with automatic testing", 
     subagent_type="project-orchestrator", 
     prompt="Coordinate error-debugger → test-runner-fixer → git-auto-commit")
```

#### Pattern 3: UI Feature with Backend Integration
```bash
# For features spanning multiple domains
Task(description="Coordinate full-stack UI feature", 
     subagent_type="project-orchestrator", 
     prompt="Plan: ruby-rails-expert → tailwind-css-expert → javascript-package-expert → test-runner-fixer → git-auto-commit")
```

### Agent Completion Protocols

All specialist agents now follow automatic handoff protocols:

#### Completion Report Format (All Agents)
```
## [AGENT TYPE] WORK COMPLETED ✅

**Implementation Summary:**
- [What was accomplished]

**Files Modified:**
- [List all files]

**Next Phase Readiness:**
- ✅ [Current work complete]
- ✅ Ready for [next work type]
- ⚠️ [Any blockers]

**Handoff Instructions:**
- [Guidance for next agent]

**Task Master Status:** Updated to [status]
```

#### Automatic Status Updates
Agents automatically call Task Master MCP tools:
- `mcp__task-master-ai__set_task_status` - Mark tasks complete
- `mcp__task-master-ai__update_subtask` - Log implementation notes

#### Next Agent Recommendations
Each agent suggests the next logical step:
- Backend complete → Frontend agent
- Frontend complete → Testing agent  
- Testing complete → Git commit agent
- Errors encountered → Debug agent

### Error Escalation Procedures

#### Automatic Escalation Chain
1. **Specialist Agent** encounters blocker
2. **Specialist Agent** documents issue and attempts resolution
3. If unresolved → **error-debugger** agent activated
4. If still blocked → **project-orchestrator** coordinates resolution
5. **project-orchestrator** may reassign or modify delegation plan

#### Escalation Format
```
## ESCALATION TO PROJECT-ORCHESTRATOR ⚠️

**Issue:** [Brief description]
**Agent:** [Current agent type]
**Attempted Solutions:** [What was tried]
**Blocker Details:** [Specific problem]
**Recommendation:** [Suggested next steps]
```

### Task Master Integration Patterns

#### Automatic Progress Tracking
```bash
# Agents automatically update Task Master throughout workflow:
1. project-orchestrator → Creates delegation plan, updates task
2. specialist-agent → Updates subtask with progress, marks complete
3. next-agent → Auto-triggered based on completion report
4. git-auto-commit → Final status update and task closure
```

#### Structured Logging
```bash
# Each phase automatically logs to Task Master:
task-master update-subtask --id=4.6 --prompt="Rails models created, ready for UI work"
task-master update-subtask --id=4.6 --prompt="UI components styled, ready for testing"
task-master set-status --id=4.6 --status=done
```

### Benefits of Automatic Workflows

1. **Zero Manual Intervention** - Once started, workflow completes automatically
2. **Consistent Task Tracking** - All progress logged to Task Master
3. **Structured Handoffs** - Clear communication between agents
4. **Error Recovery** - Automatic escalation and coordination
5. **Audit Trail** - Complete history of work and decisions

### Usage Instructions

#### To Start Automatic Workflow:
```bash
# For new complex tasks
Task(description="[brief description]", 
     subagent_type="project-orchestrator", 
     prompt="Create automatic workflow for: [detailed requirements]")
```

#### To Continue Existing Workflow:
Agents will automatically continue based on completion protocols - no user intervention needed.

#### To Handle Interruptions:
If workflow is interrupted, restart with:
```bash
Task(description="Resume workflow", 
     subagent_type="project-orchestrator", 
     prompt="Analyze current task state and resume automatic workflow from where it left off")
```
