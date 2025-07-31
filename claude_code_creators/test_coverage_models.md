# Test Coverage Tasks - Agent 1: Model Testing

## Overview
**Focus**: Model layer testing with emphasis on associations, validations, callbacks, and business logic
**Target Coverage**: 95%+ for all models
**Current Coverage**: 0% (despite existing tests - SimpleCov issue to investigate)

## Critical Issue to Fix First
- [ ] **Investigate SimpleCov Configuration**
  - Current tests exist but show 0% coverage
  - Check if `SimpleCov.start` is called before loading Rails
  - Verify test files are requiring test_helper properly
  - May need to run with `RAILS_ENV=test bundle exec rails test`

## Model Test Tasks

### 1. User Model (app/models/user.rb) - PRIORITY: HIGH
**Current**: Has tests but 0% coverage
**File**: `test/models/user_test.rb`

Expand existing tests to cover:
- [ ] Role enum methods (`user?`, `editor?`, `admin?`)
- [ ] Token generation methods:
  - [ ] `generates_token_for :password_reset`
  - [ ] `generates_token_for :email_confirmation`
- [ ] Email confirmation methods:
  - [ ] `confirm_email!`
  - [ ] `send_confirmation_email`
- [ ] Token finder methods:
  - [ ] `find_by_password_reset_token`
  - [ ] `find_by_email_confirmation_token`
- [ ] Edge cases:
  - [ ] Expired tokens
  - [ ] Invalid tokens
  - [ ] Email normalization edge cases

### 2. Current Model (app/models/current.rb) - PRIORITY: HIGH
**Current**: No test file exists
**Create**: `test/models/current_test.rb`

Test requirements:
- [ ] Thread-safe attribute storage
- [ ] Request-specific data isolation
- [ ] Clearing between requests

### 3. Document Model (app/models/document.rb) - PRIORITY: HIGH
**Current**: Has tests but 0% coverage
**File**: `test/models/document_test.rb`

Additional coverage needed:
- [ ] Version tracking methods
- [ ] Soft delete functionality
- [ ] Sharing permissions
- [ ] Search/filtering scopes
- [ ] File attachment handling
- [ ] Callbacks and validations

### 4. ClaudeSession & ClaudeMessage Models - PRIORITY: HIGH
**Files**: `test/models/claude_session_test.rb`, `test/models/claude_message_test.rb`

Test coverage needed:
- [ ] Message ordering and threading
- [ ] Session state management
- [ ] Token counting
- [ ] Rate limiting logic
- [ ] Streaming support
- [ ] Error handling states

### 5. CloudIntegration Model - PRIORITY: MEDIUM
**File**: `test/models/cloud_integration_test.rb`

Additional tests:
- [ ] OAuth token refresh logic
- [ ] Sync status tracking
- [ ] Provider-specific validations
- [ ] Encryption of sensitive data
- [ ] Expiration handling

### 6. SubAgent Model - PRIORITY: MEDIUM
**File**: `test/models/sub_agent_test.rb`

Expand tests for:
- [ ] State machine transitions
- [ ] Context management
- [ ] Message aggregation
- [ ] Capability validations
- [ ] Performance metrics

### 7. ContextItem Model - PRIORITY: MEDIUM
**File**: `test/models/context_item_test.rb`

Add tests for:
- [ ] Ordering/positioning logic
- [ ] Drag-and-drop reordering
- [ ] Permissions and access control
- [ ] Content type validations
- [ ] Size limitations

### 8. Supporting Models - PRIORITY: LOW
Test remaining models:
- [ ] Session (authentication sessions)
- [ ] Identity (OAuth identities)
- [ ] DocumentVersion
- [ ] SubAgentMessage
- [ ] CloudFile

## Test Helpers to Create

### Factories/Fixtures
```ruby
# test/factories/users.rb
- [ ] Create user factory with traits for roles
- [ ] Create confirmed/unconfirmed user traits
- [ ] Create users with various integrations

# test/factories/documents.rb
- [ ] Create document factory with versions
- [ ] Create shared document traits
- [ ] Create documents with attachments

# test/factories/claude_sessions.rb
- [ ] Create session with messages
- [ ] Create various conversation states
```

### Shared Examples
```ruby
# test/support/shared_examples/
- [ ] Tokenable behavior
- [ ] Soft deletable behavior
- [ ] Orderable behavior
- [ ] Encryptable behavior
```

## Testing Patterns to Follow

1. **Validation Testing**
   ```ruby
   test "validates presence of required fields" do
     model = Model.new
     assert_not model.valid?
     assert_includes model.errors[:field], "can't be blank"
   end
   ```

2. **Association Testing**
   ```ruby
   test "has many associations with proper dependencies" do
     assert_difference ['Model.count', 'Association.count'], -1 do
       model.destroy
     end
   end
   ```

3. **Callback Testing**
   ```ruby
   test "executes callbacks in correct order" do
     model = Model.new
     model.expects(:callback_method).once
     model.save!
   end
   ```

## Success Criteria
- [ ] All model files achieve >95% coverage
- [ ] No model has 0% coverage
- [ ] All business logic is tested
- [ ] Edge cases are covered
- [ ] Test suite runs in <10 seconds

## Notes for Agent
- Start by fixing SimpleCov configuration issue
- Use `bundle exec rails test test/models/model_test.rb` to run individual tests
- Check coverage with `open coverage/index.html` after each test run
- Write descriptive test names that explain the behavior
- Group related tests using nested `describe` blocks or comments