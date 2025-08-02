require "test_helper"

class CommandSuggestionsComponentTest < ViewComponent::TestCase
  def setup
    @user = users(:one)
    @document = documents(:one)
    @component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 100, y: 200 },
      filter: ""
    )
  end

  # Rendering Tests
  test "should render suggestions dropdown" do
    render_inline(@component)

    assert_selector "[data-command-suggestions-target='dropdown']"
    assert_selector ".command-suggestions-dropdown"
    assert_text "Commands"
  end

  test "should render all available commands when no filter" do
    render_inline(@component)

    assert_selector "[data-command='save']"
    assert_selector "[data-command='load']"
    assert_selector "[data-command='compact']"
    assert_selector "[data-command='clear']"
    assert_selector "[data-command='include']"
    assert_selector "[data-command='snippet']"
  end

  test "should filter commands based on input" do
    filtered_component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 100, y: 200 },
      filter: "sa"
    )

    render_inline(filtered_component)

    assert_selector "[data-command='save']"
    assert_no_selector "[data-command='load']"
    assert_no_selector "[data-command='compact']"
  end

  test "should position dropdown correctly" do
    render_inline(@component)

    assert_selector ".command-suggestions-dropdown[style*='left: 100px']"
    assert_selector ".command-suggestions-dropdown[style*='top: 200px']"
  end

  # Command Display Tests
  test "should display command metadata" do
    render_inline(@component)

    # Save command
    save_item = page.find("[data-command='save']")
    assert save_item.has_text?("save")
    assert save_item.has_text?("Save document to various formats")
    assert save_item.has_css?(".command-icon.save-icon")

    # Load command
    load_item = page.find("[data-command='load']")
    assert load_item.has_text?("load")
    assert load_item.has_text?("Load external content")
  end

  test "should show command parameters" do
    render_inline(@component)

    save_item = page.find("[data-command='save']")
    assert save_item.has_text?("[name]")
    assert save_item.has_css?(".parameter.optional")

    load_item = page.find("[data-command='load']")
    assert load_item.has_text?("name")
    assert load_item.has_css?(".parameter.required")
  end

  test "should indicate command categories" do
    render_inline(@component)

    save_item = page.find("[data-command='save']")
    assert save_item.has_css?(".command-category.context")

    include_item = page.find("[data-command='include']")
    assert include_item.has_css?(".command-category.content")
  end

  # Keyboard Navigation Tests
  test "should support keyboard navigation attributes" do
    render_inline(@component)

    dropdown = page.find(".command-suggestions-dropdown")
    assert dropdown["role"] == "listbox"
    assert dropdown["aria-label"].present?

    commands = page.all(".command-item")
    commands.each do |command|
      assert command["role"] == "option"
      assert command["tabindex"] == "-1"
      assert command["aria-selected"] == "false"
    end
  end

  test "should highlight selected command" do
    selected_component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 100, y: 200 },
      filter: "",
      selected_index: 0
    )

    render_inline(selected_component)

    first_command = page.all(".command-item").first
    assert first_command["aria-selected"] == "true"
    assert first_command["class"].include?("selected")
  end

  # Permission-based Display Tests
  test "should hide restricted commands for guest users" do
    guest_user = User.new(role: :guest)
    guest_component = CommandSuggestionsComponent.new(
      document: @document,
      user: guest_user,
      position: { x: 100, y: 200 },
      filter: ""
    )

    render_inline(guest_component)

    assert_no_selector "[data-command='clear']"  # Restricted command
    assert_selector "[data-command='save']"      # Allowed command
  end

  test "should show all commands for admin users" do
    admin_user = users(:one)
    admin_user.update!(role: :admin)

    admin_component = CommandSuggestionsComponent.new(
      document: @document,
      user: admin_user,
      position: { x: 100, y: 200 },
      filter: ""
    )

    render_inline(admin_component)

    assert_selector "[data-command='save']"
    assert_selector "[data-command='load']"
    assert_selector "[data-command='compact']"
    assert_selector "[data-command='clear']"
    assert_selector "[data-command='include']"
    assert_selector "[data-command='snippet']"
  end

  # Context-aware Display Tests
  test "should show context-specific suggestions" do
    # Document with existing context items
    @document.context_items.create!(
      title: "existing_context",
      item_type: "saved_context",
      content: "Sample saved context content",
      user: @user
    )

    render_inline(@component)

    load_item = page.find("[data-command='load']")
    assert load_item.has_text?("existing_context")
    assert load_item.has_css?(".context-hint")
  end

  test "should indicate available files for include command" do
    @document.context_items.create!(
      title: "available_file.txt",
      item_type: "file",
      content: "Sample file content",
      user: @user
    )

    render_inline(@component)

    include_item = page.find("[data-command='include']")
    assert include_item.has_text?("available_file.txt")
    assert include_item.has_css?(".file-hint")
  end

  test "should show Claude context status for context commands" do
    # Create Claude context
    @document.claude_contexts.create!(
      context_data: { "messages" => [ "test" ] },
      user: @user
    )

    render_inline(@component)

    compact_item = page.find("[data-command='compact']")
    assert compact_item.has_css?(".context-available")

    clear_item = page.find("[data-command='clear']")
    assert clear_item.has_css?(".context-available")
  end

  # Visual Design Tests
  test "should apply correct CSS classes" do
    render_inline(@component)

    assert_selector ".command-suggestions-dropdown.fade-in"
    assert_selector ".command-list"
    assert_selector ".command-item.interactive"

    # Each command should have proper styling
    page.all(".command-item").each do |item|
      assert item.has_css?(".command-name")
      assert item.has_css?(".command-description")
      assert item.has_css?(".command-parameters")
    end
  end

  test "should show empty state when no commands match filter" do
    no_match_component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 100, y: 200 },
      filter: "xyz"
    )

    render_inline(no_match_component)

    assert_text "No commands found"
    assert_selector ".empty-state"
    assert_no_selector ".command-item"
  end

  # Interactive Features Tests
  test "should include data attributes for JavaScript interaction" do
    render_inline(@component)

    dropdown = page.find(".command-suggestions-dropdown")
    assert dropdown["data-controller"] == "command-suggestions"
    assert dropdown["data-command-suggestions-document-id-value"] == @document.id.to_s

    commands = page.all(".command-item")
    commands.each do |command|
      assert command["data-action"].include?("click->command-suggestions#selectCommand")
      assert command["data-command"].present?
    end
  end

  test "should provide hover targets for interactions" do
    render_inline(@component)

    commands = page.all(".command-item")
    commands.each do |command|
      assert command["data-action"].include?("mouseenter->command-suggestions#highlightCommand")
      assert command["data-action"].include?("mouseleave->command-suggestions#unhighlightCommand")
    end
  end

  # Responsive Design Tests
  test "should adjust position for viewport boundaries" do
    # Test component near right edge
    edge_component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 1200, y: 200 },
      filter: ""
    )

    render_inline(edge_component)

    dropdown = page.find(".command-suggestions-dropdown")
    # Should adjust position to stay within viewport
    assert dropdown["style"].include?("left:")
    assert dropdown["class"].include?("position-adjusted")
  end

  test "should handle mobile viewport" do
    mobile_component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 50, y: 100 },
      filter: "",
      mobile: true
    )

    render_inline(mobile_component)

    assert_selector ".command-suggestions-dropdown.mobile"
    assert_selector ".command-item.mobile-friendly"
  end

  # Performance Tests
  test "should limit number of displayed commands" do
    # Component with limit
    limited_component = CommandSuggestionsComponent.new(
      document: @document,
      user: @user,
      position: { x: 100, y: 200 },
      filter: "",
      limit: 3
    )

    render_inline(limited_component)

    commands = page.all(".command-item")
    assert commands.length <= 3
  end

  # Accessibility Tests
  test "should provide proper ARIA attributes" do
    render_inline(@component)

    dropdown = page.find(".command-suggestions-dropdown")
    assert dropdown["role"] == "listbox"
    assert dropdown["aria-label"] == "Available slash commands"
    assert dropdown["aria-live"] == "polite"

    commands = page.all(".command-item")
    commands.each_with_index do |command, index|
      assert command["role"] == "option"
      assert command["aria-describedby"].present?
      assert command["id"] == "command-option-#{index}"
    end
  end

  test "should support screen reader announcements" do
    render_inline(@component)

    # Should have announcement region
    assert_selector ".sr-only[aria-live='polite']"

    # Commands should have proper descriptions
    commands = page.all(".command-item")
    commands.each do |command|
      description_id = command["aria-describedby"]
      assert page.has_selector?("##{description_id}")
    end
  end

  # Error Handling Tests
  test "should handle missing document gracefully" do
    nil_doc_component = CommandSuggestionsComponent.new(
      document: nil,
      user: @user,
      position: { x: 100, y: 200 },
      filter: ""
    )

    render_inline(nil_doc_component)

    assert_text "No document context"
    assert_selector ".error-state"
  end

  test "should handle permission errors gracefully" do
    # Mock permission check to fail
    Pundit.stubs(:policy).raises(Pundit::NotAuthorizedError)

    render_inline(@component)

    assert_text "Access denied"
    assert_selector ".permission-error"
  end

  # Integration Tests
  test "should integrate with Stimulus controller" do
    render_inline(@component)

    dropdown = page.find(".command-suggestions-dropdown")
    assert dropdown["data-controller"].include?("command-suggestions")

    # Should have targets defined
    assert dropdown["data-command-suggestions-target"] == "dropdown"

    # Should have action handlers
    commands = page.all(".command-item")
    commands.each do |command|
      assert command["data-action"].present?
    end
  end

  test "should work with Turbo frames" do
    skip "ViewComponent turbo-frame integration not yet implemented"
    render_inline(@component) do |component|
      component.with_turbo_frame("command-suggestions")
    end

    assert_selector "turbo-frame#command-suggestions"
    assert_selector "turbo-frame .command-suggestions-dropdown"
  end

  private

  def default_component_params
    {
      document: @document,
      user: @user,
      position: { x: 100, y: 200 },
      filter: ""
    }
  end
end
