require "test_helper"

class SlashCommandsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @document = documents(:one)
    sign_in_as(@user)
  end

  # Full Workflow Integration Tests
  test "complete slash command workflow from detection to execution" do
    # Visit document page
    get document_path(@document)
    assert_response :success

    # Verify slash command controller is loaded
    assert_select "[data-controller*='slash-commands']"
    assert_select "[data-slash-commands-document-id-value='#{@document.id}']"

    # Simulate typing slash command
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "integration_test" ],
      xhr: true
    }, headers: { "Content-Type" => "application/json" }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert_equal "save", response_data["command"]

    # Verify context item was created
    context_item = @document.context_items.find_by(title: "integration_test")
    assert context_item.present?
    assert_equal "saved_context", context_item.item_type
  end

  test "command suggestions integration with document state" do
    # Create some context items
    @document.context_items.create!(
      title: "existing_context",
      content: "Test content",
      item_type: "saved_context",
      user: @user
    )

    @document.context_items.create!(
      title: "test_file.txt",
      content: "File content",
      item_type: "file",
      user: @user
    )

    # Request command suggestions
    get document_command_suggestions_path(@document), params: {
      filter: "",
      position: { x: 100, y: 200 }
    }, xhr: true

    assert_response :success

    # Should include context-aware suggestions
    assert_match /existing_context/, response.body
    assert_match /test_file\.txt/, response.body
    assert_match /data-command="load"/, response.body
    assert_match /data-command="include"/, response.body
  end

  # Save Command Integration Tests
  test "save command integration with Claude context" do
    # Create Claude context
    claude_context = @document.claude_contexts.create!(
      context_data: {
        "messages" => [
          { "role" => "user", "content" => "Test message 1" },
          { "role" => "assistant", "content" => "Test response 1" }
        ]
      },
      user: @user
    )

    # Execute save command
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "claude_integration_test" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data["result"]["context_item_id"].present?

    # Verify context item contains Claude context
    context_item = ContextItem.find(response_data["result"]["context_item_id"])
    assert context_item.content.include?("Test message 1")
    assert context_item.content.include?("Test response 1")
  end

  # Load Command Integration Tests
  test "load command integration with Claude context update" do
    # Create context item to load
    context_item = @document.context_items.create!(
      title: "load_integration_test",
      content: JSON.dump({
        "messages" => [
          { "role" => "user", "content" => "Loaded message" },
          { "role" => "assistant", "content" => "Loaded response" }
        ]
      }),
      item_type: "saved_context",
      user: @user
    )

    # Execute load command
    post document_commands_path(@document), params: {
      command: "load",
      parameters: [ "load_integration_test" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data["result"]["claude_context_updated"]

    # Verify Claude context was updated
    claude_context = @document.claude_contexts.last
    assert claude_context.present?
    assert claude_context.context_data["messages"].any? { |m| m["content"] == "Loaded message" }
  end

  # Compact Command Integration Tests
  test "compact command integration with Claude API" do
    # Create large Claude context
    messages = []
    20.times do |i|
      messages << { "role" => "user", "content" => "User message #{i}" }
      messages << { "role" => "assistant", "content" => "Assistant response #{i}" }
    end

    @document.claude_contexts.create!(
      context_data: { "messages" => messages },
      user: @user
    )

    # Mock Claude API response
    mock_claude_response = {
      "compacted_messages" => [
        { "role" => "system", "content" => "Conversation summary: Test discussion about topics 1-20" }
      ],
      "compression_ratio" => 0.05
    }

    # Mock the ClaudeService
    ClaudeService.any_instance.expects(:compact_context).returns(mock_claude_response)

    # Execute compact command
    post document_commands_path(@document), params: {
      command: "compact",
      parameters: []
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal 40, response_data["result"]["original_message_count"]
    assert_equal 1, response_data["result"]["compacted_message_count"]
    assert_equal 0.05, response_data["result"]["compression_ratio"]
  end

  # Clear Command Integration Tests
  test "clear command integration with context cleanup" do
    # Create various contexts to clear
    claude_context = @document.claude_contexts.create!(
      context_data: { "messages" => [ "test" ] },
      user: @user
    )

    sub_agent = @document.sub_agents.create!(
      name: "Test Agent",
      role: "helper",
      user: @user
    )

    # Execute clear command
    post document_commands_path(@document), params: {
      command: "clear",
      parameters: [ "context" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data["result"]["cleared_items"] > 0

    # Verify contexts were cleared
    assert_not ClaudeContext.exists?(claude_context.id)

    # Document should still exist
    assert Document.exists?(@document.id)
  end

  # Include Command Integration Tests
  test "include command integration with file processing" do
    # Create file to include
    file_content = "# Test File\n\nThis is test content\nwith multiple lines."
    file_item = @document.context_items.create!(
      title: "include_test.md",
      content: file_content,
      item_type: "file",
      user: @user
    )

    # Execute include command
    post document_commands_path(@document), params: {
      command: "include",
      parameters: [ "include_test.md", "markdown" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "include_test.md", response_data["result"]["included_file"]
    assert_equal "markdown", response_data["result"]["format"]
    assert response_data["result"]["claude_context_updated"]

    # Verify Claude context includes the file
    claude_context = @document.claude_contexts.last
    context_content = claude_context.context_data["messages"].last["content"]
    assert context_content.include?(file_content)
  end

  # Snippet Command Integration Tests
  test "snippet command integration with content creation" do
    selected_content = <<~CODE
      def calculate_total(items)
        items.sum(&:price) * (1 + tax_rate)
      end
    CODE

    # Execute snippet command
    post document_commands_path(@document), params: {
      command: "snippet",
      parameters: [ "price_calculator" ],
      selected_content: selected_content
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "price_calculator", response_data["result"]["snippet_name"]
    assert response_data["result"]["snippet_id"].present?

    # Verify snippet was created as context item
    snippet = ContextItem.find(response_data["result"]["snippet_id"])
    assert_equal "price_calculator", snippet.title
    assert_equal "snippet", snippet.item_type
    assert_equal selected_content.strip, snippet.content.strip
  end

  # Error Handling Integration Tests
  test "integration error handling for invalid commands" do
    post document_commands_path(@document), params: {
      command: "invalid_command",
      parameters: []
    }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /Unknown command/, response_data["error"]
    assert response_data["suggestions"].present?
  end

  test "integration error handling for permission denied" do
    # Sign in as different user
    other_user = users(:two)
    sign_out
    sign_in_as(other_user)

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "unauthorized_test" ]
    }

    assert_response :forbidden
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /access denied/i, response_data["error"]
  end

  test "integration error handling for service failures" do
    # Mock service to fail
    CommandExecutionService.any_instance.stubs(:execute).raises(StandardError, "Service unavailable")

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "service_error_test" ]
    }

    assert_response :internal_server_error
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert response_data["error_id"].present?
  end

  # Performance Integration Tests
  test "integration performance with large documents" do
    # Create large document content
    large_content = "Lorem ipsum dolor sit amet. " * 10000
    @document.update!(rich_text_content: large_content)

    # Create many context items
    50.times do |i|
      @document.context_items.create!(
        title: "item_#{i}",
        content: "Content #{i}",
        item_type: "snippet",
        user: @user
      )
    end

    start_time = Time.current
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "performance_test" ]
    }
    end_time = Time.current

    assert_response :success
    assert (end_time - start_time) < 1.0  # Should complete in under 1 second
  end

  # Real-time Updates Integration Tests
  test "integration with ActionCable for real-time updates" do
    # This would test WebSocket integration if implemented
    # For now, verify the structure exists

    get document_path(@document)
    assert_response :success

    # Should have ActionCable connection setup
    assert_select "[data-controller*='presence']" # Existing presence system
    # Future: assert_select "[data-controller*='command-status']"
  end

  # Multi-user Integration Tests
  test "integration with concurrent user access" do
    # Create second user session
    other_user = users(:two)

    # Grant access to document
    @document.update!(user: @user) # Ensure ownership

    # Both users execute commands simultaneously
    threads = []
    results = []

    threads << Thread.new do
      post document_commands_path(@document), params: {
        command: "save",
        parameters: [ "user1_concurrent" ]
      }
      results << response.status
    end

    # Switch to other user (in real app, this would be separate session)
    threads << Thread.new do
      # Simulate second user action
      context_item = @document.context_items.create!(
        title: "user2_context",
        content: "Concurrent content",
        item_type: "snippet",
        user: other_user
      )
      results << (context_item.persisted? ? 200 : 500)
    end

    threads.each(&:join)

    # Both operations should succeed
    assert results.all? { |status| [ 200, 201 ].include?(status) }
  end

  # Mobile Integration Tests
  test "integration with mobile viewport and touch interfaces" do
    # Simulate mobile request
    get document_path(@document), headers: {
      "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15",
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"
    }

    assert_response :success

    # Should have mobile-optimized command interface
    assert_select "[data-controller*='slash-commands']"
    # Future mobile-specific assertions would go here
  end

  # Accessibility Integration Tests
  test "integration with screen readers and keyboard navigation" do
    get document_path(@document)
    assert_response :success

    # Should have proper ARIA attributes
    assert_select "[role='textbox'][aria-label]" # Editor input
    assert_select "[data-controller*='slash-commands']"

    # Command suggestions should be accessible
    get document_command_suggestions_path(@document), params: { filter: "" }, xhr: true
    assert_response :success
    assert_match /role="listbox"/, response.body
    assert_match /aria-label/, response.body
  end

  # Data Consistency Integration Tests
  test "integration data consistency across command operations" do
    original_version = @document.current_version_number || 0

    # Execute multiple commands that should maintain consistency
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "consistency_test_1" ]
    }
    assert_response :success

    post document_commands_path(@document), params: {
      command: "load",
      parameters: [ "consistency_test_1" ]
    }
    assert_response :success

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "consistency_test_2" ]
    }
    assert_response :success

    # Verify document version was updated appropriately
    @document.reload
    assert @document.current_version_number > original_version

    # Verify all context items exist
    assert @document.context_items.find_by(title: "consistency_test_1").present?
    assert @document.context_items.find_by(title: "consistency_test_2").present?
  end

  # Browser Compatibility Integration Tests
  test "integration with different browser capabilities" do
    # Test with older browser (simulated)
    get document_path(@document), headers: {
      "User-Agent" => "Mozilla/5.0 (compatible; MSIE 11.0; Windows NT 10.0)"
    }

    assert_response :success

    # Should still have basic command functionality
    assert_select "[data-controller*='slash-commands']"

    # Execute command via fallback method
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "browser_compat_test" ]
    }

    assert_response :success
  end

  private

  def document_commands_path(document)
    "/documents/#{document.id}/commands"
  end

  def document_command_suggestions_path(document)
    "/documents/#{document.id}/command_suggestions"
  end
end
