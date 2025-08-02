require "test_helper"

class CommandExecutionServiceTest < ActiveSupport::TestCase
  def setup
    @document = documents(:one)
    @user = users(:one)
    @service = CommandExecutionService.new(@document, @user)
  end

  # Save Command Tests
  test "should execute save command with name parameter" do
    result = @service.execute("save", [ "my_context" ])

    assert result[:success]
    assert_equal "my_context", result[:context_name]
    assert result[:context_item_id].present?

    # Should create context item
    context_item = ContextItem.find(result[:context_item_id])
    assert_equal "my_context", context_item.title
    assert_equal "saved_context", context_item.item_type
  end

  test "should execute save command without name parameter" do
    result = @service.execute("save", [])

    assert result[:success]
    assert result[:context_name].present?  # Should auto-generate name
    assert result[:context_item_id].present?
  end

  test "should handle save command with existing name" do
    # Create existing context item
    @document.context_items.create!(
      title: "existing_context",
      content: "Existing content",
      item_type: "saved_context",
      user: @user
    )

    result = @service.execute("save", [ "existing_context" ])

    assert result[:success]
    assert result[:overwritten]
    assert_equal "existing_context", result[:context_name]
  end

  # Load Command Tests
  test "should execute load command successfully" do
    # Create context item to load
    context_item = @document.context_items.create!(
      title: "load_test",
      content: "Test content to load",
      item_type: "saved_context",
      user: @user
    )

    result = @service.execute("load", [ "load_test" ])

    assert result[:success]
    assert_equal "load_test", result[:context_name]
    assert_equal "Test content to load", result[:loaded_content]
    assert result[:claude_context_updated]
  end

  test "should handle load command with non-existent context" do
    result = @service.execute("load", [ "non_existent" ])

    assert_not result[:success]
    assert_match /not found/, result[:error]
    assert result[:suggestions].present?  # Should suggest similar names
  end

  test "should handle load command with ambiguous context name" do
    # Create multiple similar contexts
    @document.context_items.create!(title: "test_context", content: "Content 1", item_type: "saved_context", user: @user)
    @document.context_items.create!(title: "test_context_2", content: "Content 2", item_type: "saved_context", user: @user)

    result = @service.execute("load", [ "test" ])

    assert_not result[:success]
    assert_match /Ambiguous/, result[:error]
    assert result[:matches].length > 1
  end

  # Compact Command Tests
  test "should execute compact command successfully" do
    # Create Claude context with messages
    @document.claude_contexts.create!(
      context_data: {
        "messages" => [
          { "role" => "user", "content" => "Message 1" },
          { "role" => "assistant", "content" => "Response 1" },
          { "role" => "user", "content" => "Message 2" },
          { "role" => "assistant", "content" => "Response 2" }
        ]
      },
      user: @user
    )

    # Mock Claude API response
    claude_service = mock("claude_service")
    claude_service.stubs(:compact_context).returns({
      compacted_messages: [
        { "role" => "system", "content" => "Compacted conversation summary" }
      ],
      compression_ratio: 0.25
    })
    ClaudeService.stubs(:new).returns(claude_service)

    result = @service.execute("compact", [])

    assert result[:success]
    assert result[:original_message_count] == 4
    assert result[:compacted_message_count] == 1
    assert result[:compression_ratio] == 0.25
  end

  test "should execute compact command with aggressive parameter" do
    # Create Claude context
    @document.claude_contexts.create!(
      context_data: { "messages" => Array.new(10) { |i| { "role" => "user", "content" => "Message #{i}" } } },
      user: @user
    )

    claude_service = mock("claude_service")
    claude_service.stubs(:compact_context).with(anything, aggressive: true).returns({
      compacted_messages: [ { "role" => "system", "content" => "Aggressively compacted" } ],
      compression_ratio: 0.1
    })
    ClaudeService.stubs(:new).returns(claude_service)

    result = @service.execute("compact", [ "aggressive" ])

    assert result[:success]
    assert result[:compression_ratio] < 0.3  # Should be more aggressive
  end

  test "should handle compact command with no context" do
    result = @service.execute("compact", [])

    assert_not result[:success]
    assert_match /No context to compact/, result[:error]
  end

  # Clear Command Tests
  test "should execute clear command for context" do
    # Create Claude context
    claude_context = @document.claude_contexts.create!(
      context_data: { "messages" => [ "test" ] },
      user: @user
    )

    result = @service.execute("clear", [ "context" ])

    assert result[:success]
    assert_equal "context", result[:cleared_type]
    assert result[:cleared_items] > 0

    # Context should be cleared
    assert_not ClaudeContext.exists?(claude_context.id)
  end

  test "should execute clear command for document sections" do
    result = @service.execute("clear", [ "document" ])

    assert result[:success]
    assert_equal "document", result[:cleared_type]
    # Should clear document content but preserve structure
  end

  test "should execute clear command with no parameter (default to context)" do
    @document.claude_contexts.create!(context_data: { "messages" => [ "test" ] }, user: @user)

    result = @service.execute("clear", [])

    assert result[:success]
    assert_equal "context", result[:cleared_type]
  end

  # Include Command Tests
  test "should execute include command with file" do
    # Create a file context item
    file_item = @document.context_items.create!(
      title: "test_file.txt",
      content: "File content to include",
      item_type: "file",
      user: @user
    )

    result = @service.execute("include", [ "test_file.txt" ])

    assert result[:success]
    assert_equal "test_file.txt", result[:included_file]
    assert_equal "File content to include", result[:included_content]
    assert result[:claude_context_updated]
  end

  test "should execute include command with format specification" do
    file_item = @document.context_items.create!(
      title: "code.rb",
      content: "def test; end",
      item_type: "file",
      user: @user
    )

    result = @service.execute("include", [ "code.rb", "ruby" ])

    assert result[:success]
    assert_equal "ruby", result[:format]
    assert result[:formatted_content].present?
  end

  test "should handle include command with non-existent file" do
    result = @service.execute("include", [ "non_existent.txt" ])

    assert_not result[:success]
    assert_match /not found/, result[:error]
  end

  # Snippet Command Tests
  test "should execute snippet command with selected content" do
    selected_content = "def hello_world\n  puts 'Hello, World!'\nend"

    result = @service.execute("snippet", [ "ruby_hello" ], selected_content: selected_content)

    assert result[:success]
    assert_equal "ruby_hello", result[:snippet_name]
    assert result[:snippet_id].present?

    # Should create context item
    snippet = ContextItem.find(result[:snippet_id])
    assert_equal "ruby_hello", snippet.title
    assert_equal "snippet", snippet.item_type
    assert_equal selected_content, snippet.content
  end

  test "should execute snippet command with auto-generated name" do
    selected_content = "console.log('Hello');"

    result = @service.execute("snippet", [], selected_content: selected_content)

    assert result[:success]
    assert result[:snippet_name].present?
    assert result[:snippet_name].match?(/snippet_\d+/)  # Auto-generated format
  end

  test "should handle snippet command with no selected content" do
    result = @service.execute("snippet", [ "test_snippet" ])

    assert_not result[:success]
    assert_match /No content selected/, result[:error]
  end

  # Error Handling Tests
  test "should handle unknown command gracefully" do
    result = @service.execute("unknown_command", [])

    assert_not result[:success]
    assert_match /Unknown command/, result[:error]
    assert result[:suggestions].present?
  end

  test "should handle service timeouts" do
    # Create Claude context first
    @document.claude_contexts.create!(
      context_data: { "messages" => [ "test" ] },
      user: @user
    )

    # Mock timeout
    claude_service = mock("claude_service")
    claude_service.stubs(:compact_context).raises(Timeout::Error)
    ClaudeService.stubs(:new).returns(claude_service)

    result = @service.execute("compact", [])

    assert_not result[:success]
    assert_match /timeout/, result[:error]
  end

  test "should handle Claude API errors" do
    # Create Claude context first
    @document.claude_contexts.create!(
      context_data: { "messages" => [ "test" ] },
      user: @user
    )

    claude_service = mock("claude_service")
    claude_service.stubs(:compact_context).raises(ClaudeService::APIError, "Rate limit exceeded")
    ClaudeService.stubs(:new).returns(claude_service)

    result = @service.execute("compact", [])

    assert_not result[:success]
    assert_match /Claude API error/, result[:error]
  end

  # Permission Tests
  test "should validate user permissions for commands" do
    guest_user = User.create!(
      name: "Guest User",
      email_address: "guest@example.com",
      password: "password123",
      role: :guest
    )
    guest_service = CommandExecutionService.new(@document, guest_user)

    result = guest_service.execute("clear", [ "context" ])

    assert_not result[:success]
    assert_match /insufficient permissions/, result[:error]
  end

  test "should validate document access for commands" do
    other_document = documents(:two)  # Owned by different user
    other_service = CommandExecutionService.new(other_document, @user)

    result = other_service.execute("save", [ "test" ])

    assert_not result[:success]
    assert_match /access denied/, result[:error]
  end

  # Performance Tests
  test "should execute commands within performance limits" do
    start_time = Time.current
    result = @service.execute("save", [ "performance_test" ])
    end_time = Time.current

    assert result[:success]
    assert (end_time - start_time) < 0.1  # Under 100ms
  end

  test "should handle large context efficiently" do
    # Create large context
    large_context = {
      "messages" => Array.new(1000) { |i| { "role" => "user", "content" => "Message #{i}" } }
    }
    @document.claude_contexts.create!(context_data: large_context, user: @user)

    start_time = Time.current
    result = @service.execute("compact", [])
    end_time = Time.current

    # Should still complete in reasonable time
    assert (end_time - start_time) < 5.0  # Under 5 seconds
  end

  # Integration Tests
  test "should maintain data consistency across commands" do
    # Save context
    save_result = @service.execute("save", [ "integration_test" ])
    assert save_result[:success]

    # Load same context
    load_result = @service.execute("load", [ "integration_test" ])
    assert load_result[:success]

    # Should have consistent data
    saved_item = ContextItem.find(save_result[:context_item_id])
    assert_equal load_result[:loaded_content], saved_item.content
  end

  test "should update document timestamps appropriately" do
    original_time = @document.updated_at

    result = @service.execute("save", [ "timestamp_test" ])

    assert result[:success]
    @document.reload
    assert @document.updated_at > original_time
  end

  # Audit Logging Tests
  test "should log command execution for audit trail" do
    result = @service.execute("save", [ "audit_test" ])

    assert result[:success]

    # Should create audit log entry
    audit_log = CommandAuditLog.last
    assert_equal "save", audit_log.command
    assert_equal @user.id, audit_log.user_id
    assert_equal @document.id, audit_log.document_id
    assert audit_log.execution_time.present?
  end

  private

  def mock_claude_api_success
    ClaudeService.any_instance.stubs(:process_command).returns({
      success: true,
      result: { processed: true }
    })
  end
end
