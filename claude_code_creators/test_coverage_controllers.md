# Test Coverage Tasks - Agent 2: Controller Testing

## Overview
**Focus**: Controller action testing, authentication flows, authorization, and request/response cycles
**Target Coverage**: 85%+ for all controllers
**Current Coverage**: 0% (tests exist but not registering coverage)

## Critical Issue to Fix First
- [ ] **Controller tests not executing actions**
  - Tests may only be testing setup/helpers
  - Need to ensure actual HTTP requests are made
  - Verify `get`, `post`, `patch`, `delete` methods are called

## Controller Test Tasks

### 1. SessionsController - PRIORITY: CRITICAL
**File**: `test/controllers/sessions_controller_test.rb`
**Critical for**: Authentication is the foundation

Test all actions and flows:
- [ ] **GET /new**
  - [ ] Renders login form
  - [ ] Redirects if already authenticated
- [ ] **POST /create**
  - [ ] Successful login with confirmed email
  - [ ] Failed login - wrong password
  - [ ] Failed login - unconfirmed email
  - [ ] Rate limiting (10 attempts in 3 minutes)
  - [ ] OAuth identity linking flow
  - [ ] Pending identity in session
- [ ] **DELETE /destroy**
  - [ ] Logs out successfully
  - [ ] Clears session data
- [ ] **OAuth flows**
  - [ ] `/auth/:provider/callback` - new user
  - [ ] `/auth/:provider/callback` - existing user
  - [ ] `/auth/:provider/callback` - linking accounts
  - [ ] `/auth/failure` handling

### 2. UsersController - PRIORITY: HIGH
**File**: `test/controllers/users_controller_test.rb`

Test coverage needed:
- [ ] **GET /users/new**
  - [ ] Renders registration form
  - [ ] Redirects if authenticated
- [ ] **POST /users**
  - [ ] Creates user successfully
  - [ ] Sends confirmation email
  - [ ] Handles validation errors
  - [ ] Prevents duplicate emails
- [ ] **User management** (if applicable)
  - [ ] Index (admin only)
  - [ ] Show (authorization)
  - [ ] Update (own profile only)
  - [ ] Destroy (soft delete)

### 3. DocumentsController - PRIORITY: HIGH
**File**: `test/controllers/documents_controller_test.rb`

Full CRUD + authorization:
- [ ] **Index**
  - [ ] Shows user's documents
  - [ ] Pagination
  - [ ] Search/filtering
  - [ ] Proper scoping by role
- [ ] **Show**
  - [ ] Displays document
  - [ ] Authorization checks
  - [ ] Handles missing documents
- [ ] **New/Create**
  - [ ] Form rendering
  - [ ] Successful creation
  - [ ] Validation errors
  - [ ] File attachments
- [ ] **Edit/Update**
  - [ ] Authorization
  - [ ] Version tracking
  - [ ] Concurrent edit handling
- [ ] **Destroy**
  - [ ] Soft delete
  - [ ] Authorization
  - [ ] Cascade behavior

### 4. ContextItemsController - PRIORITY: HIGH
**File**: `test/controllers/context_items_controller_test.rb`

Test drag-drop and permissions:
- [ ] **Index**
  - [ ] JSON response format
  - [ ] Proper ordering
  - [ ] Filtering by parent
- [ ] **Create**
  - [ ] Via drag-drop
  - [ ] File uploads
  - [ ] Position handling
- [ ] **Update**
  - [ ] Reordering
  - [ ] Content updates
  - [ ] Batch updates
- [ ] **Destroy**
  - [ ] Single item
  - [ ] Cascade effects
  - [ ] Position adjustment

### 5. SubAgentsController - PRIORITY: MEDIUM
**File**: `test/controllers/sub_agents_controller_test.rb`

AI agent management:
- [ ] **Index**
  - [ ] List user's agents
  - [ ] Status filtering
- [ ] **Show**
  - [ ] Agent details
  - [ ] Conversation history
  - [ ] Real-time updates
- [ ] **Create**
  - [ ] New agent setup
  - [ ] Configuration validation
- [ ] **Update**
  - [ ] Settings changes
  - [ ] State transitions
- [ ] **Message handling**
  - [ ] Send message
  - [ ] Receive response
  - [ ] Error handling

### 6. CloudIntegrationsController - PRIORITY: MEDIUM
**File**: `test/controllers/cloud_integrations_controller_test.rb`

OAuth and sync testing:
- [ ] **Index**
  - [ ] Shows connected services
  - [ ] Status indicators
- [ ] **Create** (OAuth flow)
  - [ ] Initiates OAuth
  - [ ] Handles callback
  - [ ] Stores tokens securely
- [ ] **Update**
  - [ ] Refresh tokens
  - [ ] Toggle sync
  - [ ] Update settings
- [ ] **Destroy**
  - [ ] Disconnect service
  - [ ] Clean up data
  - [ ] Revoke tokens

### 7. Supporting Controllers - PRIORITY: LOW
- [ ] **PasswordsController** - reset flow
- [ ] **ProfilesController** - user settings
- [ ] **CloudFilesController** - file browser
- [ ] **SubAgentMessagesController** - message handling
- [ ] **WelcomeController** - public pages

## Authentication & Authorization Testing

### Test Helpers
```ruby
# Ensure these are properly used
- [ ] sign_in_as(user)
- [ ] sign_out
- [ ] assert_redirected_to_login
- [ ] assert_authorized
- [ ] assert_unauthorized
```

### Authorization Patterns
```ruby
test "requires authentication" do
  get :index
  assert_redirected_to new_session_path
end

test "authorizes based on role" do
  sign_in_as(users(:regular))
  get :admin_action
  assert_response :forbidden
end
```

## Request Testing Patterns

### 1. **Success Path**
```ruby
test "creates resource successfully" do
  sign_in_as(@user)
  assert_difference "Resource.count", 1 do
    post resources_path, params: { resource: valid_attributes }
  end
  assert_redirected_to resource_path(Resource.last)
  assert_equal "Resource created", flash[:notice]
end
```

### 2. **Error Handling**
```ruby
test "handles validation errors" do
  sign_in_as(@user)
  post resources_path, params: { resource: invalid_attributes }
  assert_response :unprocessable_entity
  assert_template :new
  assert_not_empty assigns(:resource).errors
end
```

### 3. **Format Testing**
```ruby
test "responds with JSON" do
  sign_in_as(@user)
  get resources_path, as: :json
  assert_response :success
  json = JSON.parse(response.body)
  assert_equal 10, json["resources"].length
end
```

## Integration Test Patterns

### Full Flow Testing
```ruby
# test/integration/user_flow_test.rb
test "complete user journey" do
  # Registration
  get new_user_path
  post users_path, params: { user: attributes }
  
  # Email confirmation
  user = User.last
  get confirm_email_path(token: user.confirmation_token)
  
  # Login
  post session_path, params: { email_address: user.email, password: "password" }
  
  # Use app
  get documents_path
  assert_response :success
end
```

## Performance Considerations
- [ ] Add performance tests for slow actions
- [ ] Test N+1 query prevention
- [ ] Verify caching behavior
- [ ] Test rate limiting

## Success Criteria
- [ ] All controller actions have test coverage
- [ ] Authorization is tested for every action
- [ ] Error cases are covered
- [ ] Response formats (HTML/JSON) are tested
- [ ] No controller below 85% coverage

## Notes for Agent
- Start with SessionsController - it's critical
- Use `assigns(:variable)` to test instance variables
- Test both HTML and JSON responses where applicable
- Verify flash messages and redirects
- Test edge cases like missing records
- Use `follow_redirect!` for integration tests