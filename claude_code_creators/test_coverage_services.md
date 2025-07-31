# Test Coverage Tasks - Agent 4: Service Layer Testing

## Overview
**Focus**: Service objects, external API integrations, business logic, error handling
**Target Coverage**: 90%+ for all services
**Current Coverage**: ClaudeService (0%), BaseService (36.21%), Others (N/A)

## Critical Setup Required
- [ ] **Configure VCR or WebMock for API mocking**
  - Add `gem 'vcr'` and `gem 'webmock'` to Gemfile
  - Configure VCR cassettes for API recordings
  - Set up API key filtering
  - Create shared contexts for mocked responses

## Service Test Tasks

### 1. ClaudeService (app/services/claude_service.rb) - PRIORITY: CRITICAL
**File**: `test/services/claude_service_test.rb`
**Current**: 0% coverage (tests exist but not covering code)

Test all Claude AI interactions:
- [ ] **Message sending**
  - [ ] Successful API call
  - [ ] Message formatting
  - [ ] Context inclusion
  - [ ] Token counting
- [ ] **Streaming responses**
  - [ ] SSE event parsing
  - [ ] Chunk aggregation
  - [ ] Error mid-stream
  - [ ] Connection timeouts
- [ ] **Error handling**
  - [ ] Rate limiting (429)
  - [ ] API errors (500, 503)
  - [ ] Network failures
  - [ ] Invalid API key
  - [ ] Token limit exceeded
- [ ] **Context management**
  - [ ] System prompts
  - [ ] Conversation history
  - [ ] File attachments
  - [ ] Token optimization
- [ ] **Response parsing**
  - [ ] JSON response handling
  - [ ] Markdown processing
  - [ ] Code block extraction

### 2. CloudServices::NotionService - PRIORITY: HIGH
**Create**: `test/services/cloud_services/notion_service_test.rb`

Full test coverage needed:
- [ ] **Authentication**
  - [ ] OAuth flow
  - [ ] Token refresh
  - [ ] Token expiration
- [ ] **Page operations**
  - [ ] List pages
  - [ ] Get page content
  - [ ] Create page
  - [ ] Update page
  - [ ] Search pages
- [ ] **Database operations**
  - [ ] List databases
  - [ ] Query database
  - [ ] Create entry
  - [ ] Update entry
- [ ] **Block operations**
  - [ ] Read blocks
  - [ ] Create blocks
  - [ ] Update blocks
  - [ ] Delete blocks
- [ ] **File handling**
  - [ ] Upload files
  - [ ] Download content
  - [ ] Handle attachments
- [ ] **Error cases**
  - [ ] Permission denied
  - [ ] Resource not found
  - [ ] API rate limits
  - [ ] Network failures

### 3. CloudServices::DropboxService - PRIORITY: HIGH
**Create**: `test/services/cloud_services/dropbox_service_test.rb`

Complete test suite:
- [ ] **Authentication**
  - [ ] OAuth2 flow
  - [ ] Token refresh
  - [ ] Revocation handling
- [ ] **File operations**
  - [ ] List folder contents
  - [ ] Download file
  - [ ] Upload file
  - [ ] Move/rename file
  - [ ] Delete file
  - [ ] Create folder
- [ ] **Sync operations**
  - [ ] Get latest cursor
  - [ ] List folder continue
  - [ ] Handle deletions
  - [ ] Conflict resolution
- [ ] **Sharing**
  - [ ] Create shared link
  - [ ] List shared links
  - [ ] Revoke access
- [ ] **Large file handling**
  - [ ] Upload sessions
  - [ ] Chunked downloads
  - [ ] Progress callbacks
- [ ] **Error handling**
  - [ ] Quota exceeded
  - [ ] Path not found
  - [ ] Permission errors
  - [ ] Network interruptions

### 4. CloudServices::GoogleDriveService - PRIORITY: HIGH
**File**: `test/services/cloud_services/google_drive_service_test.rb`
**Current**: 0% coverage

Expand existing tests:
- [ ] **Authentication**
  - [ ] OAuth2 with Google
  - [ ] Token refresh
  - [ ] Scope management
- [ ] **File operations**
  - [ ] List files
  - [ ] Get file metadata
  - [ ] Download file
  - [ ] Upload file
  - [ ] Update file
  - [ ] Trash/delete file
- [ ] **Folder operations**
  - [ ] Create folder
  - [ ] List folder contents
  - [ ] Move items
  - [ ] Copy items
- [ ] **Permissions**
  - [ ] Share file
  - [ ] List permissions
  - [ ] Update permissions
  - [ ] Remove permissions
- [ ] **Search and queries**
  - [ ] Search by name
  - [ ] Filter by type
  - [ ] Sort results
  - [ ] Pagination
- [ ] **Special features**
  - [ ] Google Docs export
  - [ ] OCR for images
  - [ ] Revision history
  - [ ] Comments

### 5. CloudServices::BaseService - PRIORITY: MEDIUM
**File**: `test/services/cloud_services/base_service_test.rb`
**Current**: 36.21% coverage

