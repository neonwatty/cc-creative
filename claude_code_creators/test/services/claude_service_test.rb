require "test_helper"
require "ostruct"

class ClaudeServiceTest < ActiveSupport::TestCase
  setup do
    @session_id = "test-session-#{SecureRandom.uuid}"
    
    # Mock Rails.application.config.anthropic
    Rails.application.config.stubs(:anthropic).returns({
      api_key: 'test-api-key',
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4096,
      temperature: 0.7
    })
    
    @service = ClaudeService.new(session_id: @session_id)
    
    # Mock Anthropic client
    @mock_client = mock('anthropic_client')
    @service.instance_variable_set(:@client, @mock_client)
  end
  
  teardown do
    # Clean up test data
    ClaudeSession.where(session_id: @session_id).destroy_all
    ClaudeMessage.where(session_id: @session_id).destroy_all
    
    # Restore Rails config
    Rails.application.config.unstub(:anthropic)
  end
  
  test "initializes with session_id" do
    assert_equal @session_id, @service.instance_variable_get(:@session_id)
    assert_nil @service.instance_variable_get(:@sub_agent_name)
  end
  
  test "initializes with sub_agent_name" do
    sub_agent_service = ClaudeService.new(
      session_id: @session_id,
      sub_agent_name: "test-agent"
    )
    assert_equal "test-agent", sub_agent_service.instance_variable_get(:@sub_agent_name)
  end
  
  test "send_message returns structured response" do
    # Mock response
    mock_response = OpenStruct.new(
      content: [OpenStruct.new(text: "Hello! I'm Claude.")],
      usage: { total_tokens: 42 }
    )
    
    @mock_client.expects(:messages).returns(mock_response)
    
    result = @service.send_message("Hello Claude!")
    
    assert_equal "Hello! I'm Claude.", result[:response]
    assert_equal({ total_tokens: 42 }, result[:usage])
    assert_equal @session_id, result[:session_id]
    assert_nil result[:sub_agent]
  end
  
  test "send_message stores interaction in database" do
    # Mock response
    mock_response = OpenStruct.new(
      content: [OpenStruct.new(text: "Test response")],
      usage: { total_tokens: 20 }
    )
    
    @mock_client.expects(:messages).returns(mock_response)
    
    assert_difference 'ClaudeMessage.count', 2 do
      @service.send_message("Test message")
    end
    
    # Check stored messages
    messages = ClaudeMessage.where(session_id: @session_id).order(:created_at)
    
    assert_equal 2, messages.count
    assert_equal "user", messages.first.role
    assert_equal "Test message", messages.first.content
    assert_equal "assistant", messages.last.role
    assert_equal "Test response", messages.last.content
  end
  
  test "send_message raises ApiError on Anthropic error" do
    # Mock the Anthropic::Error class if it doesn't exist
    unless defined?(Anthropic::Error)
      Anthropic = Module.new
      Anthropic::Error = Class.new(StandardError)
    end
    
    @mock_client.expects(:messages).raises(Anthropic::Error.new("API Error"))
    
    assert_raises(ClaudeService::ApiError) do
      @service.send_message("Test")
    end
  end
  
  test "create_sub_agent returns new service instance" do
    sub_agent = @service.create_sub_agent("research", initial_context: { task: "research" })
    
    assert_instance_of ClaudeService, sub_agent
    assert_equal "#{@session_id}:research", sub_agent.instance_variable_get(:@session_id)
    assert_equal "research", sub_agent.instance_variable_get(:@sub_agent_name)
  end
  
  test "set_context updates session context" do
    @service.set_context({ user_name: "Alice", preferences: { theme: "dark" } })
    
    session = ClaudeSession.find_by(session_id: @session_id)
    assert_equal "Alice", session.context["user_name"]
    assert_equal "dark", session.context["preferences"]["theme"]
  end
  
  test "get_context returns session context" do
    # Create session with context
    ClaudeSession.create!(
      session_id: @session_id,
      context: { test_key: "test_value" }
    )
    
    context = @service.get_context
    assert_equal "test_value", context["test_key"]
  end
  
  test "clear_context removes all context" do
    # Create session with context
    ClaudeSession.create!(
      session_id: @session_id,
      context: { test_key: "test_value" }
    )
    
    @service.clear_context
    
    context = @service.get_context
    assert_empty context
  end
  
  test "conversation_history returns recent messages" do
    # Create some messages
    5.times do |i|
      ClaudeMessage.create!(
        session_id: @session_id,
        role: i.even? ? "user" : "assistant",
        content: "Message #{i}"
      )
    end
    
    history = @service.conversation_history(limit: 3)
    
    assert_equal 3, history.count
    assert_equal "Message 4", history.first.content
  end
  
  test "handles missing API key gracefully" do
    service = ClaudeService.new(session_id: "test")
    service.instance_variable_set(:@client, nil)
    
    assert_raises(ClaudeService::ConfigurationError) do
      service.send_message("Test")
    end
  end
end