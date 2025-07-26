# Helper module for testing Claude integration
require 'ostruct'

module ClaudeTestHelper
  # Mock Anthropic client for testing
  class MockAnthropicClient
    attr_accessor :messages_called, :last_request
    
    def initialize(responses = {})
      @responses = responses
      @messages_called = 0
      @last_request = nil
    end
    
    def messages(params)
      @messages_called += 1
      @last_request = params
      
      # Return configured response or default
      response = @responses[:messages] || default_message_response
      
      if response.is_a?(Exception)
        raise response
      else
        response
      end
    end
    
    private
    
    def default_message_response
      OpenStruct.new(
        content: [OpenStruct.new(text: "Mock response from Claude")],
        usage: {
          input_tokens: 10,
          output_tokens: 15,
          total_tokens: 25
        },
        model: "claude-3-5-sonnet-20241022",
        stop_reason: "end_turn"
      )
    end
  end
  
  # Create a mock response for testing
  def mock_claude_response(text, usage = {})
    OpenStruct.new(
      content: [OpenStruct.new(text: text)],
      usage: usage.reverse_merge(
        input_tokens: 10,
        output_tokens: 15,
        total_tokens: 25
      )
    )
  end
  
  # Create a mock error for testing
  def mock_claude_error(message = "API Error")
    Anthropic::Error.new(message)
  end
  
  # Stub ClaudeService with mock client
  def with_mocked_claude_service(responses = {})
    mock_client = MockAnthropicClient.new(responses)
    
    ClaudeService.any_instance.stubs(:create_client).returns(mock_client)
    
    yield mock_client
  ensure
    ClaudeService.any_instance.unstub(:create_client)
  end
  
  # Create test messages
  def create_test_conversation(session_id, message_count: 3)
    messages = []
    
    message_count.times do |i|
      messages << ClaudeMessage.create!(
        session_id: session_id,
        role: i.even? ? "user" : "assistant",
        content: "Test message #{i + 1}"
      )
    end
    
    messages
  end
  
  # Create test context
  def create_test_context(session_id, type: 'document', size: 1000)
    ClaudeContext.create!(
      session_id: session_id,
      context_type: type,
      content: { text: "Test content" * (size / 12) },
      token_count: size
    )
  end
end

# Include in test classes
ActiveSupport::TestCase.include ClaudeTestHelper if defined?(ActiveSupport::TestCase)