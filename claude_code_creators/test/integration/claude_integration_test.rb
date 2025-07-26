require "test_helper"

class ClaudeIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @session_id = "integration-test-#{SecureRandom.uuid}"
    
    # Mock Rails config for Anthropic
    Rails.application.config.anthropic = {
      api_key: 'test-api-key',
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4096,
      temperature: 0.7
    }
    
    # Clear cache to prevent rate limit interference
    Rails.cache.clear if defined?(Rails.cache)
    
    # Mock the Anthropic::Error class if it doesn't exist
    unless defined?(Anthropic::Error)
      Anthropic = Module.new
      Anthropic::Error = Class.new(StandardError)
    end
  end
  
  teardown do
    ClaudeSession.where(session_id: @session_id).destroy_all
    ClaudeMessage.where(session_id: @session_id).destroy_all
    ClaudeContext.where(session_id: @session_id).destroy_all
  end
  
  test "full conversation flow with context management" do
    # Create service with mocked client
    with_mocked_claude_service(messages: mock_claude_response("Hello! How can I help you today?")) do |mock_client|
      service = ClaudeService.new(session_id: @session_id)
      
      # Set initial context
      service.set_context({ user_name: "Alice", project: "Creative Writing" })
      
      # Send first message
      result = service.send_message("Hello Claude!")
      
      assert_equal "Hello! How can I help you today?", result[:response]
      assert_equal @session_id, result[:session_id]
      
      # Verify message was stored
      messages = ClaudeMessage.where(session_id: @session_id).order(:created_at)
      assert_equal 2, messages.count
      assert_equal "user", messages.first.role
      assert_equal "Hello Claude!", messages.first.content
      assert_equal "assistant", messages.last.role
      
      # Verify context was stored
      context = service.get_context
      assert_equal "Alice", context["user_name"]
      assert_equal "Creative Writing", context["project"]
      
      # Verify mock was called correctly
      assert_equal 1, mock_client.messages_called
      assert_equal "Hello Claude!", mock_client.last_request[:messages].last[:content]
    end
  end
  
  test "sub-agent creation and isolation" do
    with_mocked_claude_service do
      main_service = ClaudeService.new(session_id: @session_id)
      
      # Set main context
      main_service.set_context({ mode: "main" })
      
      # Create sub-agent
      research_agent = main_service.create_sub_agent("research", 
        initial_context: { mode: "research", focus: "historical facts" }
      )
      
      # Verify sub-agent has separate context
      main_context = main_service.get_context
      research_context = research_agent.get_context
      
      assert_equal "main", main_context["mode"]
      assert_equal "research", research_context["mode"]
      assert_equal "historical facts", research_context["focus"]
      
      # Verify sub-agent session ID
      expected_sub_session_id = "#{@session_id}:research"
      assert_equal expected_sub_session_id, research_agent.instance_variable_get(:@session_id)
    end
  end
  
  test "background job processing" do
    # Create a mock client that will store messages
    with_mocked_claude_service(messages: mock_claude_response("Async response")) do |mock_client|
      # Perform job
      ClaudeInteractionJob.perform_now(
        @session_id, 
        'send_message', 
        { content: "Process this async" }
      )
      
      # Verify messages were created
      messages = ClaudeMessage.where(session_id: @session_id).order(:created_at)
      assert_equal 2, messages.count
      assert_equal "user", messages.first.role
      assert_equal "Process this async", messages.first.content
      assert_equal "assistant", messages.last.role
      assert_equal "Async response", messages.last.content
    end
  end
  
  test "context compression when limit exceeded" do
    # Create contexts with specific content
    5.times do |i|
      # Create content that will result in predictable token count
      content_text = "X" * 4000  # ~1000 tokens (4 chars per token)
      ClaudeContext.create!(
        session_id: @session_id,
        context_type: 'document',
        content: { text: content_text }
      )
    end
    
    # Get actual total tokens
    initial_count = ClaudeContext.where(session_id: @session_id).count
    initial_tokens = ClaudeContext.total_tokens_for_session(@session_id)
    
    assert_equal 5, initial_count
    assert initial_tokens > 0, "Expected tokens to be calculated"
    
    # Compress to half the current total
    target_tokens = initial_tokens / 2
    ClaudeContext.compress_context(@session_id, max_tokens: target_tokens)
    
    # Should have removed some contexts
    remaining_count = ClaudeContext.where(session_id: @session_id).count
    remaining_tokens = ClaudeContext.total_tokens_for_session(@session_id)
    
    assert remaining_count < initial_count, "Expected fewer contexts after compression"
    assert remaining_tokens <= target_tokens, "Expected tokens to be under limit"
  end
  
  test "conversation history retrieval" do
    # Create conversation
    messages = create_test_conversation(@session_id, message_count: 10)
    
    service = ClaudeService.new(session_id: @session_id)
    history = service.conversation_history(limit: 5)
    
    assert_equal 5, history.count
    # Should get most recent messages first
    assert_equal "Test message 10", history.first.content
  end
  
  test "error handling and recovery" do
    # Test API error handling
    with_mocked_claude_service(messages: mock_claude_error("Rate limit exceeded")) do
      service = ClaudeService.new(session_id: @session_id)
      
      assert_raises(ClaudeService::ApiError) do
        service.send_message("This should fail")
      end
      
      # Verify no messages were stored on error
      assert_equal 0, ClaudeMessage.where(session_id: @session_id).count
    end
  end
  
  test "streaming message support" do
    skip "Streaming implementation pending"
    
    # This would test the streaming functionality
    # when implemented
  end
end