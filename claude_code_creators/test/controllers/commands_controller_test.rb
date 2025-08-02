require "test_helper"

class CommandsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @document = documents(:one)
    @other_user = users(:two)
    @other_document = documents(:two)
    sign_in_as(@user)
  end

  private

  def post_authenticated_command(document, command, parameters = [], options = {})
    # Ensure we have a session for the request
    if Current.session.blank?
      session = @user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
      cookies.signed[:session_id] = session.id
    end

    post document_commands_path(document), params: {
      command: command,
      parameters: parameters,
      **options
    }
  end

  # Authentication Tests
  test "should require authentication for command execution" do
    sign_out
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "test" ]
    }
    assert_response :unauthorized
  end

  test "should reject commands from unauthorized users" do
    sign_out
    sign_in_as(@other_user)

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "test" ]
    }
    assert_response :forbidden
  end

  # Command Execution Tests
  test "should execute save command successfully" do
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "my_context" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert_equal "save", response_data["command"]
    assert response_data["result"].present?
  end

  test "should execute load command successfully" do
    # First create a context item to load
    context_item = @document.context_items.create!(
      title: "test_context",
      content: "Test content",
      item_type: "saved_context",
      user: @user
    )

    post document_commands_path(@document), params: {
      command: "load",
      parameters: [ "test_context" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert_equal "load", response_data["command"]
    assert response_data["result"]["loaded_content"].present?
  end

  test "should execute compact command successfully" do
    # Create some Claude context to compact
    @document.claude_contexts.create!(
      context_data: { "messages" => [ "msg1", "msg2", "msg3" ] },
      user: @user,
      context_type: "document"
    )

    # Mock Claude API response
    claude_service = mock("claude_service")
    claude_service.stubs(:compact_context).returns({
      compacted_messages: [ { "role" => "system", "content" => "Compacted" } ],
      compression_ratio: 0.33
    })
    ClaudeService.stubs(:new).returns(claude_service)

    post document_commands_path(@document), params: {
      command: "compact",
      parameters: []
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert response_data["result"]["compacted_messages"].present?
  end

  test "should execute clear command successfully" do
    post document_commands_path(@document), params: {
      command: "clear",
      parameters: [ "context" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert response_data["result"]["cleared_items"].present?
  end

  test "should execute include command successfully" do
    # Create a context item to include
    context_item = @document.context_items.create!(
      title: "include_test.txt",
      content: "Content to include",
      item_type: "file",
      user: @user
    )

    post document_commands_path(@document), params: {
      command: "include",
      parameters: [ "include_test.txt" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert response_data["result"]["included_content"].present?
  end

  test "should execute snippet command successfully" do
    post document_commands_path(@document), params: {
      command: "snippet",
      parameters: [ "test_snippet" ],
      selected_content: "def test_function\n  return true\nend"
    }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "success", response_data["status"]
    assert response_data["result"]["snippet_id"].present?
  end

  # Parameter Validation Tests
  test "should validate required parameters" do
    post document_commands_path(@document), params: {
      command: "load",
      parameters: []  # Missing required parameter
    }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /required parameter/, response_data["error"]
  end

  test "should validate parameter types" do
    post document_commands_path(@document),
         params: { command: "save", parameters: [ 123 ] }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /invalid parameter type/, response_data["error"]
  end

  test "should validate parameter count" do
    post document_commands_path(@document), params: {
      command: "clear",
      parameters: [ "context", "document", "extra" ]  # Too many
    }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /too many parameters/i, response_data["error"]
  end

  # Error Handling Tests
  test "should handle unknown command gracefully" do
    post document_commands_path(@document), params: {
      command: "unknown_command",
      parameters: []
    }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /Unknown command/, response_data["error"]
    assert response_data["suggestions"].present?
  end

  test "should handle service errors gracefully" do
    # Mock service to raise an error
    CommandExecutionService.any_instance.stubs(:execute).raises(StandardError, "Service error")

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "test" ]
    }

    assert_response :internal_server_error
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /internal error/, response_data["error"]
    assert response_data["error_id"].present?  # For tracking
  end

  test "should handle timeout errors" do
    # Mock service to timeout
    CommandExecutionService.any_instance.stubs(:execute).raises(Timeout::Error)

    post document_commands_path(@document), params: {
      command: "compact",
      parameters: []
    }

    assert_response :request_timeout
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /timeout/, response_data["error"]
  end

  test "should handle Claude API errors" do
    # Create Claude context first
    @document.claude_contexts.create!(
      context_data: { "messages" => [ "test" ] },
      user: @user,
      context_type: "document"
    )

    # Mock Claude service to fail
    claude_service = mock("claude_service")
    claude_service.stubs(:compact_context).raises(ClaudeService::APIError, "API Error")
    ClaudeService.stubs(:new).returns(claude_service)

    post document_commands_path(@document), params: {
      command: "compact",
      parameters: []
    }

    assert_response :service_unavailable
    response_data = JSON.parse(response.body)
    assert_equal "error", response_data["status"]
    assert_match /Claude API/, response_data["error"]
  end

  # Response Format Tests
  test "should return consistent response format for success" do
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "test" ]
    }

    assert_response :success
    response_data = JSON.parse(response.body)

    # Required fields
    assert response_data.key?("status")
    assert response_data.key?("command")
    assert response_data.key?("result")
    assert response_data.key?("execution_time")
    assert response_data.key?("timestamp")

    # Status should be success
    assert_equal "success", response_data["status"]
  end

  test "should return consistent response format for errors" do
    post document_commands_path(@document), params: {
      command: "unknown",
      parameters: []
    }

    assert_response :unprocessable_entity
    response_data = JSON.parse(response.body)

    # Required fields
    assert response_data.key?("status")
    assert response_data.key?("error")
    assert response_data.key?("command")
    assert response_data.key?("timestamp")

    # Status should be error
    assert_equal "error", response_data["status"]
  end

  # Performance Tests
  test "should execute commands within time limit" do
    start_time = Time.current

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "performance_test" ]
    }

    end_time = Time.current
    execution_time = end_time - start_time

    assert_response :success
    assert execution_time < 0.1  # Should complete in under 100ms
  end

  test "should handle concurrent requests" do
    threads = []
    results = []

    5.times do |i|
      threads << Thread.new do
        post document_commands_path(@document), params: {
          command: "save",
          parameters: [ "concurrent_#{i}" ]
        }
        results << response.status
      end
    end

    threads.each(&:join)
    assert results.all? { |status| status == 200 }
  end

  # Rate Limiting Tests
  test "should apply rate limiting to command execution" do
    # Make rapid requests - first 10 should succeed
    10.times do
      post document_commands_path(@document), params: {
        command: "save",
        parameters: [ "rate_limit_test" ]
      }
    end

    # 11th request should hit rate limit
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "rate_limit_test" ]
    }

    assert_response :too_many_requests
    response_data = JSON.parse(response.body)
    assert_match /Rate limit/, response_data["error"]
  end

  # Content Type Tests
  test "should accept JSON content type" do
    post document_commands_path(@document),
         params: { command: "save", parameters: [ "json_test" ] }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :success
  end

  test "should accept form data content type" do
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "form_test" ]
    }

    assert_response :success
  end

  # CSRF Protection Tests
  test "should validate CSRF token for non-API requests" do
    # Remove CSRF token
    ActionController::Base.any_instance.stubs(:verified_request?).returns(false)

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "csrf_test" ]
    }

    assert_response :forbidden
  end

  # Command History Tests
  test "should log command execution history" do
    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "history_test" ]
    }

    assert_response :success

    # Should create command history record
    history = CommandHistory.last
    assert_equal "save", history.command
    assert_equal @user.id, history.user_id
    assert_equal @document.id, history.document_id
  end

  # Document State Tests
  test "should update document state after command execution" do
    original_updated_at = @document.updated_at

    post document_commands_path(@document), params: {
      command: "save",
      parameters: [ "state_test" ]
    }

    assert_response :success
    @document.reload
    assert @document.updated_at > original_updated_at
  end

  private

  def document_commands_path(document)
    "/documents/#{document.id}/commands"
  end
end
