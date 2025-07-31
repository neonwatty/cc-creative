# Test Coverage Tasks - Agent 5: Jobs & Channels Testing

## Overview
**Focus**: Background jobs, ActionCable channels, real-time features, async processing
**Target Coverage**: 85%+ for all jobs and channels
**Current Coverage**: Jobs (0%), Channels (SubAgentChannel 28.57%, others 0% or missing)

## Critical Setup Required
- [ ] **Configure ActiveJob test helpers**
  - Ensure `include ActiveJob::TestHelper` in tests
  - Set up test queue adapter
  - Configure ActionCable test helpers
- [ ] **Fix coverage tracking for jobs**
  - Jobs may run in separate process
  - Ensure SimpleCov merges results

## Job Test Tasks

### 1. CloudFileSyncJob - PRIORITY: HIGH
**File**: `test/jobs/cloud_file_sync_job_test.rb`
**Current**: 0% coverage despite existing tests

Test comprehensive sync behavior:
- [ ] **Successful sync**
  - [ ] Single file sync
  - [ ] Batch file sync
  - [ ] Different file types
  - [ ] Large files
- [ ] **Sync strategies**
  - [ ] Full sync
  - [ ] Incremental sync
  - [ ] Conflict resolution
  - [ ] Deletion propagation
- [ ] **Error handling**
  - [ ] Network failures
  - [ ] API errors
  - [ ] Rate limiting
  - [ ] Invalid credentials
- [ ] **Job behavior**
  - [ ] Retry on failure
  - [ ] Backoff strategy
  - [ ] Dead letter queue
  - [ ] Idempotency
- [ ] **Performance**
  - [ ] Batch processing
  - [ ] Memory usage
  - [ ] Concurrent syncs
  - [ ] Progress tracking

### 2. CloudFileImportJob - PRIORITY: HIGH
**File**: `test/jobs/cloud_file_import_job_test.rb`
**Current**: 0% coverage

Test import pipeline:
- [ ] **File processing**
  - [ ] Text extraction
  - [ ] Metadata parsing
  - [ ] Format conversion
  - [ ] Encoding detection
- [ ] **Content types**
  - [ ] Documents (PDF, DOCX)
  - [ ] Spreadsheets
  - [ ] Images (with OCR)
  - [ ] Code files
  - [ ] Archives
- [ ] **Import stages**
  - [ ] Download from cloud
  - [ ] Process content
  - [ ] Store locally
  - [ ] Index for search
- [ ] **Error scenarios**
  - [ ] Corrupted files
  - [ ] Unsupported formats
  - [ ] Size limits
  - [ ] Timeout handling
- [ ] **Notifications**
  - [ ] Progress updates
  - [ ] Completion notice
  - [ ] Error alerts
  - [ ] ActionCable broadcasts

### 3. ClaudeInteractionJob - PRIORITY: CRITICAL
**File**: `test/jobs/claude_interaction_job_test.rb`
**Current**: 0% coverage

Test AI interaction pipeline:
- [ ] **Message processing**
  - [ ] Queue message
  - [ ] Build context
  - [ ] Call Claude API
  - [ ] Process response
  - [ ] Store result
- [ ] **Streaming support**
  - [ ] Stream chunks
  - [ ] Aggregate response
  - [ ] Broadcast updates
  - [ ] Handle interruptions
- [ ] **Context management**
  - [ ] Load conversation history
  - [ ] Include relevant files
  - [ ] Token limit handling
  - [ ] Context prioritization
- [ ] **Error recovery**
  - [ ] API failures
  - [ ] Rate limits
  - [ ] Timeout handling
  - [ ] Partial responses
- [ ] **Concurrency**
  - [ ] Queue ordering
  - [ ] User isolation
  - [ ] Resource limits
  - [ ] Priority handling

## Channel Test Tasks

### 4. PresenceChannel - PRIORITY: HIGH
**Create**: `test/channels/presence_channel_test.rb`

Test real-time presence:
- [ ] **Connection lifecycle**
  - [ ] Subscribe to channel
  - [ ] Authenticate user
  - [ ] Track presence
  - [ ] Handle disconnect
- [ ] **Presence tracking**
  - [ ] User appears
  - [ ] User disappears
  - [ ] Timeout handling
  - [ ] Multiple connections
- [ ] **Broadcasting**
  - [ ] Notify others of join
  - [ ] Notify others of leave
  - [ ] Status updates
  - [ ] Activity indicators
- [ ] **Room management**
  - [ ] Document-specific presence
  - [ ] User limits
  - [ ] Permission checks
  - [ ] Clean up on empty

### 5. CloudSyncChannel - PRIORITY: MEDIUM
**Create**: `test/channels/cloud_sync_channel_test.rb`

Test sync notifications:
- [ ] **Sync events**
  - [ ] Sync started
  - [ ] Progress updates
  - [ ] Sync completed
  - [ ] Error notifications
- [ ] **File events**
  - [ ] File added
  - [ ] File updated
  - [ ] File deleted
  - [ ] Batch updates
- [ ] **Integration status**
  - [ ] Connected
  - [ ] Disconnected
  - [ ] Token expired
  - [ ] Quota warnings
- [ ] **Filtering**
  - [ ] User-specific events
  - [ ] Provider filtering
  - [ ] Event throttling

