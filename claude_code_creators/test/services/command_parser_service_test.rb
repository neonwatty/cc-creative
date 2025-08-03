require "test_helper"

class CommandParserServiceTest < ActiveSupport::TestCase
  def setup
    @document = documents(:one)
    @user = users(:one)
    @service = CommandParserService.new(@document, @user)
  end

  # Command Registry Tests
  test "should register default slash commands" do
    assert_includes CommandParserService.registered_commands, "save"
    assert_includes CommandParserService.registered_commands, "load"
    assert_includes CommandParserService.registered_commands, "compact"
    assert_includes CommandParserService.registered_commands, "clear"
    assert_includes CommandParserService.registered_commands, "include"
    assert_includes CommandParserService.registered_commands, "snippet"
  end

  test "should get command metadata" do
    metadata = CommandParserService.command_metadata("save")
    assert_equal "Save document to various formats", metadata[:description]
    assert_equal [ "name" ], metadata[:parameters]
    assert_equal :context, metadata[:category]
  end

  test "should raise error for unregistered command metadata" do
    assert_raises(CommandParserService::UnknownCommandError) do
      CommandParserService.command_metadata("unknown")
    end
  end

  # Command Parsing Tests
  test "should parse simple slash command" do
    result = @service.parse("/save")
    assert_equal "save", result[:command]
    assert_empty result[:parameters]
    assert_equal "/save", result[:raw_input]
  end

  test "should parse slash command with single parameter" do
    result = @service.parse("/save my_document")
    assert_equal "save", result[:command]
    assert_equal [ "my_document" ], result[:parameters]
    assert_equal "/save my_document", result[:raw_input]
  end

  test "should parse slash command with multiple parameters" do
    result = @service.parse("/include file.txt markdown")
    assert_equal "include", result[:command]
    assert_equal [ "file.txt", "markdown" ], result[:parameters]
    assert_equal "/include file.txt markdown", result[:raw_input]
  end

  test "should parse slash command with quoted parameters" do
    result = @service.parse('/save "my document with spaces"')
    assert_equal "save", result[:command]
    assert_equal [ "my document with spaces" ], result[:parameters]
  end

  test "should parse slash command with mixed quoted and unquoted parameters" do
    result = @service.parse('/include "file name.txt" html section1')
    assert_equal "include", result[:command]
    assert_equal [ "file name.txt", "html", "section1" ], result[:parameters]
  end

  test "should handle empty slash command" do
    result = @service.parse("/")
    assert_nil result[:command]
    assert_empty result[:parameters]
    assert result[:error].present?
  end

  test "should detect non-slash command input" do
    result = @service.parse("regular text")
    assert_nil result[:command]
    assert result[:error].present?
    assert_match /not a valid slash command/, result[:error]
  end

  # Command Validation Tests
  test "should validate known commands" do
    assert @service.valid_command?("save")
    assert @service.valid_command?("load")
    assert @service.valid_command?("compact")
    assert @service.valid_command?("clear")
    assert @service.valid_command?("include")
    assert @service.valid_command?("snippet")
  end

  test "should reject unknown commands" do
    assert_not @service.valid_command?("unknown")
    assert_not @service.valid_command?("invalid")
  end

  test "should validate save command parameters" do
    assert @service.valid_parameters?("save", [ "document_name" ])
    assert @service.valid_parameters?("save", [])  # name is optional
    assert_not @service.valid_parameters?("save", [ "name1", "name2", "name3" ])  # too many
  end

  test "should validate load command parameters" do
    assert @service.valid_parameters?("load", [ "context_name" ])
    assert_not @service.valid_parameters?("load", [])  # name is required
    assert_not @service.valid_parameters?("load", [ "name1", "name2" ])  # too many
  end

  test "should validate compact command parameters" do
    assert @service.valid_parameters?("compact", [])
    assert @service.valid_parameters?("compact", [ "aggressive" ])
    assert_not @service.valid_parameters?("compact", [ "invalid", "params" ])
  end

  test "should validate clear command parameters" do
    assert @service.valid_parameters?("clear", [])
    assert @service.valid_parameters?("clear", [ "context" ])
    assert @service.valid_parameters?("clear", [ "document" ])
    assert_not @service.valid_parameters?("clear", [ "invalid" ])
  end

  test "should validate include command parameters" do
    assert @service.valid_parameters?("include", [ "file.txt" ])
    assert @service.valid_parameters?("include", [ "file.txt", "markdown" ])
    assert_not @service.valid_parameters?("include", [])  # file is required
  end

  test "should validate snippet command parameters" do
    assert @service.valid_parameters?("snippet", [])
    assert @service.valid_parameters?("snippet", [ "snippet_name" ])
    assert_not @service.valid_parameters?("snippet", [ "name", "extra", "params" ])
  end

  # Command Suggestion Tests
  test "should suggest commands based on partial input" do
    suggestions = @service.suggest_commands("sa")
    assert_includes suggestions, "save"
    assert_not_includes suggestions, "load"
  end

  test "should suggest commands based on empty input" do
    suggestions = @service.suggest_commands("")
    assert_equal 9, suggestions.length
    assert_includes suggestions, "save"
    assert_includes suggestions, "load"
    assert_includes suggestions, "compact"
    assert_includes suggestions, "clear"
    assert_includes suggestions, "include"
    assert_includes suggestions, "snippet"
    assert_includes suggestions, "review"
    assert_includes suggestions, "suggest"
    assert_includes suggestions, "critique"
  end

  test "should suggest commands with descriptions" do
    suggestions = @service.suggest_commands_with_metadata("c")
    compact_suggestion = suggestions.find { |s| s[:command] == "compact" }
    clear_suggestion = suggestions.find { |s| s[:command] == "clear" }

    assert compact_suggestion.present?
    assert clear_suggestion.present?
    assert compact_suggestion[:description].present?
    assert clear_suggestion[:description].present?
  end

  test "should limit suggestions to maximum count" do
    suggestions = @service.suggest_commands("", limit: 3)
    assert_equal 3, suggestions.length
  end

  # Error Handling Tests
  test "should handle malformed command input gracefully" do
    result = @service.parse("/save'unclosed quote")
    assert result[:error].present?
    assert_match /malformed command/, result[:error]
  end

  test "should provide helpful error messages for unknown commands" do
    result = @service.parse("/unknown_command")
    assert result[:error].present?
    assert_match /Unknown command: unknown_command/, result[:error]
    assert_match /Did you mean/, result[:error]  # Should suggest similar commands
  end

  test "should validate command permissions" do
    guest_user = User.new(role: :guest)
    guest_service = CommandParserService.new(@document, guest_user)

    result = guest_service.validate_permissions("save")
    assert_not result[:allowed]
    assert result[:error].present?
    assert_match /insufficient permissions/, result[:error]
  end

  test "should validate document access" do
    other_document = Document.create!(title: "Other Doc", content: "Some content", user: users(:two))
    result = @service.validate_document_access(other_document)

    assert_not result[:allowed]
    assert result[:error].present?
    assert_match /access denied/, result[:error]
  end

  # Command Context Tests
  test "should build execution context" do
    context = @service.build_execution_context("save", [ "test_name" ])

    assert_equal @document, context[:document]
    assert_equal @user, context[:user]
    assert_equal "save", context[:command]
    assert_equal [ "test_name" ], context[:parameters]
    assert context[:timestamp].present?
    assert context[:session_id].present?
  end

  test "should include Claude context in execution context" do
    # Create some Claude context
    @document.claude_contexts.create!(
      context_data: { "messages" => [ "test message" ] }.to_json,
      user: @user
    )

    context = @service.build_execution_context("compact", [])
    assert context[:claude_context].present?
    assert_equal 1, context[:claude_context]["messages"].length
  end

  # Performance Tests
  test "should parse commands quickly" do
    start_time = Time.current
    1000.times { @service.parse("/save test_document") }
    end_time = Time.current

    # Should complete 1000 parses in under 100ms
    assert (end_time - start_time) < 0.1
  end

  test "should suggest commands quickly" do
    start_time = Time.current
    1000.times { @service.suggest_commands("sa") }
    end_time = Time.current

    # Should complete 1000 suggestions in under 50ms
    assert (end_time - start_time) < 0.05
  end

  # Integration Tests
  test "should integrate with existing document structure" do
    parsed = @service.parse("/save integration_test")
    context = @service.build_execution_context(parsed[:command], parsed[:parameters])

    assert_equal @document.id, context[:document].id
    assert_equal @document.title, context[:document].title
  end

  test "should integrate with user permissions" do
    admin_user = users(:one)  # Assuming fixture has admin
    admin_user.update!(role: :admin)
    admin_service = CommandParserService.new(@document, admin_user)

    result = admin_service.validate_permissions("clear")
    assert result[:allowed]
    assert result[:error].blank?
  end

  private

  def assert_command_structure(result)
    assert result.key?(:command)
    assert result.key?(:parameters)
    assert result.key?(:raw_input)
    assert result.key?(:timestamp)
  end
end