Increase coverage:
- [ ] **Common functionality**
  - [ ] HTTP client setup
  - [ ] Authentication helpers
  - [ ] Error handling
  - [ ] Retry logic
  - [ ] Rate limiting
- [ ] **Shared behaviors**
  - [ ] Token storage
  - [ ] Token refresh
  - [ ] API versioning
  - [ ] Response parsing

### 6. SubAgentService - PRIORITY: MEDIUM
**File**: `test/services/sub_agent_service_test.rb`

Ensure coverage of:
- [ ] Agent creation
- [ ] Message routing
- [ ] Context building
- [ ] Response handling
- [ ] Error recovery
- [ ] State management

## Testing Patterns for Services

### 1. VCR Setup
```ruby
# test/test_helper.rb
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  config.filter_sensitive_data('<TOKEN>') { ENV['OAUTH_TOKEN'] }
end
```

### 2. API Mocking Pattern
```ruby
test "handles API errors gracefully" do
  VCR.use_cassette("claude_service/api_error") do
    service = ClaudeService.new(api_key: "test_key")
    
    # Mock 429 rate limit error
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 429, body: { error: "Rate limited" }.to_json)
    
    assert_raises(ClaudeService::RateLimitError) do
      service.send_message("Hello")
    end
  end
end
```

### 3. Streaming Response Testing
```ruby
test "processes streaming responses" do
  service = ClaudeService.new
  chunks = []
  
  VCR.use_cassette("claude_service/streaming") do
    service.stream_message("Hello") do |chunk|
      chunks << chunk
    end
  end
  
  assert_equal 5, chunks.length
  assert_equal "Hello! How can I help?", chunks.join
end
```

### 4. OAuth Flow Testing
```ruby
test "refreshes expired token" do
  service = CloudServices::GoogleDriveService.new(integration: integration)
  integration.update!(expires_at: 1.hour.ago)
  
  VCR.use_cassette("google_drive/token_refresh") do
    files = service.list_files
    
    assert_not_empty files
    assert integration.reload.expires_at > Time.current
  end
end
```

### 5. Error Handling Tests
```ruby
test "retries transient failures" do
  service = CloudServices::NotionService.new
  call_count = 0
  
  service.stub :make_request, ->(_) {
    call_count += 1
    raise Net::ReadTimeout if call_count < 3
    { "results" => [] }
  } do
    result = service.list_pages
    
    assert_equal 3, call_count
    assert_equal [], result
  end
end
```

### 6. File Upload Testing
```ruby
test "uploads large files in chunks" do
  service = CloudServices::DropboxService.new
  file = fixture_file_upload("large_file.pdf", "application/pdf")
  
  VCR.use_cassette("dropbox/chunked_upload") do
    progress = []
    
    result = service.upload_file(file, "/test/large.pdf") do |bytes|
      progress << bytes
    end
    
    assert_equal file.size, progress.sum
    assert_equal "/test/large.pdf", result["path_display"]
  end
end
```

## Test Data and Fixtures

### API Response Fixtures
```ruby
# test/fixtures/api_responses/claude_success.json
# test/fixtures/api_responses/notion_pages.json
# test/fixtures/api_responses/dropbox_folder.json
# test/fixtures/api_responses/google_drive_files.json
```

### Mock Helpers
```ruby
# test/support/service_test_helpers.rb
def mock_claude_response(content:, role: "assistant")
  {
    "id" => "msg_123",
    "content" => [{ "type" => "text", "text" => content }],
    "role" => role
  }
end

def mock_oauth_token(expires_in: 3600)
  {
    "access_token" => "mock_token",
    "refresh_token" => "mock_refresh",
    "expires_in" => expires_in
  }
end
```

## Performance and Integration Tests

### Rate Limiting
```ruby
test "respects rate limits" do
  service = ClaudeService.new
  
  10.times do
    VCR.use_cassette("claude_service/rate_limit_test") do
      service.send_message("Test")
    end
  end
  
  assert service.rate_limiter.current_count <= 10
end
```

### Concurrent Requests
```ruby
test "handles concurrent file uploads" do
  service = CloudServices::GoogleDriveService.new
  files = 5.times.map { |i| "file_#{i}.txt" }
  
  results = files.map do |file|
    Thread.new do
      VCR.use_cassette("google_drive/concurrent_#{file}") do
        service.upload_file(file)
      end
    end
  end.map(&:value)
  
  assert_equal 5, results.compact.length
end
```

## Success Criteria
- [ ] All services achieve >90% coverage
- [ ] External APIs are properly mocked
- [ ] Error cases are thoroughly tested
- [ ] Performance characteristics verified
- [ ] No flaky tests due to network calls

## Notes for Agent
- Set up VCR/WebMock first
- Record real API responses when possible
- Test both success and failure paths
- Mock time-sensitive operations
- Ensure API keys are filtered in recordings
- Test rate limiting and retries