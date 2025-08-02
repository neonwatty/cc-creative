require "test_helper"

class ClaudeSessionTest < ActiveSupport::TestCase
  setup do
    @claude_session = claude_sessions(:one)
    @session_id = "test-session-789"
  end

  # Validation tests
  test "should be valid with valid attributes" do
    session = ClaudeSession.new(session_id: @session_id)
    assert session.valid?
  end

  test "should require session_id" do
    session = ClaudeSession.new
    assert_not session.valid?
    assert_includes session.errors[:session_id], "can't be blank"
  end

  test "should enforce unique session_id" do
    ClaudeSession.create!(session_id: @session_id)

    duplicate = ClaudeSession.new(session_id: @session_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:session_id], "has already been taken"
  end

  # Association tests
  test "has many claude_messages through session_id" do
    session = ClaudeSession.create!(session_id: @session_id)
    message1 = ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Test 1")
    message2 = ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Test 2")

    assert_equal 2, session.claude_messages.count
    assert_includes session.claude_messages, message1
    assert_includes session.claude_messages, message2
  end

  test "has many claude_contexts through session_id" do
    session = ClaudeSession.create!(session_id: @session_id)
    context1 = ClaudeContext.create!(session_id: @session_id, context_type: "document")
    context2 = ClaudeContext.create!(session_id: @session_id, context_type: "code")

    assert_equal 2, session.claude_contexts.count
    assert_includes session.claude_contexts, context1
    assert_includes session.claude_contexts, context2
  end

  test "dependent destroy removes associated messages" do
    session = ClaudeSession.create!(session_id: @session_id)
    ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Test")

    assert_difference "ClaudeMessage.count", -1 do
      session.destroy
    end
  end

  test "dependent destroy removes associated contexts" do
    session = ClaudeSession.create!(session_id: @session_id)
    ClaudeContext.create!(session_id: @session_id, context_type: "document")

    assert_difference "ClaudeContext.count", -1 do
      session.destroy
    end
  end

  # Scope tests
  test "active scope returns sessions updated within 24 hours" do
    active_session = ClaudeSession.create!(session_id: "active", updated_at: 1.hour.ago)
    inactive_session = ClaudeSession.create!(session_id: "inactive", updated_at: 2.days.ago)

    results = ClaudeSession.active
    assert_includes results, active_session
    assert_not_includes results, inactive_session
  end

  test "with_messages scope returns only sessions with messages" do
    session_with_messages = ClaudeSession.create!(session_id: "with_messages")
    ClaudeMessage.create!(session_id: "with_messages", role: "user", content: "Test")

    session_without_messages = ClaudeSession.create!(session_id: "without_messages")

    results = ClaudeSession.with_messages
    assert_includes results, session_with_messages
    assert_not_includes results, session_without_messages
  end

  test "with_messages scope returns distinct sessions" do
    session = ClaudeSession.create!(session_id: "multiple_messages")
    ClaudeMessage.create!(session_id: "multiple_messages", role: "user", content: "Test 1")
    ClaudeMessage.create!(session_id: "multiple_messages", role: "assistant", content: "Test 2")

    results = ClaudeSession.with_messages
    assert_equal 1, results.where(session_id: "multiple_messages").count
  end

  # Instance method tests
  test "add_context adds key-value pairs to context" do
    session = ClaudeSession.create!(session_id: @session_id)

    session.add_context("user_id", 123)
    session.add_context("document_id", 456)

    assert_equal 123, session.context["user_id"]
    assert_equal 456, session.context["document_id"]
  end

  test "remove_context removes key from context" do
    session = ClaudeSession.create!(
      session_id: @session_id,
      context: { "user_id" => 123, "document_id" => 456 }
    )

    session.remove_context("user_id")

    assert_nil session.context["user_id"]
    assert_equal 456, session.context["document_id"]
  end

  test "message_count returns count of associated messages" do
    session = ClaudeSession.create!(session_id: @session_id)

    assert_equal 0, session.message_count

    ClaudeMessage.create!(session_id: @session_id, role: "user", content: "Test 1")
    ClaudeMessage.create!(session_id: @session_id, role: "assistant", content: "Test 2")

    assert_equal 2, session.message_count
  end

  test "last_message returns most recent message" do
    session = ClaudeSession.create!(session_id: @session_id)

    assert_nil session.last_message

    older_message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Older",
      created_at: 1.hour.ago
    )
    newer_message = ClaudeMessage.create!(
      session_id: @session_id,
      role: "assistant",
      content: "Newer",
      created_at: 1.minute.ago
    )

    assert_equal newer_message, session.last_message
  end

  test "total_tokens_used sums tokens from messages" do
    session = ClaudeSession.create!(session_id: @session_id)

    # Create messages with usage metadata
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Test 1",
      message_metadata: { "usage" => { "total_tokens" => 10 } }
    )
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "assistant",
      content: "Test 2",
      message_metadata: { "usage" => { "total_tokens" => 20 } }
    )

    assert_equal 30, session.total_tokens_used
  end

  test "total_tokens_used handles missing metadata" do
    session = ClaudeSession.create!(session_id: @session_id)

    # Message with usage
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Test 1",
      message_metadata: { "usage" => { "total_tokens" => 15 } }
    )

    # Message without usage
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "assistant",
      content: "Test 2"
    )

    # Message with empty metadata
    ClaudeMessage.create!(
      session_id: @session_id,
      role: "user",
      content: "Test 3",
      message_metadata: {}
    )

    assert_equal 15, session.total_tokens_used
  end

  # Callback tests
  test "sets default values after initialize" do
    session = ClaudeSession.new
    assert_equal({}, session.context)
    assert_equal({}, session.metadata)
  end

  test "preserves existing values when setting defaults" do
    session = ClaudeSession.new(
      context: { "existing" => "value" },
      metadata: { "key" => "data" }
    )

    assert_equal({ "existing" => "value" }, session.context)
    assert_equal({ "key" => "data" }, session.metadata)
  end

  test "can store arbitrary metadata" do
    session = ClaudeSession.create!(
      session_id: @session_id,
      metadata: {
        "sub_agents" => [ "editor", "researcher" ],
        "user_preferences" => { "theme" => "dark" }
      }
    )

    assert_equal [ "editor", "researcher" ], session.metadata["sub_agents"]
    assert_equal "dark", session.metadata["user_preferences"]["theme"]
  end

  test "associations work with string session_id as foreign key" do
    # This tests the non-standard foreign key setup
    session = ClaudeSession.create!(session_id: "custom-id-123")
    message = ClaudeMessage.create!(session_id: "custom-id-123", role: "user", content: "Test")
    context = ClaudeContext.create!(session_id: "custom-id-123", context_type: "document")

    session.reload
    assert_includes session.claude_messages, message
    assert_includes session.claude_contexts, context
  end
end
