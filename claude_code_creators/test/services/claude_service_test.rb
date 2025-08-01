require "test_helper"

class ClaudeServiceTest < ActiveSupport::TestCase
  setup do
    # Configure Rails config for testing
    Rails.application.config.stubs(:anthropic).returns({
      api_key: "test-api-key",
      model: "claude-3-opus-20240229",
      max_tokens: 1000,
      temperature: 0.7
    })
    
    @service = ClaudeService.new(session_id: "test-session")
    
    # Mock Anthropic API responses
    @mock_response = OpenStruct.new(
      content: [OpenStruct.new(text: "Hello! I'm Claude.")],
      usage: { 
        input_tokens: 10,
        output_tokens: 5,
        total_tokens: 15
      }
    )
  end

  teardown do
    # WebMock.reset!
  end

  test "initializes with session_id and sub_agent_name" do
    service = ClaudeService.new(session_id: "test-123", sub_agent_name: "editor")
    assert_not_nil service
  end

  test "initializes with auto-generated session_id when not provided" do
    SecureRandom.stubs(:uuid).returns("auto-generated-uuid")
    service = ClaudeService.new
    assert_not_nil service
  end

  test "send_message makes API call and returns structured response" do
    # Mock the Anthropic client
    mock_client = mock()
    mock_client.expects(:messages).with(
      model: "claude-3-opus-20240229",
      max_tokens: 1000,
      temperature: 0.7,
      system: anything,
      messages: [{ role: "user", content: "Hello Claude" }]
    ).returns(@mock_response)
    
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    # Create service and send message
    service = ClaudeService.new(session_id: "test-session")
    response = service.send_message("Hello Claude")
    
    assert_equal "Hello! I'm Claude.", response[:response]
    assert_equal "test-session", response[:session_id]
    assert_nil response[:sub_agent]
    assert_equal 10, response[:usage][:input_tokens]
  end

  test "send_message with context includes previous messages" do
    mock_client = mock()
    mock_client.expects(:messages).with(
      model: anything,
      max_tokens: anything,
      temperature: anything,
      system: anything,
      messages: [
        { role: "user", content: "First message" },
        { role: "assistant", content: "First response" },
        { role: "user", content: "Second message" }
      ]
    ).returns(@mock_response)
    
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    service = ClaudeService.new
    context = {
      previous_messages: [
        { role: "user", content: "First message" },
        { role: "assistant", content: "First response" }
      ]
    }
    
    service.send_message("Second message", context: context)
  end

  test "send_message with custom system prompt" do
    mock_client = mock()
    mock_client.expects(:messages).with(
      model: anything,
      max_tokens: anything,
      temperature: anything,
      system: "You are a helpful coding assistant.",
      messages: anything
    ).returns(@mock_response)
    
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    service = ClaudeService.new
    service.send_message("Help me code", system_prompt: "You are a helpful coding assistant.")
  end

  test "send_message stores interaction in database" do
    mock_client = mock()
    mock_client.stubs(:messages).returns(@mock_response)
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    service = ClaudeService.new(session_id: "test-session")
    
    assert_difference "ClaudeMessage.count", 2 do
      service.send_message("Hello Claude")
    end
    
    user_message = ClaudeMessage.where(role: "user").last
    assert_equal "test-session", user_message.session_id
    assert_equal "Hello Claude", user_message.content
    
    assistant_message = ClaudeMessage.where(role: "assistant").last
    assert_equal "test-session", assistant_message.session_id
    assert_equal "Hello! I'm Claude.", assistant_message.content
  end

  test "send_message raises ApiError on Anthropic error" do
    mock_client = mock()
    mock_client.expects(:messages).raises(Anthropic::Error.new("API Error"))
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    service = ClaudeService.new
    
    assert_raises ClaudeService::ApiError do
      service.send_message("Hello")
    end
  end

  test "send_message raises ConfigurationError when client not configured" do
    Rails.application.config.anthropic[:api_key] = nil
    
    service = ClaudeService.new
    
    assert_raises ClaudeService::ConfigurationError do
      service.send_message("Hello")
    end
  end

  test "create_sub_agent creates new service with sub_agent context" do
    service = ClaudeService.new(session_id: "main-session")
    sub_agent = service.create_sub_agent("editor", initial_context: { role: "code editor" })
    
    assert_not_nil sub_agent
    assert_equal "editor", sub_agent.instance_variable_get(:@sub_agent_name)
    assert_equal "main-session:editor", sub_agent.instance_variable_get(:@session_id)
  end

  test "set_context updates session context" do
    service = ClaudeService.new(session_id: "test-session")
    
    service.set_context({ theme: "dark", language: "ruby" })
    
    session = ClaudeSession.find_by(session_id: "test-session")
    assert_equal "dark", session.context["theme"]
    assert_equal "ruby", session.context["language"]
  end

  test "get_context returns current context" do
    service = ClaudeService.new(session_id: "test-session")
    service.set_context({ theme: "light" })
    
    context = service.get_context
    assert_equal "light", context["theme"]
  end

  test "clear_context removes all context" do
    service = ClaudeService.new(session_id: "test-session")
    service.set_context({ theme: "dark", language: "ruby" })
    
    service.clear_context
    
    context = service.get_context
    assert_empty context
  end

  test "conversation_history returns recent messages" do
    # Create some messages
    ClaudeMessage.create!(
      session_id: "test-session",
      role: "user",
      content: "First message",
      created_at: 2.hours.ago
    )
    
    ClaudeMessage.create!(
      session_id: "test-session",
      role: "assistant",
      content: "First response",
      created_at: 1.hour.ago
    )
    
    service = ClaudeService.new(session_id: "test-session")
    history = service.conversation_history(limit: 2)
    
    assert_equal 2, history.count
    assert_equal "First response", history.first.content
  end

  test "stream_message returns enumerator" do
    mock_client = mock()
    mock_client.expects(:messages).with(
      model: anything,
      max_tokens: anything,
      temperature: anything,
      system: anything,
      messages: anything,
      stream: anything
    ).returns(nil)
    
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    service = ClaudeService.new
    result = service.stream_message("Hello")
    
    assert_kind_of Enumerator, result
    
    # Consume the enumerator to trigger the API call
    result.to_a rescue nil
  end

  test "context manager merges context updates" do
    service = ClaudeService.new(session_id: "test-session")
    
    service.set_context({ theme: "dark" })
    service.set_context({ language: "ruby" })
    
    context = service.get_context
    assert_equal "dark", context["theme"]
    assert_equal "ruby", context["language"]
  end

  test "handles sub_agent_name in stored messages" do
    mock_client = mock()
    mock_client.stubs(:messages).returns(@mock_response)
    Anthropic::Client.stubs(:new).returns(mock_client)
    
    service = ClaudeService.new(session_id: "test-session", sub_agent_name: "editor")
    service.send_message("Hello")
    
    messages = ClaudeMessage.where(session_id: "test-session")
    assert messages.all? { |m| m.sub_agent_name == "editor" }
  end
end