# Context7 MCP Integration Guide

## Overview

This guide provides standardized patterns for integrating Context7 documentation loading across all Claude agents. Context7 provides real-time, version-specific documentation that enhances agent decision-making and ensures current best practices.

## Context7 Tools

### Available Tools
- **resolve-library-id**: Convert library names to Context7-compatible IDs
- **get-library-docs**: Fetch current documentation for specific topics (with optional topic focus and token limits)

### Connection Health Check

Before using Context7 tools, agents should verify connectivity:

```bash
# Check Context7 status
claude mcp list | grep context7

# Expected output for healthy connection:
# context7: http https://mcp.context7.com/mcp - ✓ Connected

# If connection fails:
# context7: http https://mcp.context7.com/mcp - ✗ Failed to connect
```

## Integration Patterns by Agent Type

### Language/Framework Experts
**Agents**: ruby-rails-expert, javascript-package-expert, tailwind-css-expert

**Primary Use Cases**:
- Query current framework versions and features
- Validate best practices before implementation
- Check linting rule explanations and fixes
- Load performance optimization patterns

**Example Queries**:
```javascript
// For Rails expert
"Rails 8 Hotwire patterns"
"ActiveRecord query optimization"
"RuboCop rule explanations"

// For JavaScript expert  
"ESLint configuration best practices"
"TypeScript latest features"
"npm security guidelines"

// For Tailwind expert
"Tailwind CSS responsive patterns"
"Tailwind v3 arbitrary values"
"Tailwind dark mode implementation"
```

### Coordination Agents
**Agents**: project-orchestrator, error-debugger

**Primary Use Cases**:
- Validate architectural decisions
- Query debugging patterns and error resolutions
- Check current industry standards
- Load framework integration guidelines

**Example Queries**:
```bash
# For orchestrator
"Software architecture patterns 2024"
"Full-stack development workflows"
"Testing strategy best practices"

# For debugger
"Error debugging patterns"
"Performance troubleshooting guides"
"Framework-specific error solutions"
```

### Testing Agent
**Agent**: test-runner-fixer

**Primary Use Cases**:
- Load current testing framework patterns
- Query test debugging techniques
- Check assertion and mock best practices

**Example Queries**:
```ruby
"RSpec best practices"
"Jest testing patterns"
"Rails system testing guides"
```

## Standardized Integration Protocol

### 1. Pre-Query Assessment
Before making Context7 queries:
- Identify the specific technology/framework involved
- Determine the type of guidance needed (patterns, debugging, configuration)
- Choose appropriate topic focus to limit response scope

### 2. Query Construction
- Use specific, focused queries rather than broad topics
- Include version information when relevant
- Limit token responses based on complexity (default: 10000)

### 3. Fallback Strategy
When Context7 is unavailable or fails:
- Proceed with existing knowledge base
- Document in completion reports that documentation wasn't verified
- Recommend manual verification of approaches
- Flag areas that may need current practice validation

### 4. Error Handling
If Context7 queries fail:
- Log the specific error (connection timeout, service unavailable, etc.)
- Continue with planned work using existing knowledge
- Include troubleshooting steps in completion report
- Suggest Context7 connection verification

## Health Check Implementation

### Connection Verification
Agents can check Context7 status before critical decisions:

```bash
# Quick health check
if claude mcp get context7 | grep -q "✓ Connected"; then
    echo "Context7 available - proceeding with documentation queries"
else 
    echo "Context7 unavailable - using fallback approach"
fi
```

### Graceful Degradation
When Context7 is unavailable:
1. **Continue Operation**: Don't block on documentation queries
2. **Document Limitations**: Note in reports that current practices weren't verified
3. **Provide Alternatives**: Suggest manual verification steps
4. **Flag for Review**: Recommend post-completion validation

## Best Practices

### Query Optimization
- **Be Specific**: Use focused topics rather than broad categories
- **Version Aware**: Include framework versions when relevant
- **Token Conscious**: Adjust token limits based on query complexity
- **Topic Focused**: Use topic parameter to narrow scope

### Integration Timing
- **Pre-Implementation**: Query before making architectural decisions
- **During Review**: Validate approaches against current standards
- **For Debugging**: Look up current error patterns and solutions
- **Post-Implementation**: Verify final approaches align with best practices

### Documentation Standards
All agents should document Context7 usage in completion reports:
- Which queries were made and why
- Whether Context7 was available or unavailable
- How documentation influenced decisions
- Recommendations for manual verification if needed

## Troubleshooting

### Common Issues
1. **Connection Timeout**: Context7 service temporarily unavailable
2. **Library Not Found**: Requested library not in Context7 database
3. **Token Limit Exceeded**: Response truncated due to size limits
4. **Invalid Query**: Malformed query parameters

### Resolution Steps
1. Verify MCP configuration: `claude mcp get context7`
2. Check network connectivity
3. Retry with more specific query terms
4. Reduce token limits for large responses
5. Fall back to existing knowledge if issues persist

## Agent-Specific Customizations

Each agent can customize Context7 integration based on their domain:
- **Query Patterns**: Technology-specific query templates
- **Fallback Strategies**: Domain-appropriate alternative approaches
- **Documentation Requirements**: Varying levels of verification needed
- **Token Allocations**: Adjusted based on typical response complexity

This guide should be referenced by all agents when implementing Context7 integration to ensure consistent, robust documentation loading across the system.