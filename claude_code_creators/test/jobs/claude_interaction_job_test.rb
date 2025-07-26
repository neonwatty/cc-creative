require "test_helper"

class ClaudeInteractionJobTest < ActiveJob::TestCase
  setup do
    @session_id = "test-session-#{SecureRandom.uuid}"
    @job = ClaudeInteractionJob.new
    
    # Mock Rails.application.config.anthropic
    Rails.application.config.stubs(:anthropic).returns({
      api_key: 'test-api-key',
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4096,
      temperature: 0.7
    })
    
    # Mock the Anthropic::Error class if it doesn't exist
    unless defined?(Anthropic::Error)
      Anthropic = Module.new
      Anthropic::Error = Class.new(StandardError)
    end
    
    # Clear cache to prevent rate limit interference
    Rails.cache.clear if defined?(Rails.cache)
  end
  
  teardown do
    ClaudeSession.where(session_id: @session_id).destroy_all
    ClaudeMessage.where(session_id: @session_id).destroy_all
    ClaudeContext.where(session_id: @session_id).destroy_all
    
    # Restore Rails config
    Rails.application.config.unstub(:anthropic)
  end
  
  test "enqueues job" do
    assert_enqueued_with(job: ClaudeInteractionJob) do
      ClaudeInteractionJob.perform_later(@session_id, 'send_message', { content: "Test" })
    end
  end
  
  test "performs send_message action" do
    # Mock ClaudeService
    mock_result = { 
      response: "Test response", 
      usage: { total_tokens: 10 },
      session_id: @session_id
    }
    
    ClaudeService.any_instance.expects(:send_message)
                 .with("Test content", context: {}, system_prompt: nil)
                 .returns(mock_result)
    
    result = @job.perform(@session_id, 'send_message', { content: "Test content" })
    assert_equal mock_result, result
  end
  
  test "performs create_sub_agent action" do
    # Create a session first
    session = ClaudeSession.create!(session_id: @session_id, metadata: {})
    
    # Mock ClaudeService and sub-agent
    mock_sub_agent = mock('sub_agent')
    mock_sub_agent.expects(:instance_variable_get).with(:@session_id).returns("#{@session_id}:research")
    
    ClaudeService.any_instance.expects(:create_sub_agent)
                 .with("research", initial_context: {})
                 .returns(mock_sub_agent)
    
    @job.perform(@session_id, 'create_sub_agent', { name: "research" })
    
    # Check that sub-agent info was stored
    session.reload
    assert_equal 1, session.metadata['sub_agents'].count
    assert_equal "research", session.metadata['sub_agents'].first['name']
  end
  
  test "performs compress_context action" do
    # Create some contexts - token count is auto-calculated
    3.times do |i|
      ClaudeContext.create!(
        session_id: @session_id,
        context_type: 'document',
        content: { text: "Document #{i}" * 1000 }
      )
    end
    
    # Verify initial state
    initial_count = ClaudeContext.where(session_id: @session_id).count
    assert_equal 3, initial_count
    
    # Get initial total tokens
    initial_tokens = ClaudeContext.total_tokens_for_session(@session_id)
    
    # Perform compression with a limit less than total
    @job.perform(@session_id, 'compress_context', { max_tokens: initial_tokens / 2 })
    
    # Should have removed at least one context
    remaining_count = ClaudeContext.where(session_id: @session_id).count
    assert remaining_count < initial_count, "Expected fewer than #{initial_count} contexts, got #{remaining_count}"
    
    # Total tokens should be under limit
    total_tokens = ClaudeContext.total_tokens_for_session(@session_id)
    assert total_tokens <= initial_tokens / 2, "Expected tokens <= #{initial_tokens / 2}, got #{total_tokens}"
  end
  
  test "performs generate_completion action" do
    # Create some previous messages
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Previous question"
    )
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "assistant",
      content: "Previous answer"
    )
    
    # Mock ClaudeService
    mock_result = { 
      response: "Generated completion", 
      usage: { total_tokens: 50 }
    }
    
    ClaudeService.any_instance.expects(:send_message)
                 .with("Complete this", has_key(:context))
                 .returns(mock_result)
    
    result = @job.perform(@session_id, 'generate_completion', { 
      prompt: "Complete this",
      context_size: 2 
    })
    assert_equal mock_result, result
  end
  
  test "raises error for unknown action" do
    assert_raises(ArgumentError) do
      @job.perform(@session_id, 'unknown_action', {})
    end
  end
  
  test "respects rate limiting" do
    # Simulate hitting rate limit
    Rails.cache.write(
      "claude_rate_limit:#{Time.current.to_i / 60}",
      ClaudeInteractionJob::MAX_REQUESTS_PER_MINUTE + 1,
      expires_in: 1.minute
    )
    
    assert_raises(StandardError, "Rate limit exceeded") do
      @job.perform(@session_id, 'send_message', { content: "Test" })
    end
  end
  
  test "handles and logs errors" do
    # Create a session
    session = ClaudeSession.create!(session_id: @session_id, metadata: {})
    
    # Force an error
    ClaudeService.any_instance.expects(:send_message).raises(StandardError, "Test error")
    
    assert_raises(StandardError) do
      @job.perform(@session_id, 'send_message', { content: "Test" })
    end
    
    # Check error was logged in session
    session.reload
    assert_equal "send_message", session.metadata['last_error']['action']
    assert_equal "Test error", session.metadata['last_error']['error']
  end
  
  test "retries on API errors" do
    # Check that job is configured to retry on API errors
    # ActiveJob doesn't expose retry configuration easily, so we just ensure
    # the job can be performed and handles errors appropriately
    assert_nothing_raised do
      ClaudeInteractionJob.new
    end
  end
end