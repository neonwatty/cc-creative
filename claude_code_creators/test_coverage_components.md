# Test Coverage Tasks - Agent 3: ViewComponent Testing

## Overview
**Focus**: ViewComponent rendering, props, slots, JavaScript interactions, and accessibility
**Target Coverage**: 90%+ for all components
**Current Coverage**: 0% (critical issue - tests exist but don't register coverage)

## Critical Issue to Fix First
- [ ] **ViewComponent tests not registering coverage**
  - Ensure using `render_inline(component).to_html`
  - May need ViewComponent test helpers
  - Check if components are being loaded in test environment
  - Verify `require "view_component/test_helpers"` in test files

## Component Test Tasks

### Components WITH Existing Tests (Fix Coverage)

#### 1. CloudProviderComponent - PRIORITY: HIGH
**File**: `test/components/cloud_provider_component_test.rb`
**Current**: Tests exist but 0% coverage

Fix and expand:
- [ ] Ensure `render_inline` is used correctly
- [ ] Test all provider types (Google, Dropbox, Notion)
- [ ] Test connected vs disconnected states
- [ ] Test OAuth initiation links
- [ ] Test sync status display
- [ ] Test error states (expired tokens)
- [ ] Test file count display
- [ ] Test last sync time formatting

#### 2. CloudSyncStatusComponent - PRIORITY: HIGH  
**File**: `test/components/cloud_sync_status_component_test.rb`

Fix and expand:
- [ ] Global sync status rendering
- [ ] Multiple integration handling
- [ ] Sync in progress states
- [ ] Error state display
- [ ] Empty state (no integrations)
- [ ] Refresh button functionality
- [ ] Real-time update hooks

#### 3. ContextItemPreviewComponent - PRIORITY: HIGH
**File**: `test/components/context_item_preview_component_test.rb`

Fix and expand:
- [ ] Different content type rendering
- [ ] File preview generation
- [ ] Image thumbnail display
- [ ] Code syntax highlighting
- [ ] Truncation for long content
- [ ] Loading states
- [ ] Error handling

#### 4. ContextSidebarComponent - PRIORITY: HIGH
**File**: `test/components/context_sidebar_component_test.rb`

Fix and expand:
- [ ] Item list rendering
- [ ] Drag-drop zones
- [ ] Search functionality
- [ ] Filter controls
- [ ] Empty states
- [ ] Loading states
- [ ] Keyboard navigation

### Components WITHOUT Tests (Create New)

#### 5. CloudFileBrowserComponent - PRIORITY: MEDIUM
**Create**: `test/components/cloud_file_browser_component_test.rb`

Test requirements:
- [ ] File tree rendering
- [ ] Folder navigation
- [ ] File selection (single/multi)
- [ ] Search within files
- [ ] Sort options
- [ ] Grid/list view toggle
- [ ] Loading states
- [ ] Empty folders
- [ ] Error states

#### 6. DocumentLayoutComponent - PRIORITY: MEDIUM
**Create**: `test/components/document_layout_component_test.rb`

Test requirements:
- [ ] Layout structure
- [ ] Sidebar toggle
- [ ] Responsive behavior
- [ ] Theme switching
- [ ] Navigation elements
- [ ] Content area sizing
- [ ] Mobile menu

#### 7. OnboardingModalComponent - PRIORITY: MEDIUM
**Create**: `test/components/onboarding_modal_component_test.rb`

Test requirements:
- [ ] Step progression
- [ ] Form validation
- [ ] Skip functionality
- [ ] Progress indicators
- [ ] Completion handling
- [ ] Persistence (don't show again)
- [ ] Responsive design

#### 8. WidgetDropZoneComponent - PRIORITY: HIGH
**Create**: `test/components/widget_drop_zone_component_test.rb`

Test requirements:
- [ ] Drag hover states
- [ ] Drop acceptance
- [ ] File type validation
- [ ] Multiple file handling
- [ ] Upload progress
- [ ] Error messages
- [ ] Success feedback

#### 9. Additional Components - PRIORITY: LOW
Create tests for:
- [ ] CloudFileItemComponent
- [ ] EditorComponent
- [ ] PresenceIndicatorComponent
- [ ] SidebarNavigationComponent
- [ ] SubAgentConversationComponent
- [ ] SubAgentMergeComponent
- [ ] SubAgentSidebarComponent
- [ ] ThemeToggleComponent

## ViewComponent Testing Patterns

### 1. Basic Rendering Test
```ruby
test "renders with default props" do
  component = CloudProviderComponent.new(provider: "google")
  render_inline(component)
  
  assert_selector "div.cloud-provider"
  assert_text "Google Drive"
end
```

### 2. Props and State Testing
```ruby
test "displays connected state correctly" do
  integration = cloud_integrations(:google_connected)
  component = CloudProviderComponent.new(
    provider: "google",
    integration: integration
  )
  
  render_inline(component)
  
  assert_selector ".status-connected"
  assert_text "Connected"
  assert_no_selector "a[href*='auth/google']"
end
```

### 3. Slot Testing
```ruby
test "renders with custom actions slot" do
  component = DocumentLayoutComponent.new(title: "Test")
  
  render_inline(component) do |c|
    c.with_actions { "<button>Custom Action</button>".html_safe }
  end
  
  assert_selector "button", text: "Custom Action"
end
```

### 4. JavaScript Interaction Testing
```ruby
test "initializes Stimulus controller" do
  component = WidgetDropZoneComponent.new(target: "files")
  render_inline(component)
  
  assert_selector "[data-controller='drop-zone']"
  assert_selector "[data-drop-zone-target='dropArea']"
  assert_selector "[data-action='drop->drop-zone#handleDrop']"
end
```

### 5. Accessibility Testing
```ruby
test "meets accessibility standards" do
  component = OnboardingModalComponent.new(step: 1)
  render_inline(component)
  
  # ARIA attributes
  assert_selector "[role='dialog']"
  assert_selector "[aria-labelledby]"
  assert_selector "[aria-describedby]"
  
  # Keyboard navigation
  assert_selector "[tabindex='0']"
  
  # Screen reader text
  assert_selector ".sr-only", text: "Step 1 of 5"
end
```

### 6. Conditional Rendering
```ruby
test "shows loading state" do
  component = CloudFileBrowserComponent.new(
    provider: "google",
    loading: true
  )
  
  render_inline(component)
  
  assert_selector ".spinner"
  assert_text "Loading files..."
  assert_no_selector ".file-list"
end
```

## Component Test Helpers

### Create Shared Test Setup
```ruby
# test/components/support/component_test_helper.rb
module ComponentTestHelper
  def render_and_assert_component(component)
    render_inline(component)
    assert_selector ".#{component.class.name.underscore.dasherize}"
  end
  
  def assert_stimulus_controller(name)
    assert_selector "[data-controller='#{name}']"
  end
end
```

### Mock Data Builders
```ruby
# test/components/support/mock_builders.rb
def build_mock_integration(provider:, connected: true)
  OpenStruct.new(
    provider: provider,
    connected?: connected,
    expires_at: 1.week.from_now,
    last_synced_at: 1.hour.ago
  )
end
```

## CSS and Styling Tests

### Responsive Behavior
```ruby
test "adapts to mobile viewport" do
  component = SidebarNavigationComponent.new
  
  # Test with mobile viewport
  render_inline(component)
  
  assert_selector ".mobile-menu-toggle"
  assert_selector ".sidebar.collapsed-mobile"
end
```

### Theme Testing
```ruby
test "applies dark theme classes" do
  component = ThemeToggleComponent.new(theme: "dark")
  render_inline(component)
  
  assert_selector ".dark-theme"
  assert_selector "[data-theme='dark']"
end
```

## Performance Considerations
- [ ] Test component render time
- [ ] Verify no N+1 queries in components
- [ ] Test large dataset rendering
- [ ] Verify lazy loading behavior

## Success Criteria
- [ ] All components have >90% coverage
- [ ] No component shows 0% coverage
- [ ] All props and slots are tested
- [ ] Accessibility standards are verified
- [ ] JavaScript interactions are tested
- [ ] Error states are handled

## Notes for Agent
- Fix coverage registration issue first
- Use `assert_selector` for DOM queries
- Test both happy path and edge cases
- Include accessibility assertions
- Test responsive behavior where applicable
- Verify Stimulus controller initialization