# Test Coverage Tasks - Agent 6: System & Integration Testing

## Overview
**Focus**: End-to-end flows, browser testing, integration scenarios, and completing skipped tests
**Target Coverage**: Full user journeys, real browser interactions, API integrations
**Current Status**: 4 skipped tests need completion, limited system tests

## Priority 1: Fix Skipped Tests

### 1. SubAgentConversationComponent - Context Display
**File**: `test/components/sub_agent_conversation_component_test.rb:172`
**Skip Reason**: "Context display not implemented in current template"

Fix requirements:
- [ ] Implement context display in component template
- [ ] Add rendering logic for context items
- [ ] Update test to verify context rendering
- [ ] Test different context types (files, documents, etc.)

### 2. ClaudeIntegrationTest - Streaming Support
**File**: `test/integration/claude_integration_test.rb:167`
**Skip Reason**: "Streaming implementation pending"

Fix requirements:
- [ ] Implement SSE streaming in Claude integration
- [ ] Add ActionCable broadcast for chunks
- [ ] Test chunk aggregation
- [ ] Handle stream interruptions
- [ ] Verify complete message assembly

### 3. ProfilesController - Profile Picture Upload
**File**: `test/controllers/profiles_controller_test.rb:147`
**Skip Reason**: "Profile picture upload not yet implemented"

Fix requirements:
- [ ] Add Active Storage for profile pictures
- [ ] Implement upload endpoint
- [ ] Add image processing (resize, format)
- [ ] Test file type validation
- [ ] Test size limits

### 4. ContextSidebarComponent - Search Highlighting
**File**: `test/components/context_sidebar_component_test.rb:346`
**Skip Reason**: "Search highlighting is handled by the partial rendering"

Fix requirements:
- [ ] Implement search highlighting in partials
- [ ] Add highlight helper method
- [ ] Test search term highlighting
- [ ] Handle multiple match highlighting
- [ ] Test special character escaping

## Priority 2: System Tests (Capybara)

### 1. User Authentication Flow
**Create**: `test/system/authentication_flow_test.rb`

Complete user journey:
- [ ] **Registration**
  - [ ] Visit homepage
  - [ ] Click sign up
  - [ ] Fill registration form
  - [ ] Submit and verify email sent
  - [ ] Confirm email via link
  - [ ] Verify account activated
- [ ] **Login**
  - [ ] Standard email/password
  - [ ] OAuth login (Google, GitHub)
  - [ ] Remember me functionality
  - [ ] Forgot password flow
  - [ ] Two-factor auth (if implemented)
- [ ] **Session management**
  - [ ] Logout functionality
  - [ ] Session timeout
  - [ ] Multiple device handling
  - [ ] Security notifications

### 2. Document Management Flow
**Create**: `test/system/document_management_test.rb`

Full document lifecycle:
- [ ] **Creation**
  - [ ] New document button
  - [ ] Title and content entry
  - [ ] Auto-save functionality
  - [ ] File attachments
  - [ ] Rich text formatting
- [ ] **Editing**
  - [ ] Real-time collaboration
  - [ ] Version history
  - [ ] Conflict resolution
  - [ ] Undo/redo
  - [ ] Keyboard shortcuts
- [ ] **Organization**
  - [ ] Folder structure
  - [ ] Tags and categories
  - [ ] Search functionality
  - [ ] Sort and filter
  - [ ] Bulk operations
- [ ] **Sharing**
  - [ ] Share dialog
  - [ ] Permission levels
  - [ ] Public links
  - [ ] Revoke access
  - [ ] Activity tracking

### 3. Claude AI Integration Flow
**Create**: `test/system/claude_ai_flow_test.rb`

AI assistant interaction:
- [ ] **Conversation**
  - [ ] Start new chat
  - [ ] Send message
  - [ ] Receive response
  - [ ] View typing indicator
  - [ ] Stop generation
- [ ] **Context management**
  - [ ] Add files to context
  - [ ] Remove context items
  - [ ] Drag-drop files
  - [ ] Context preview
  - [ ] Token count display
- [ ] **Sub-agents**
  - [ ] Create sub-agent
  - [ ] Configure capabilities
  - [ ] Switch between agents
  - [ ] Merge conversations
  - [ ] Export history

### 4. Cloud Integration Flow
**Create**: `test/system/cloud_integration_test.rb`

Cloud service connections:
- [ ] **OAuth setup**
  - [ ] Connect Google Drive
  - [ ] Connect Dropbox
  - [ ] Connect Notion
  - [ ] Handle OAuth errors
  - [ ] Revoke connections
- [ ] **File browser**
  - [ ] Browse cloud files
  - [ ] Search across services
  - [ ] Import files
  - [ ] Sync status
  - [ ] Conflict handling
- [ ] **Automatic sync**
  - [ ] Enable/disable sync
  - [ ] Sync frequency
  - [ ] Selective sync
  - [ ] Sync notifications
  - [ ] Error recovery

### 5. Real-time Features
**Create**: `test/system/realtime_features_test.rb`

WebSocket/ActionCable features:
- [ ] **Presence**
  - [ ] See who's online
  - [ ] User avatars
  - [ ] Activity status
  - [ ] Cursor positions
