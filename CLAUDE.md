# Claude Code Agent System

## Quick Start

1. **Simple Tasks** → Direct to specialist agent
2. **Complex Tasks** → Use `project-orchestrator` (Planning Mode)
3. **Errors** → Auto-escalate to `error-debugger`

## Agent Reference

| Agent | Use For | Trigger Keywords |
|-------|---------|------------------|
| 🚂 `ruby-rails-expert` | Rails + Ruby linting (RuboCop) | rails, model, controller, activerecord, rubocop, lint |
| 📦 `javascript-package-expert` | JS/TS + npm + JS linting (ESLint) | npm, javascript, package, stimulus, eslint, lint |
| 🎨 `tailwind-css-expert` | Styling, UI, responsive design | css, tailwind, styling, ui |
| 🧪 `test-runner-fixer` | Write/fix tests, coverage | test, spec, rspec, coverage |
| 🐛 `error-debugger` | Debug errors, performance | error, bug, failing, debug |
| 📋 `project-orchestrator` | Planning, coordination, todo lists | plan, coordinate, complex, todo, strategy |
| 🔀 `git-auto-commit` | Create commits | commit, save changes |

## Workflow

See visual workflow: [workflow-diagram.md](.claude/workflow-diagram.md)

## Agent Communication

Agents communicate through structured completion reports embedded in their responses. Each agent knows when to hand off work to the next appropriate agent.

## Context7 Documentation Integration

All agents are enhanced with real-time documentation access via Context7 MCP server:

- **📚 Current Best Practices**: Agents query up-to-date framework documentation before making decisions
- **🔍 Version-Specific Guidance**: Access to latest stable versions and migration guides  
- **⚡ Performance Optimization**: Current techniques and patterns from official sources
- **🛡️ Security Standards**: Latest security guidelines and vulnerability patterns
- **🧪 Testing Strategies**: Modern testing framework patterns and best practices

**Integration Guide**: [context7-integration-guide.md](.claude/context7-integration-guide.md)

### Usage Pattern
Agents automatically query Context7 for current documentation when:
- Making architectural decisions
- Implementing new features
- Debugging complex issues
- Running linting and quality checks
- Creating comprehensive plans

### Fallback Strategy
If Context7 is unavailable, agents gracefully degrade to existing knowledge while noting documentation verification needs in completion reports.

## Playwright Browser Automation Integration

All agents are enhanced with comprehensive browser automation capabilities via Playwright MCP server:

- **🌐 Real-Browser Testing**: Agents perform E2E testing, visual validation, and user interaction simulation
- **📱 Cross-Platform Validation**: Testing across Chromium, Firefox, WebKit, and mobile viewports
- **🎨 Visual Regression Testing**: Automated screenshot comparison and responsive design validation
- **🔍 Interactive Debugging**: Browser-based error reproduction and real-time debugging capabilities
- **⚡ Performance Testing**: Real-world performance monitoring and optimization in browser environments
- **🧪 System Testing**: Full-stack user journey validation and integration testing

**Integration Guide**: [playwright-integration-guide.md](.claude/playwright-integration-guide.md)

### Usage Patterns by Agent
- **🧪 test-runner-fixer**: E2E test automation, visual regression testing, cross-browser validation
- **🎨 tailwind-css-expert**: Responsive design testing, component visual validation, interactive state testing
- **🐛 error-debugger**: Browser bug reproduction, JavaScript error analysis, UI debugging workflows
- **📦 javascript-package-expert**: Real-browser JS testing, Stimulus controller validation, package integration
- **🚂 ruby-rails-expert**: Rails system testing, user journey validation, Hotwire/Turbo testing
- **📋 project-orchestrator**: Comprehensive testing strategy coordination, multi-agent workflow orchestration

### Browser Automation Capabilities
Agents automatically use Playwright for:
- User interaction simulation (clicks, form submission, navigation)
- Visual state capture and screenshot comparison
- Console error monitoring and network request analysis
- Cross-browser compatibility validation
- Performance profiling and optimization
- Accessibility testing and validation

### Fallback Strategy
If Playwright is unavailable, agents gracefully fall back to traditional testing methods while documenting browser testing limitations in completion reports.

## Router Configuration

Automatic agent selection rules: [router.yaml](.claude/router.yaml)

## Task Master Integration

**Import Task Master commands:**
@./.taskmaster/CLAUDE.md

All agents automatically:
- Update task status via `mcp__task-master-ai__set_task_status`
- Log progress via `mcp__task-master-ai__update_subtask`

## Starting Complex Tasks

```bash
Task(description="Brief description",
     subagent_type="project-orchestrator", 
     prompt="Create automatic workflow for: [detailed requirements]")
```

The orchestrator will:
1. Analyze requirements
2. Create delegation plan
3. Launch specialist agents
4. Monitor progress
5. Handle errors/escalations
6. Trigger git commit when complete

## Agent Communication Flow

```
User Request → Analyze → Route to Agent → Execute → Report → Next Agent/Complete
                  ↓
              [Complex?] → project-orchestrator → Delegation Plan
```

## Error Handling

Automatic escalation chain:
1. Specialist agent attempts fix
2. Escalate to `error-debugger`
3. Escalate to `project-orchestrator`
4. Replan and reassign

## Planning Protocol

**MANDATORY: All complex tasks must begin with proper planning**

1. **Planning Requirement**: Any task involving multiple steps, agents, or phases MUST start with project-orchestrator in Planning Mode
2. **Plan Storage**: All plans MUST be saved to `@plans/[feature-name]/README.md` before execution
3. **Todo Tracking**: Use TodoWrite tool to create actionable, trackable task lists
4. **Execution Flow**: 
   - User request → project-orchestrator analyzes complexity
   - Complex task → Planning Mode creates plan
   - Plan saved to @plans/ directory
   - TodoWrite creates task list
   - Execution Mode runs plan
   - Progress tracked via Task Master

### Plan Structure Requirements

Every plan must include:
- Clear objectives and success criteria
- Actionable todo list with agent assignments
- Test-Driven Development (TDD) approach
- Linting and code quality phases
- Implementation phases with timelines
- Risk assessment and mitigation
- Automatic execution command

### TDD and Code Quality Protocol

1. **Test First**: All new features MUST start with failing tests
2. **Implementation**: Code only to make tests pass
3. **Linting**: Run appropriate linters after each implementation:
   - Ruby: `ruby-rails-expert` (includes RuboCop)
   - JavaScript: `javascript-package-expert` (includes ESLint)
4. **Quality Gates**: No phase proceeds with failing tests or linting errors

### Planning Workflow Example

```bash
# For any complex feature request:
Task(description="Implement [feature]",
     subagent_type="project-orchestrator",
     prompt="[Detailed requirements] - Create plan and execute with automatic handoffs")

# Or if plan already exists:
Task(description="Execute [feature] plan",
     subagent_type="project-orchestrator", 
     prompt="Execute plan at plans/[feature-name]/README.md")
```

## Best Practices

- Always start complex tasks with project-orchestrator (Planning Mode)
- Let orchestrator handle multi-domain tasks
- Linting is integrated with language experts (not separate agents)
- Trust automatic handoffs
- Check Task Master for progress
- Agents complete work before handoff
- Use structured completion reports
- Document all plans in @plans/ directory

## Important Instructions

- Do what's asked; nothing more, nothing less
- Never create files unless necessary
- Always prefer editing existing files
- No unsolicited documentation creation
- ALWAYS plan before executing complex tasks

For detailed agent capabilities, see individual agent files in `.claude/agents/`