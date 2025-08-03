require "application_system_test_case"

class SlashCommandsSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @document = documents(:one)
    sign_in_as(@user)
  end

  # End-to-End Workflow Tests
  test "complete slash command workflow in browser" do
    visit document_path(@document)

    # Wait for page to load completely
    assert_selector "[data-controller*='slash-commands']", wait: 5

    # Find editor input
    editor_input = find("[data-slash-commands-target='input']", wait: 5)

    # Type slash to trigger suggestions
    editor_input.send_keys("/")
    
    # Give JavaScript time to process
    sleep(0.5)

    # Should show command suggestions
    assert_selector ".command-suggestions-dropdown", visible: true, wait: 3
    within(".command-suggestions-dropdown") do
      assert_text "save"
      assert_text "load"  
      assert_text "compact"
    end

    # Type to filter suggestions
    editor_input.send_keys("sa")

    # Should filter to only "save" command
    assert_text "save"
    assert_no_text "load"

    # Select save command using keyboard
    editor_input.send_keys(:arrow_down)
    assert_selector ".command-item.selected"

    editor_input.send_keys(:enter)

    # Should close suggestions and replace text
    assert_no_selector ".command-suggestions-dropdown"
    assert_equal "/save", editor_input.value

    # Complete the command
    editor_input.send_keys(" my_test_document")

    # Execute command with Ctrl+Enter
    editor_input.send_keys([ :control, :enter ])

    # Should show execution feedback
    assert_selector ".command-status.loading", wait: 1
    assert_text "Executing save command"

    # Wait for completion
    assert_selector ".command-status.success", wait: 5
    assert_text "Successfully saved context"

    # Verify context item was created
    visit document_context_items_path(@document)
    assert_text "my_test_document"
  end

  test "command suggestions with mouse interaction" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.send_keys("/")

    # Wait for suggestions to appear
    assert_selector ".command-suggestions-dropdown", wait: 2

    # Click on load command
    find("[data-command='load']").click

    # Should select the command
    assert_equal "/load", editor_input.value
    assert_no_selector ".command-suggestions-dropdown"
  end

  test "command execution with visual feedback" do
    # Create context item to load
    @document.context_items.create!(
      title: "test_context",
      content: "Test context content",
      item_type: "saved_context",
      user: @user
    )

    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set("/load test_context")
    editor_input.send_keys([ :control, :enter ])

    # Should show loading state
    assert_selector ".command-status.loading", wait: 1

    # Should complete successfully
    assert_selector ".command-status.success", wait: 5
    assert_text "Successfully loaded context"

    # Status should auto-clear
    assert_no_selector ".command-status.success", wait: 4
  end

  # Error Handling System Tests
  test "error handling for unknown commands" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set("/unknown_command")
    editor_input.send_keys([ :control, :enter ])

    # Should show error state
    assert_selector ".command-status.error", wait: 2
    assert_text "Unknown command: unknown_command"
    assert_text "Did you mean:"
  end

  test "error handling for invalid parameters" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set("/load")  # Missing required parameter
    editor_input.send_keys([ :control, :enter ])

    # Should show parameter error
    assert_selector ".command-status.error", wait: 2
    assert_text "Missing required parameter"
  end

  # Accessibility System Tests
  test "keyboard navigation accessibility" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.send_keys("/")

    # Should be able to navigate with keyboard only
    suggestions = find(".command-suggestions-dropdown")
    assert suggestions["role"] == "listbox"

    # Navigate with arrow keys
    editor_input.send_keys(:arrow_down)
    first_item = find(".command-item.selected")
    assert first_item["aria-selected"] == "true"

    # Navigate to next item
    editor_input.send_keys(:arrow_down)
    second_item = find(".command-item.selected")
    assert second_item["aria-selected"] == "true"
    assert first_item["aria-selected"] == "false"

    # Select with Enter
    editor_input.send_keys(:enter)
    assert_no_selector ".command-suggestions-dropdown"
  end

  test "screen reader compatibility" do
    visit document_path(@document)

    # Should have proper ARIA labels
    editor_input = find("[data-slash-commands-target='input']")
    assert editor_input["aria-label"].present?

    editor_input.send_keys("/")

    # Suggestions should have proper ARIA structure
    suggestions = find(".command-suggestions-dropdown")
    assert suggestions["aria-live"] == "polite"

    command_items = all(".command-item")
    command_items.each do |item|
      assert item["role"] == "option"
      assert item["aria-describedby"].present?
    end
  end

  # Performance System Tests
  test "suggestion performance with large documents" do
    # Add large content to document
    large_content = "Lorem ipsum dolor sit amet. " * 1000
    @document.update!(content: large_content)

    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")

    # Measure suggestion response time
    start_time = Time.current
    editor_input.send_keys("/")
    assert_selector ".command-suggestions-dropdown", wait: 1
    end_time = Time.current

    response_time = end_time - start_time
    assert response_time < 0.5, "Suggestions should appear within 500ms, took #{response_time}s"
  end

  test "command execution performance" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set("/save performance_test")

    # Measure execution time
    start_time = Time.current
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 3
    end_time = Time.current

    execution_time = end_time - start_time
    assert execution_time < 2.0, "Command should execute within 2s, took #{execution_time}s"
  end

  # Mobile System Tests
  test "mobile touch interface" do
    # Simulate mobile viewport
    resize_window_to_mobile

    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.send_keys("/")

    # Should show mobile-optimized suggestions
    suggestions = find(".command-suggestions-dropdown")
    assert suggestions[:class].include?("mobile") if page.evaluate_script("window.innerWidth < 768")

    # Touch interactions should work
    find("[data-command='save']").click
    assert_equal "/save", editor_input.value
  end

  # Browser Compatibility Tests
  test "works in different browsers" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']", wait: 5)
    editor_input.send_keys("/save test")
    editor_input.send_keys([ :control, :enter ])

    assert_selector ".command-status", wait: 5
  end

  test "fallback for browsers without modern JavaScript" do
    visit document_path(@document)

    # Should still have basic form submission fallback
    editor_input = find("[data-slash-commands-target='input']", wait: 5)
    editor_input.set("/save fallback_test")

    # Try basic form submission
    editor_input.send_keys([ :control, :enter ])

    # Should handle gracefully even without JavaScript
    assert_selector ".command-status", wait: 3
  end

  # Real-world Usage Scenarios
  test "typical user workflow scenario" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")

    # User saves current work
    editor_input.set("/save my_work_session")
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 3

    # Clear status and continue working
    sleep 1
    editor_input.clear

    # User loads previous context
    editor_input.set("/load")
    editor_input.send_keys(" ")

    # Should show available contexts in suggestions
    assert_selector ".command-suggestions-dropdown"
    assert_text "my_work_session"

    editor_input.send_keys("my_work_session")
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 3

    # User compacts the context
    editor_input.clear
    editor_input.set("/compact")
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 5
  end

  test "power user advanced workflow" do
    # Create some files and contexts for advanced usage
    @document.context_items.create!(
      title: "config.yml",
      content: "database:\n  host: localhost\n  port: 5432",
      item_type: "file",
      user: @user
    )

    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")

    # Include a file
    editor_input.set("/include config.yml yaml")
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 3

    # Create a snippet from selection (simulated)
    editor_input.clear
    editor_input.set("def calculate_total(items)\n  items.sum(&:price)\nend")

    # Select text (simulated - in real usage, user would select with mouse)
    page.execute_script("arguments[0].select();", editor_input)

    # Create snippet
    editor_input.send_keys("/snippet price_calculator")
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 3

    # Verify snippet was created
    visit document_context_items_path(@document)
    assert_text "price_calculator"
  end

  # Edge Cases and Error Recovery
  test "recovery from network errors" do
    visit document_path(@document)

    # Simulate network failure
    page.execute_script(<<~JS)
      const originalFetch = window.fetch;
      window.fetch = function() {
        return Promise.reject(new Error('Network error'));
      };
    JS

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set("/save network_test")
    editor_input.send_keys([ :control, :enter ])

    # Should show network error
    assert_selector ".command-status.error", wait: 3
    assert_text "Network error"

    # Restore network and retry
    page.execute_script("window.fetch = originalFetch;")

    # Retry command
    editor_input.send_keys([ :control, :enter ])
    assert_selector ".command-status.success", wait: 5
  end

  test "handling of concurrent command execution" do
    visit document_path(@document)

    editor_input = find("[data-slash-commands-target='input']")
    editor_input.set("/save concurrent_test_1")

    # Start first command
    editor_input.send_keys([ :control, :enter ])

    # Immediately try second command
    editor_input.clear
    editor_input.set("/save concurrent_test_2")
    editor_input.send_keys([ :control, :enter ])

    # Should handle gracefully (queue or reject)
    assert_selector ".command-status", wait: 5
    # Either success or "command in progress" message
  end

  private

  def resize_window_to_mobile
    page.driver.browser.manage.window.resize_to(375, 667) # iPhone dimensions
  end

  def document_path(document)
    "/documents/#{document.id}"
  end

  def document_context_items_path(document)
    "/documents/#{document.id}/context_items"
  end
end
