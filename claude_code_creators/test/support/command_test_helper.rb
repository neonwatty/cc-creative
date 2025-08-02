module CommandTestHelper
  # Command parsing test helpers
  def assert_command_parsed(input, expected_command, expected_params = [])
    result = CommandParserService.new(@document, @user).parse(input)
    assert_equal expected_command, result[:command], "Expected command '#{expected_command}', got '#{result[:command]}'"
    assert_equal expected_params, result[:parameters], "Expected parameters #{expected_params}, got #{result[:parameters]}"
  end

  def assert_command_invalid(input, expected_error_pattern = nil)
    result = CommandParserService.new(@document, @user).parse(input)
    assert result[:error].present?, "Expected command to be invalid, but no error was present"
    if expected_error_pattern
      assert_match expected_error_pattern, result[:error], "Error message doesn't match expected pattern"
    end
  end

  # Command execution test helpers
  def execute_command(command, parameters = [], options = {})
    service = CommandExecutionService.new(@document, @user)
    service.execute(command, parameters, options)
  end

  def assert_command_success(command, parameters = [], options = {})
    result = execute_command(command, parameters, options)
    assert result[:success], "Expected command '#{command}' to succeed, but got error: #{result[:error]}"
    result
  end

  def assert_command_failure(command, parameters = [], expected_error_pattern = nil)
    result = execute_command(command, parameters)
    assert_not result[:success], "Expected command '#{command}' to fail, but it succeeded"
    if expected_error_pattern
      assert_match expected_error_pattern, result[:error], "Error message doesn't match expected pattern"
    end
    result
  end

  # API endpoint test helpers
  def post_command(document, command, parameters = [], options = {})
    post "/documents/#{document.id}/commands", params: {
      command: command,
      parameters: parameters,
      **options
    }
  end

  def assert_api_success(response_body = nil)
    response_body ||= JSON.parse(response.body)
    assert_equal "success", response_body["status"]
    assert response_body["result"].present?
    response_body
  end

  def assert_api_error(response_body = nil, expected_error_pattern = nil)
    response_body ||= JSON.parse(response.body)
    assert_equal "error", response_body["status"]
    assert response_body["error"].present?
    if expected_error_pattern
      assert_match expected_error_pattern, response_body["error"]
    end
    response_body
  end

  # Context item test helpers
  def create_context_item(title, content, type = "note", options = {})
    @document.context_items.create!({
      title: title,
      content: content,
      item_type: type,
      user: @user
    }.merge(options))
  end

  def create_saved_context(name, messages = [])
    context_data = messages.empty? ? default_claude_messages : { "messages" => messages }
    create_context_item(name, JSON.dump(context_data), "saved_context")
  end

  def create_file_item(filename, content, format = nil)
    create_context_item(filename, content, "file", format: format)
  end

  def create_snippet(name, code, language = nil)
    create_context_item(name, code, "snippet", metadata: { language: language })
  end

  # Claude context test helpers
  def create_claude_context(messages = nil)
    messages ||= default_claude_messages
    @document.claude_contexts.create!(
      context_data: { "messages" => messages },
      user: @user
    )
  end

  def default_claude_messages
    [
      { "role" => "user", "content" => "Hello, I need help with my project" },
      { "role" => "assistant", "content" => "I'd be happy to help you with your project. What specific area would you like assistance with?" },
      { "role" => "user", "content" => "I'm working on implementing slash commands" },
      { "role" => "assistant", "content" => "Slash commands are a great way to provide quick actions. Let me help you design the system." }
    ]
  end

  # Permission test helpers
  def with_user_role(role)
    original_role = @user.role
    @user.update!(role: role)
    yield
  ensure
    @user.update!(role: original_role)
  end

  def with_guest_user
    original_user = @user
    @user = User.create!(
      email_address: "guest@example.com",
      password: "password",
      role: :guest
    )
    yield
  ensure
    @user.destroy
    @user = original_user
  end

  # Mock helpers
  def mock_claude_api_success(response_data = {})
    default_response = {
      "compacted_messages" => [
        { "role" => "system", "content" => "Conversation summary" }
      ],
      "compression_ratio" => 0.3
    }
    ClaudeService.any_instance.stubs(:compact_context).returns(default_response.merge(response_data))
  end

  def mock_claude_api_error(error_message = "API Error")
    ClaudeService.any_instance.stubs(:compact_context).raises(ClaudeService::APIError, error_message)
  end

  def mock_service_timeout
    CommandExecutionService.any_instance.stubs(:execute).raises(Timeout::Error)
  end

  # Performance test helpers
  def measure_execution_time
    start_time = Time.current
    yield
    Time.current - start_time
  end

  def assert_performance_within(seconds)
    execution_time = measure_execution_time { yield }
    assert execution_time < seconds, "Operation took #{execution_time}s, expected under #{seconds}s"
  end

  # Assertion helpers
  def assert_context_item_created(title, type = nil)
    item = @document.context_items.find_by(title: title)
    assert item.present?, "Expected context item '#{title}' to be created"
    assert_equal type, item.item_type if type
    item
  end

  def assert_claude_context_updated
    assert @document.claude_contexts.exists?, "Expected Claude context to be updated"
    @document.claude_contexts.last
  end

  def assert_document_updated
    @document.reload
    assert @document.updated_at > 1.minute.ago, "Expected document to be recently updated"
  end

  # Data cleanup helpers
  def cleanup_command_data
    CommandHistory.delete_all
    CommandAuditLog.delete_all
    @document.context_items.destroy_all
    @document.claude_contexts.destroy_all
  end

  # JavaScript test helpers (for system tests)
  def wait_for_command_suggestions
    assert_selector ".command-suggestions-dropdown", wait: 2
  end

  def wait_for_command_execution
    assert_selector ".command-status.loading", wait: 1
    assert_selector ".command-status.success, .command-status.error", wait: 5
  end

  def select_command_suggestion(command_name)
    find("[data-command='#{command_name}']").click
  end

  def execute_command_in_editor(command_text)
    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set(command_text)
    editor_input.send_keys([:control, :enter])
  end

  # Validation helpers
  def valid_command_response?(response_data)
    response_data.key?("status") &&
      response_data.key?("command") &&
      response_data.key?("result") &&
      response_data.key?("execution_time") &&
      response_data.key?("timestamp")
  end

  def valid_error_response?(response_data)
    response_data.key?("status") &&
      response_data["status"] == "error" &&
      response_data.key?("error") &&
      response_data.key?("command") &&
      response_data.key?("timestamp")
  end
end

# Include in test cases
ActiveSupport::TestCase.include CommandTestHelper
ActionDispatch::IntegrationTest.include CommandTestHelper

# Only include if ApplicationSystemTestCase is defined
if defined?(ApplicationSystemTestCase)
  ApplicationSystemTestCase.include CommandTestHelper
end