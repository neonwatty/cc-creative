require "test_helper"

class ClaudeMessageTest < ActiveSupport::TestCase
  setup do
    @claude_message = claude_messages(:one)
    @session_id = "test-session-456"
  end

  # Validation tests
  test "should be valid with valid attributes" do
    message = ClaudeMessage.new(
      session_id: @session_id,
      role: "user",
      content: "Hello Claude"
    )
    assert message.valid?
  end

  test "should require session_id" do
    message = ClaudeMessage.new(role: "user", content: "Test")
    assert_not message.valid?
    assert_includes message.errors[:session_id], "can't be blank"
  end

  test "should require role" do
    message = ClaudeMessage.new(session_id: @session_id, content: "Test")
    assert_not message.valid?
    assert_includes message.errors[:role], "can't be blank"
  end

  test "should require content" do
    message = ClaudeMessage.new(session_id: @session_id, role: "user")
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "should validate role inclusion" do
    message = ClaudeMessage.new(session_id: @session_id, role: "invalid", content: "Test")
    assert_not message.valid?
    assert_includes message.errors[:role], "is not included in the list"
  end

  test "should accept valid roles" do
    %w[user assistant system].each do |role|
      message = ClaudeMessage.new(session_id: @session_id, role: role, content: "Test")
      assert message.valid?, "#{role} should be a valid role"
    end
  end

  # Association tests
  test "belongs to claude_session through session_id" do
    session = ClaudeSession.create!(session_id: @session_id)
    message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Test message"
    )
    assert_equal session, message.claude_session
  end

  test "claude_session association is optional" do
    message = ClaudeMessage.create!(
      session_id: "non-existent-session",
      role: "user",
      content: "Test message"
    )
    assert_nil message.claude_session
    assert message.persisted?
  end

  # Scope tests
  test "user_messages scope returns only user role messages" do
    user_msg = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "User message")
    assistant_msg = ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Assistant message")
    
    results = ClaudeMessage.user_messages
    assert_includes results, user_msg
    assert_not_includes results, assistant_msg
  end

  test "assistant_messages scope returns only assistant role messages" do
    user_msg = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "User message")
    assistant_msg = ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Assistant message")
    
    results = ClaudeMessage.assistant_messages
    assert_includes results, assistant_msg
    assert_not_includes results, user_msg
  end

  test "by_session scope filters by session_id" do
    msg1 = ClaudeMessage.create!(session_id: "session1", role: "user", content: "Message 1")
    msg2 = ClaudeMessage.create!(session_id: "session2", role: "user", content: "Message 2")
    msg3 = ClaudeMessage.create!(session_id: "session1", role: "assistant", content: "Message 3")
    
    results = ClaudeMessage.by_session("session1")
    assert_includes results, msg1
    assert_includes results, msg3
    assert_not_includes results, msg2
  end

  test "by_sub_agent scope filters by sub_agent_name" do
    msg1 = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Message 1", sub_agent_name: "editor")
    msg2 = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Message 2", sub_agent_name: "researcher")
    msg3 = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Message 3", sub_agent_name: "editor")
    
    results = ClaudeMessage.by_sub_agent("editor")
    assert_includes results, msg1
    assert_includes results, msg3
    assert_not_includes results, msg2
  end

  test "recent scope orders by created_at descending" do
    old = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Old", created_at: 2.days.ago)
    new = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "New", created_at: 1.hour.ago)
    middle = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Middle", created_at: 1.day.ago)
    
    results = ClaudeMessage.recent.to_a
    assert_equal [new, middle, old], results.select { |m| [new, middle, old].include?(m) }
  end

  # Class method tests
  test "conversation_pairs returns message pairs" do
    # Create alternating user/assistant messages
    msg1 = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Question 1", created_at: 4.hours.ago)
    msg2 = ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Answer 1", created_at: 3.hours.ago)
    msg3 = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Question 2", created_at: 2.hours.ago)
    msg4 = ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Answer 2", created_at: 1.hour.ago)
    
    pairs = ClaudeMessage.conversation_pairs(@session_id, limit: 2)
    
    # Should return most recent pairs first
    assert_equal 2, pairs.size
    assert_equal [msg4, msg3], pairs[0]
    assert_equal [msg2, msg1], pairs[1]
  end

  test "conversation_pairs respects limit" do
    10.times do |i|
      ClaudeMessage.create!(
        session_id: @session_id, 
        role: i.even? ? "user" : "assistant", 
        content: "Message #{i}",
        created_at: i.hours.ago
      )
    end
    
    pairs = ClaudeMessage.conversation_pairs(@session_id, limit: 3)
    assert_equal 3, pairs.size
  end

  test "conversation_pairs handles odd number of messages" do
    ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Question 1")
    ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Answer 1")
    ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Question 2")
    
    pairs = ClaudeMessage.conversation_pairs(@session_id)
    # Should only return complete pairs
    assert_equal 1, pairs.size
  end

  # Instance method tests
  test "user? returns true for user role" do
    message = ClaudeMessage.new(role: "user")
    assert message.user?
    assert_not message.assistant?
    assert_not message.system?
  end

  test "assistant? returns true for assistant role" do
    message = ClaudeMessage.new(role: "assistant")
    assert message.assistant?
    assert_not message.user?
    assert_not message.system?
  end

  test "system? returns true for system role" do
    message = ClaudeMessage.new(role: "system")
    assert message.system?
    assert_not message.user?
    assert_not message.assistant?
  end

  test "token_count returns stored count from metadata" do
    message = ClaudeMessage.new(
      content: "Test content",
      message_metadata: { 'token_count' => 42 }
    )
    assert_equal 42, message.token_count
  end

  test "token_count estimates when not stored" do
    message = ClaudeMessage.new(content: "a" * 40)
    # 40 chars / 4 = 10 tokens
    assert_equal 10, message.token_count
  end

  test "formatted_content returns content for non-assistant messages" do
    user_message = ClaudeMessage.new(role: "user", content: "User content")
    assert_equal "User content", user_message.formatted_content
    
    system_message = ClaudeMessage.new(role: "system", content: "System content")
    assert_equal "System content", system_message.formatted_content
  end

  test "formatted_content processes assistant messages" do
    assistant_message = ClaudeMessage.new(role: "assistant", content: "Assistant content")
    # Currently just returns content, but this is where formatting logic would go
    assert_equal "Assistant content", assistant_message.formatted_content
  end

  # Callback tests
  test "sets default values after initialize" do
    message = ClaudeMessage.new
    assert_equal({}, message.context)
    assert_equal({}, message.message_metadata)
  end

  test "calculates token estimate before save" do
    message = ClaudeMessage.new(
      session_id: @session_id,
      role: "user",
      content: "a" * 100
    )
    
    assert_nil message.message_metadata['token_count']
    message.save!
    assert_equal 25, message.message_metadata['token_count']  # 100 / 4
  end

  test "updates token count when content changes" do
    message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Short"
    )
    
    initial_tokens = message.token_count
    
    message.content = "a" * 200
    message.save!
    
    assert_equal 50, message.token_count  # 200 / 4
    assert message.token_count > initial_tokens
  end

  test "estimate_tokens rounds up" do
    message = ClaudeMessage.new(content: "abc")  # 3 chars
    # 3 / 4 = 0.75, should round up to 1
    assert_equal 1, message.send(:estimate_tokens)
  end

  test "can store sub_agent_name" do
    message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Test",
      sub_agent_name: "researcher"
    )
    
    assert_equal "researcher", message.sub_agent_name
    assert message.persisted?
  end

  test "can store arbitrary context data" do
    message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Test",
      context: { document_id: 123, reference: "page 5" }
    )
    
    assert_equal 123, message.context["document_id"]
    assert_equal "page 5", message.context["reference"]
  end

  test "can store message metadata" do
    message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "assistant",
      content: "Test response",
      message_metadata: { 
        model: "claude-3-opus", 
        temperature: 0.7,
        processing_time: 1.23
      }
    )
    
    assert_equal "claude-3-opus", message.message_metadata["model"]
    assert_equal 0.7, message.message_metadata["temperature"]
    assert_equal 1.23, message.message_metadata["processing_time"]
  end
end