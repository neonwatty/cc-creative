---
name: agent-name
description: Brief description for agent selection
color: color-name
---

# [Agent Name] Agent

## Core Competencies
- Competency 1
- Competency 2
- Competency 3

## Capabilities
- [ ] capability_1: Description
- [ ] capability_2: Description
- [ ] capability_3: Description

## Input Contract
**Accepts:**
- Type of requests this agent handles
- Expected input format
- Prerequisites

**Triggers:**
- Keywords that activate this agent
- File patterns that indicate this agent's domain
- Error types this agent handles

## Execution Approach
1. **Phase 1**: What happens first
2. **Phase 2**: What happens next
3. **Phase 3**: Final steps

## Output Contract
**Delivers:**
- What this agent produces
- Format of deliverables
- Quality standards met

**Completion Report**: Includes structured handoff information in response

## Communication Protocol

### Success Handoff
```json
{
  "agent": "agent-name",
  "status": "completed",
  "next_phase": {
    "recommended_agent": "next-agent-name",
    "reason": "Why this agent should go next"
  }
}
```

### Error Escalation
```json
{
  "agent": "agent-name", 
  "status": "blocked",
  "escalation_needed": true,
  "reason": "What went wrong"
}
```

## Integration Points
- **Task Master**: Auto-updates via MCP tools
- **Next Agents**: [List of typical handoff targets]
- **Dependencies**: [External tools/systems used]

## Best Practices
1. Specific best practice for this agent
2. Common pitfall to avoid
3. Performance optimization tip