### 6. SubAgentChannel - PRIORITY: HIGH
**File**: `test/channels/sub_agent_channel_test.rb`
**Current**: 28.57% coverage

Expand coverage:
- [ ] **Message flow**
  - [ ] Send user message
  - [ ] Receive AI response
  - [ ] Stream chunks
  - [ ] Complete response
- [ ] **Agent states**
  - [ ] Thinking
  - [ ] Processing
  - [ ] Responding
  - [ ] Error state
- [ ] **Context updates**
  - [ ] Add context item
  - [ ] Remove context
  - [ ] Update context
  - [ ] Clear context
- [ ] **Multi-agent**
  - [ ] Agent handoff
  - [ ] Merge responses
  - [ ] Coordinate agents

## Testing Patterns for Async

### 1. Job Testing Pattern
```ruby
test "performs file sync successfully" do
  integration = cloud_integrations(:google_drive)
  
  assert_enqueued_with(job: CloudFileSyncJob, args: [integration]) do
    CloudFileSyncJob.perform_later(integration)
  end
  
  perform_enqueued_jobs do
    CloudFileSyncJob.perform_later(integration)
  end
  
  assert_equal "completed", integration.reload.sync_status
  assert_not_nil integration.last_synced_at
end
```

### 2. Job Error Handling
```ruby
test "retries on transient failure" do
  integration = cloud_integrations(:dropbox)
  
  # Mock failure on first attempt
  CloudServices::DropboxService.any_instance
    .stubs(:list_files)
    .raises(Net::ReadTimeout)
    .then.returns([])
  
  assert_performed_jobs 2 do
    CloudFileSyncJob.perform_later(integration)
  end
  
  assert_equal "completed", integration.reload.sync_status
end
```

### 3. Channel Connection Testing
```ruby
test "subscribes to presence channel" do
  connect user: users(:alice)
  
  subscribe room_id: documents(:shared).id
  
  assert subscription.confirmed?
  assert_broadcast_on("presence:#{documents(:shared).id}", 
    type: "user_joined", 
    user_id: users(:alice).id
  )
end
```

### 4. Channel Broadcasting
```ruby
test "broadcasts sync progress" do
  channel = CloudSyncChannel.new
  integration = cloud_integrations(:notion)
  
  assert_broadcast_on("cloud_sync:#{users(:bob).id}", 
    type: "sync_progress",
    integration_id: integration.id,
    progress: 50
  ) do
    channel.broadcast_progress(integration, 50)
  end
end
```

### 5. Streaming Response Testing
```ruby
test "streams AI response chunks" do
  connect user: users(:charlie)
  subscribe agent_id: sub_agents(:assistant).id
  
  chunks = ["Hello", ", how", " can", " I", " help?"]
  
  chunks.each_with_index do |chunk, index|
    assert_broadcast_on(subscription, 
      type: "response_chunk",
      content: chunk,
      index: index
    ) do
      SubAgentChannel.broadcast_chunk(
        sub_agents(:assistant), 
        chunk, 
        index
      )
    end
  end
end
```

### 6. Job Queue Testing
```ruby
test "processes jobs in priority order" do
  urgent = ClaudeInteractionJob.set(priority: 1)
    .perform_later(message: "Urgent")
  normal = ClaudeInteractionJob.set(priority: 5)
    .perform_later(message: "Normal")
  
  performed_jobs = []
  
  perform_enqueued_jobs do
    performed_jobs = ActiveJob::Base.queue_adapter.performed_jobs
  end
  
  assert_equal "Urgent", performed_jobs.first[:args].first[:message]
end
```

## ActionCable Test Helpers

### Connection Stubs
```ruby
# test/channels/application_cable/connection_test.rb
test "connects with valid session" do
  connect params: { session_id: sessions(:valid).id }
  assert_equal users(:alice).id, connection.current_user.id
end

test "rejects without session" do
  assert_reject_connection { connect }
end
```

### Channel Stubs
```ruby
def stub_connection(user:)
  stub_connection current_user: user
end

def subscribe_and_assert(channel, **params)
  subscribe **params
  assert subscription.confirmed?
  subscription
end
```

## Performance Testing

### Job Performance
```ruby
test "syncs large number of files efficiently" do
  files = create_list(:cloud_file, 1000)
  
  time = Benchmark.realtime do
    perform_enqueued_jobs do
      CloudFileSyncJob.perform_later(files)
    end
  end
  
  assert time < 30.seconds
  assert CloudFile.where(synced: true).count == 1000
end
```

### Channel Load Testing
```ruby
test "handles multiple concurrent connections" do
  users = create_list(:user, 100)
  
  connections = users.map do |user|
    connect user: user
    subscribe room_id: "global"
  end
  
  assert connections.all?(&:confirmed?)
end
```

## Success Criteria
- [ ] All jobs achieve >85% coverage
- [ ] All channels achieve >85% coverage
- [ ] Async behavior properly tested
- [ ] Error recovery verified
- [ ] Performance benchmarks met
- [ ] No race conditions in tests

## Notes for Agent
- Use `perform_enqueued_jobs` for synchronous testing
- Test both success and failure paths
- Verify broadcasts with `assert_broadcast_on`
- Mock external services to avoid flakiness
- Test job retry and dead letter behavior
- Ensure channel authorization is tested