- [ ] **Collaboration**
  - [ ] Live typing
  - [ ] Simultaneous editing
  - [ ] Change notifications
  - [ ] Conflict markers
- [ ] **Notifications**
  - [ ] Desktop notifications
  - [ ] In-app alerts
  - [ ] Email preferences
  - [ ] Notification center

## Priority 3: Integration Tests

### 1. API Integration Tests
**Create**: `test/integration/api_integration_test.rb`

External API interactions:
- [ ] **Claude API**
  - [ ] Message sending
  - [ ] Token limits
  - [ ] Error handling
  - [ ] Rate limiting
  - [ ] Failover
- [ ] **Cloud APIs**
  - [ ] Authentication flows
  - [ ] Data synchronization
  - [ ] Error recovery
  - [ ] Quota handling
  - [ ] Network resilience

### 2. Background Job Integration
**Create**: `test/integration/background_job_integration_test.rb`

Job processing flows:
- [ ] **File processing**
  - [ ] Upload triggers job
  - [ ] Processing updates UI
  - [ ] Completion notification
  - [ ] Error handling
- [ ] **Sync operations**
  - [ ] Scheduled syncs
  - [ ] Manual sync trigger
  - [ ] Progress tracking
  - [ ] Conflict resolution

### 3. Security Integration Tests
**Create**: `test/integration/security_test.rb`

Security scenarios:
- [ ] **Authentication**
  - [ ] Session hijacking prevention
  - [ ] CSRF protection
  - [ ] XSS prevention
  - [ ] SQL injection tests
- [ ] **Authorization**
  - [ ] Role-based access
  - [ ] Resource permissions
  - [ ] API token scoping
  - [ ] Rate limiting

## System Test Patterns

### 1. Capybara Setup
```ruby
# test/application_system_test_case.rb
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  
  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Welcome back"
  end
end
```

### 2. JavaScript Interaction Testing
```ruby
test "drag and drop file upload" do
  sign_in_as(users(:alice))
  visit documents_path
  
  # Simulate drag and drop
  drop_zone = find("[data-drop-zone]")
  drop_zone.drop(file_fixture_path("test.pdf"))
  
  assert_text "Uploading test.pdf..."
  assert_text "Upload complete", wait: 10
end
```

### 3. Real-time Testing
```ruby
test "shows real-time presence" do
  # User 1 signs in
  using_session(:user1) do
    sign_in_as(users(:alice))
    visit document_path(documents(:shared))
  end
  
  # User 2 signs in
  using_session(:user2) do
    sign_in_as(users(:bob))
    visit document_path(documents(:shared))
    
    # Should see User 1's presence
    within(".presence-list") do
      assert_text "Alice"
    end
  end
  
  # User 1 should see User 2
  using_session(:user1) do
    within(".presence-list") do
      assert_text "Bob"
    end
  end
end
```

### 4. Mobile Responsive Testing
```ruby
test "mobile navigation works" do
  # Set mobile viewport
  page.driver.browser.manage.window.resize_to(375, 667)
  
  sign_in_as(users(:charlie))
  visit root_path
  
  # Mobile menu should be visible
  assert_selector(".mobile-menu-toggle")
  
  # Open mobile menu
  find(".mobile-menu-toggle").click
  assert_selector(".mobile-menu.open")
  
  # Navigate via mobile menu
  within(".mobile-menu") do
    click_link "Documents"
  end
  
  assert_current_path documents_path
end
```

### 5. File Upload Testing
```ruby
test "uploads multiple files" do
  sign_in_as(users(:alice))
  visit new_document_path
  
  attach_file("Files", [
    file_fixture_path("doc1.pdf"),
    file_fixture_path("doc2.jpg"),
    file_fixture_path("doc3.txt")
  ])
  
  click_button "Upload"
  
  assert_text "3 files uploaded"
  assert_selector(".file-preview", count: 3)
end
```

### 6. Performance Testing
```ruby
test "loads large document list efficiently" do
  user = users(:alice)
  create_list(:document, 100, user: user)
  
  sign_in_as(user)
  
  time = Benchmark.realtime do
    visit documents_path
  end
  
  assert time < 3.seconds
  assert_selector(".document-item", count: 20) # Pagination
end
```

## Browser Compatibility Tests

### Cross-browser Testing
```ruby
# Run with different browsers
[:chrome, :firefox, :safari].each do |browser|
  test "works in #{browser}" do
    Capybara.current_driver = browser
    
    visit root_path
    assert_text "Welcome"
    # Core functionality tests
  end
end
```

## Success Criteria
- [ ] All 4 skipped tests are fixed
- [ ] Major user flows have system tests
- [ ] JavaScript interactions are tested
- [ ] Real-time features are verified
- [ ] Mobile experience is tested
- [ ] Cross-browser compatibility confirmed
- [ ] Performance benchmarks met

## Notes for Agent
- Fix skipped tests first - they indicate missing features
- Use Capybara's waiting helpers for async operations
- Test both happy paths and error scenarios
- Use `save_screenshot` for debugging failures
- Run system tests separately: `rails test:system`
- Consider using VCR for external API calls in system tests
- Test keyboard navigation and accessibility