# Playwright MCP Browser Automation Integration Guide

## Overview

This guide provides standardized patterns for integrating Playwright MCP browser automation across all Claude agents. Playwright MCP enables comprehensive browser testing, visual validation, user interaction simulation, and real-world performance testing that enhances agent capabilities for modern web development workflows.

## Playwright MCP Capabilities

### Available Tools
- **mcp__playwright__browser_navigate**: Navigate to URLs and pages
- **mcp__playwright__browser_click**: Click elements and trigger interactions
- **mcp__playwright__browser_type**: Fill forms and input fields
- **mcp__playwright__browser_take_screenshot**: Capture visual states and screenshots
- **mcp__playwright__browser_snapshot**: Get accessibility tree snapshots
- **mcp__playwright__browser_wait_for**: Wait for elements, conditions, or timeouts
- **mcp__playwright__browser_evaluate**: Execute JavaScript in browser context
- **mcp__playwright__browser_console_messages**: Monitor JavaScript errors and logs
- **mcp__playwright__browser_network_requests**: Track network requests and responses
- **mcp__playwright__browser_resize**: Test different viewport sizes
- **mcp__playwright__browser_hover**: Test hover states and interactions

### Connection Health Check

Before using Playwright tools, agents should verify connectivity:

```bash
# Check Playwright status
claude mcp list | grep playwright

# Expected output for healthy connection:
# playwright: npx @playwright/mcp@latest - ✓ Connected

# If connection fails:
# playwright: npx @playwright/mcp@latest - ✗ Failed to connect
```

## Integration Patterns by Agent Type

### Testing and Quality Assurance Agents
**Agents**: test-runner-fixer, error-debugger

**Primary Use Cases**:
- E2E test automation and generation
- Browser-based error reproduction and debugging
- Visual regression testing and validation
- Cross-browser compatibility testing
- Performance testing in real browser environments

**Example Workflows**:
```javascript
// E2E Testing Pattern
// 1. Navigate to application URL
// 2. Perform user interactions (login, navigation, form submission)
// 3. Capture screenshots for visual validation
// 4. Monitor console errors and network requests
// 5. Validate expected outcomes and generate test code

// Error Debugging Pattern  
// 1. Navigate to error-prone page
// 2. Reproduce user actions leading to error
// 3. Capture console messages and network failures
// 4. Take screenshots of error states
// 5. Execute debugging JavaScript to inspect application state
```

### Visual and Design Agents
**Agents**: tailwind-css-expert

**Primary Use Cases**:
- Responsive design validation across viewport sizes
- Visual component testing and screenshot comparison
- Interactive state testing (hover, focus, active)
- Cross-browser CSS compatibility validation
- Theme and dark mode visual testing

**Example Workflows**:
```css
/* Responsive Design Testing Pattern
 * 1. Navigate to component showcase or application page
 * 2. Resize browser to different breakpoints (sm, md, lg, xl, 2xl)
 * 3. Capture screenshots at each breakpoint
 * 4. Test interactive states (hover, focus)
 * 5. Validate visual consistency across browsers
 * 6. Test dark mode and theme variations
 */
```

### Development and Integration Agents
**Agents**: javascript-package-expert, ruby-rails-expert

**Primary Use Cases**:
- Real-browser JavaScript testing and validation
- Stimulus controller testing in browser environments
- Rails system testing and user journey validation
- Package integration validation
- Full-stack feature testing

**Example Workflows**:
```ruby
# Rails System Testing Pattern
# 1. Navigate to Rails application routes
# 2. Test user authentication and session management
# 3. Fill and submit Rails forms with validation
# 4. Test Turbo frame updates and Stimulus responses
# 5. Validate database changes through browser interactions
# 6. Test complete user workflows end-to-end
```

### Coordination Agents
**Agents**: project-orchestrator

**Primary Use Cases**:
- Comprehensive testing strategy coordination
- Multi-agent browser testing workflow orchestration
- Quality assurance planning with browser automation
- Cross-browser compatibility strategy development

## Standardized Integration Protocol

### 1. Pre-Automation Assessment
Before using Playwright tools:
- Verify the task requires browser-based validation or testing
- Identify the specific browser interactions needed
- Determine cross-browser compatibility requirements
- Choose appropriate browser automation tools for the task

### 2. Browser Session Management
- Use appropriate browser contexts for isolation
- Manage browser state between different testing scenarios
- Handle authentication and session management properly
- Clean up browser resources after automation tasks

### 3. Error Handling and Resilience
When Playwright operations fail:
- Implement retry mechanisms for flaky interactions
- Use explicit waits instead of fixed delays
- Handle timeout scenarios gracefully
- Capture diagnostic information for debugging

### 4. Cross-Browser Testing Strategy
- Test critical functionality across Chromium, Firefox, and WebKit
- Validate mobile vs desktop behavior differences
- Consider performance variations across browser engines
- Document browser-specific issues and workarounds

## Health Check Implementation

### Connection Verification
Agents can check Playwright status before critical browser operations:

```bash
# Quick health check
if claude mcp get playwright | grep -q "✓ Connected"; then
    echo "Playwright available - proceeding with browser automation"
else 
    echo "Playwright unavailable - using fallback approach"
fi
```

### Graceful Degradation
When Playwright is unavailable:
1. **Continue Operation**: Don't block on browser automation
2. **Document Limitations**: Note in reports that browser testing wasn't performed
3. **Provide Alternatives**: Suggest manual browser testing steps
4. **Flag for Review**: Recommend post-completion browser validation

## Best Practices by Use Case

### Visual Testing Best Practices
- **Consistent Screenshots**: Use standardized viewport sizes and wait conditions
- **Visual Comparison**: Implement threshold-based image comparison strategies
- **State Management**: Ensure consistent application state before visual capture
- **Cross-Browser Consistency**: Test visual elements across different rendering engines

### Interactive Testing Best Practices
- **Reliable Selectors**: Use accessibility attributes and stable selectors
- **Explicit Waits**: Wait for specific conditions rather than arbitrary timeouts
- **User-Centric Actions**: Simulate realistic user interaction patterns
- **Error State Testing**: Validate error handling and edge case behaviors

### Performance Testing Best Practices
- **Real-World Conditions**: Test under various network conditions and device constraints
- **Comprehensive Metrics**: Monitor loading performance, runtime performance, and memory usage
- **Baseline Comparisons**: Establish performance benchmarks and track regressions
- **Mobile Performance**: Validate performance on mobile devices and slower networks

### System Testing Best Practices
- **End-to-End Workflows**: Test complete user journeys from start to finish
- **Data Management**: Use appropriate test data and database cleanup strategies
- **Authentication Testing**: Validate login, session management, and authorization flows
- **Integration Points**: Test API interactions and third-party service integrations

## Agent-Specific Integration Guidelines

### test-runner-fixer
- Focus on automated test generation and execution
- Prioritize cross-browser compatibility testing
- Implement visual regression testing workflows
- Generate maintainable test code from browser interactions

### tailwind-css-expert
- Emphasize responsive design validation and visual testing
- Test component states and interactive styling
- Validate design system consistency across browsers
- Implement theme and accessibility testing workflows

### error-debugger
- Prioritize error reproduction and root cause analysis
- Capture comprehensive debugging context (console, network, visual)
- Test error scenarios and edge cases systematically
- Validate fixes in the same controlled browser environment

### javascript-package-expert
- Focus on real-browser JavaScript validation and package testing
- Test Stimulus controllers and interactive components
- Validate package integration and compatibility
- Monitor JavaScript performance and error patterns

### ruby-rails-expert
- Emphasize Rails system testing and user journey validation
- Test Hotwire, Turbo, and Stimulus integration
- Validate Rails form handling and authentication flows
- Test full-stack feature functionality

### project-orchestrator
- Coordinate comprehensive browser testing strategies
- Plan multi-agent browser testing workflows
- Establish quality gates and success criteria
- Orchestrate cross-browser compatibility testing

## Troubleshooting

### Common Issues
1. **Browser Launch Failures**: Browser engines not installed or accessible
2. **Element Selection Failures**: Elements not found or not interactive
3. **Timeout Issues**: Pages or elements taking longer than expected to load
4. **Network Connectivity**: API endpoints not reachable during testing
5. **Authentication Issues**: Session management and login flow problems

### Resolution Steps
1. Verify Playwright MCP connection: `claude mcp get playwright`
2. Check browser engine installation and accessibility
3. Use explicit waits and reliable element selectors
4. Implement retry mechanisms for flaky operations
5. Capture diagnostic screenshots and console logs
6. Fall back to alternative testing approaches if issues persist

## Documentation Standards

All agents should document Playwright usage in completion reports:
- Which browser automation tools were used and why
- Whether Playwright was available or unavailable
- How browser testing influenced decisions and outcomes
- Screenshots or visual evidence captured during automation
- Recommendations for manual verification if needed
- Cross-browser compatibility notes and findings

## Integration Examples

### Visual Regression Testing
```javascript
// Example: Component visual testing workflow
// 1. Navigate to component library or showcase
// 2. Resize browser to test responsive breakpoints
// 3. Capture screenshots of component in different states
// 4. Compare against baseline images
// 5. Generate visual regression test code
```

### E2E User Journey Testing
```ruby
# Example: Rails user registration and onboarding flow
# 1. Navigate to registration page
# 2. Fill registration form with test data
# 3. Submit form and validate success response
# 4. Navigate through onboarding steps
# 5. Validate final user dashboard state
```

### Performance Testing Integration
```bash
# Example: Page load and interaction performance testing
# 1. Navigate to application with network monitoring
# 2. Measure initial page load performance
# 3. Execute user interactions and measure response times
# 4. Monitor memory usage and JavaScript performance
# 5. Generate performance optimization recommendations
```

This guide should be referenced by all agents when implementing Playwright browser automation to ensure consistent, robust, and effective browser testing across the system.