# Agent Capabilities Matrix

## Quick Decision Guide

| Task Type | Primary Agent | Secondary Agent | When to Escalate |
|-----------|--------------|-----------------|------------------|
| Create Rails model | ruby-rails-expert | - | If complex associations |
| Fix JavaScript error | error-debugger | javascript-package-expert | If architectural issue |
| Style component | tailwind-css-expert | - | If needs JS interactivity |
| Write tests | test-runner-fixer | - | If tests reveal bugs |
| Plan feature | project-orchestrator | - | Always for complex tasks |
| Debug performance | error-debugger | Specialist for domain | If systemic issue |
| Commit changes | git-auto-commit | - | Never |

## Detailed Capability Matrix

### ruby-rails-expert 🚂

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Models & Migrations | ⭐⭐⭐⭐⭐ | User model, associations, validations | tailwind-css-expert (for views) |
| Controllers | ⭐⭐⭐⭐⭐ | CRUD, authentication, authorization | javascript-package-expert (for AJAX) |
| Rails Configuration | ⭐⭐⭐⭐⭐ | routes.rb, application.rb, initializers | - |
| ActiveRecord | ⭐⭐⭐⭐⭐ | Complex queries, scopes, callbacks | error-debugger (for N+1) |
| Testing (Rails) | ⭐⭐⭐⭐ | RSpec, Minitest, fixtures | test-runner-fixer (for failures) |
| ViewComponents | ⭐⭐⭐⭐ | Component structure, slots | tailwind-css-expert (for styling) |

### javascript-package-expert 📦

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Package Management | ⭐⭐⭐⭐⭐ | npm, yarn, dependencies | error-debugger (for conflicts) |
| Stimulus Controllers | ⭐⭐⭐⭐⭐ | Interactivity, DOM manipulation | tailwind-css-expert (for styling) |
| Build Tools | ⭐⭐⭐⭐ | Webpack, esbuild, importmaps | error-debugger (for build failures) |
| Modern JS/TS | ⭐⭐⭐⭐⭐ | ES6+, TypeScript, modules | test-runner-fixer (for JS tests) |
| Frontend Frameworks | ⭐⭐⭐ | React, Vue integration | project-orchestrator (for architecture) |

### tailwind-css-expert 🎨

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Utility Classes | ⭐⭐⭐⭐⭐ | Responsive, hover states, animations | javascript-package-expert (for JS) |
| Component Design | ⭐⭐⭐⭐⭐ | Cards, modals, navigation | test-runner-fixer (for visual tests) |
| Dark Mode | ⭐⭐⭐⭐⭐ | Theme switching, color schemes | - |
| Custom Config | ⭐⭐⭐⭐ | tailwind.config.js, plugins | - |
| Performance | ⭐⭐⭐⭐ | PurgeCSS, optimization | error-debugger (if issues) |

### test-runner-fixer 🧪

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Write Tests | ⭐⭐⭐⭐⭐ | Unit, integration, system tests | git-auto-commit (when passing) |
| Fix Failures | ⭐⭐⭐⭐⭐ | Debug test issues, update assertions | error-debugger (for app bugs) |
| Test Coverage | ⭐⭐⭐⭐ | Coverage reports, missing tests | - |
| Test Performance | ⭐⭐⭐⭐ | Optimize slow tests, parallelize | - |
| Multiple Frameworks | ⭐⭐⭐⭐ | RSpec, Minitest, Jest, Cypress | - |

### error-debugger 🐛

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Runtime Errors | ⭐⭐⭐⭐⭐ | Exceptions, crashes, undefined | test-runner-fixer (add tests) |
| Build Failures | ⭐⭐⭐⭐⭐ | Compilation, bundling, syntax | Original specialist |
| Performance | ⭐⭐⭐⭐ | Slow queries, memory leaks, N+1 | Specialist for optimization |
| Logic Errors | ⭐⭐⭐⭐⭐ | Incorrect behavior, edge cases | test-runner-fixer (add tests) |
| Root Cause Analysis | ⭐⭐⭐⭐⭐ | Deep debugging, system issues | project-orchestrator (if complex) |

### project-orchestrator 📋

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Planning | ⭐⭐⭐⭐⭐ | Break down features, architecture | Specialist agents |
| Delegation | ⭐⭐⭐⭐⭐ | Assign tasks, coordinate work | All agents |
| Risk Assessment | ⭐⭐⭐⭐ | Identify issues, dependencies | error-debugger (preventive) |
| Multi-Domain | ⭐⭐⭐⭐⭐ | Full-stack features, integrations | Multiple specialists |
| Monitoring | ⭐⭐⭐⭐⭐ | Track progress, handle blockers | git-auto-commit (when done) |

### git-auto-commit 🔀

| Capability | Strength | Examples | Handoff To |
|------------|----------|----------|------------|
| Analyze Changes | ⭐⭐⭐⭐⭐ | git diff, status, staged files | - |
| Write Messages | ⭐⭐⭐⭐⭐ | Conventional commits, detailed | - |
| Git Operations | ⭐⭐⭐⭐ | add, commit, branch management | - |
| PR Creation | ⭐⭐⭐ | GitHub CLI integration | - |

## Decision Tree

```
Start
├─ Is it an error/bug?
│  └─ YES → error-debugger
│  └─ NO → Continue
├─ Is it multi-domain?
│  └─ YES → project-orchestrator
│  └─ NO → Continue
├─ What's the primary domain?
│  ├─ Rails/Backend → ruby-rails-expert
│  ├─ JavaScript/Frontend → javascript-package-expert
│  ├─ Styling/UI → tailwind-css-expert
│  ├─ Testing → test-runner-fixer
│  └─ Version Control → git-auto-commit
```

## Capability Overlap Areas

### Areas Where Multiple Agents Can Help

1. **Form Implementation**
   - ruby-rails-expert: Rails forms, validations
   - tailwind-css-expert: Form styling
   - javascript-package-expert: Dynamic forms

2. **API Integration**
   - ruby-rails-expert: Rails API endpoints
   - javascript-package-expert: Frontend API calls
   - error-debugger: API errors

3. **Performance**
   - ruby-rails-expert: Query optimization
   - error-debugger: Performance profiling
   - test-runner-fixer: Performance tests

## Agent Collaboration Patterns

### Sequential Handoffs
```
Backend → Frontend → Styling → Testing → Commit
```

### Parallel Execution
```
┌─ ruby-rails-expert (models)
├─ javascript-package-expert (controllers)
└─ tailwind-css-expert (views)
   └─ All merge → test-runner-fixer
```

### Error Recovery
```
Any Agent → error-debugger → Original Agent → Continue
```