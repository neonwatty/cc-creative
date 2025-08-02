require "application_system_test_case"

class SubAgentWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @document = documents(:one)
    sign_in_as(@user)
  end

  test "complete sub-agent workflow from creation to merge" do
    # Visit document page
    visit document_path(@document)

    # Open sub-agents sidebar
    click_button "Sub-Agents"
    assert_selector ".sub-agent-sidebar"

    # Create new sub-agent
    click_button "New Agent"
    assert_selector "h1", text: "New Sub-Agent"

    fill_in "Name", with: "Rails Development Assistant"
    select "Rails/Ruby Expert", from: "Agent type"
    click_button "Create Sub agent"

    # Verify creation and redirect
    assert_text "Sub-agent was successfully created and initialized"
    assert_selector "h1", text: "Rails Development Assistant"
    assert_selector ".status-badge", text: "Active"

    # Start conversation
    fill_in "message_input", with: "Help me create a new model for blog posts"
    click_button "Send"

    # Wait for response
    assert_selector ".message.user-message", text: "Help me create a new model"
    assert_selector ".message.assistant-message", wait: 5

    # Send follow-up
    fill_in "message_input", with: "Can you also add validations?"
    click_button "Send"

    assert_selector ".message.user-message", text: "Can you also add validations?"
    assert_selector ".message.assistant-message", count: 2, wait: 5

    # Test merge functionality
    click_button "Merge to Document"
    assert_selector ".sub-agent-merge"

    # Configure merge options
    check "Include agent name"
    check "Add separator"
    select "End of document", from: "merge_position"

    # Preview and confirm merge
    assert_selector ".content-preview"
    click_button "Merge Content"

    # Confirm in dialog
    within ".confirm-dialog" do
      click_button "Yes, Merge"
    end

    assert_text "Content merged successfully"

    # Verify document was updated
    visit document_path(@document)
    assert_text "Content from Rails Development Assistant"
  end

  test "managing multiple sub-agents" do
    # Create multiple sub-agents
    agents = []
    [ "Rails Expert", "JavaScript Expert", "CSS Expert" ].each_with_index do |name, i|
      visit new_document_sub_agent_path(@document)

      fill_in "Name", with: name
      select name.split(" ").first + " Expert", from: "Agent type"
      click_button "Create Sub agent"

      agents << SubAgent.last
      visit document_path(@document)
    end

    # Open sidebar with multiple agents
    click_button "Sub-Agents"

    agents.each do |agent|
      assert_selector ".sub-agent-item", text: agent.name
    end

    # Test filtering
    select "Rails/Ruby Expert", from: "Filter by type"
    assert_selector ".sub-agent-item", count: 1
    assert_text "Rails Expert"

    # Test agent activation/deactivation
    within ".sub-agent-item", text: "Rails Expert" do
      click_button "Pause"
    end

    assert_selector ".status-badge", text: "Idle"

    # Switch between agents
    click_on "JavaScript Expert"
    assert_selector "h1", text: "JavaScript Expert"

    click_on "CSS Expert"
    assert_selector "h1", text: "CSS Expert"
  end

  test "sub-agent conversation with real-time updates" do
    sub_agent = SubAgent.create!(
      name: "Test Agent",
      agent_type: "ruby-rails-expert",
      user: @user,
      document: @document
    )

    visit document_sub_agent_path(@document, sub_agent)

    # Send message
    fill_in "message_input", with: "Hello, agent!"

    # Test keyboard shortcut
    find("#message_input").send_keys [ :control, :enter ]

    assert_selector ".message.user-message", text: "Hello, agent!"

    # Simulate real-time message from ActionCable
    page.execute_script <<~JS
      const controller = document.querySelector('[data-controller="sub-agent-conversation"]')._stimulusController
      controller.received({
        message: {
          id: 999,
          role: 'assistant',
          content: 'Hello! How can I help you?',
          html: '<div class="message assistant-message">Hello! How can I help you?</div>'
        }
      })
    JS

    assert_selector ".message.assistant-message", text: "Hello! How can I help you?"
  end

  test "error handling and recovery" do
    sub_agent = sub_agents(:one)

    visit document_sub_agent_path(@document, sub_agent)

    # Simulate network error
    page.execute_script <<~JS
      window.fetch = () => Promise.reject(new Error('Network error'))
    JS

    fill_in "message_input", with: "Test message"
    click_button "Send"

    # Should show error message
    assert_text "Error sending message"

    # Message should remain in input for retry
    assert_field "message_input", with: "Test message"

    # Restore fetch and retry
    page.execute_script "window.fetch = window.originalFetch"
    click_button "Send"

    assert_selector ".message.user-message", text: "Test message"
  end

  test "export and import conversation" do
    sub_agent = sub_agents(:one)

    # Create some messages
    sub_agent.messages.create!(role: "user", content: "Question 1", user: @user)
    sub_agent.messages.create!(role: "assistant", content: "Answer 1", user: @user)

    visit document_sub_agent_path(@document, sub_agent)

    # Export conversation
    click_button "Export"

    # Verify download started (checking for download is browser-specific)
    # In a real test, we'd verify the file contents

    # Test clear messages
    accept_confirm do
      click_button "Clear"
    end

    assert_no_selector ".message"
    assert_text "No messages yet"
  end

  test "drag and drop reordering in sidebar" do
    # Create multiple agents
    3.times do |i|
      SubAgent.create!(
        name: "Agent #{i + 1}",
        agent_type: "custom",
        user: @user,
        document: @document
      )
    end

    visit document_path(@document)
    click_button "Sub-Agents"

    # Get agent elements
    agent1 = find(".sub-agent-item", text: "Agent 1")
    agent3 = find(".sub-agent-item", text: "Agent 3")

    # Drag agent 1 after agent 3
    agent1.drag_to(agent3)

    # Verify new order
    agent_items = all(".sub-agent-item")
    assert_equal "Agent 2", agent_items[0].text
    assert_equal "Agent 3", agent_items[1].text
    assert_equal "Agent 1", agent_items[2].text
  end

  test "responsive design on mobile" do
    # Test mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)

    visit document_path(@document)

    # Sidebar should be hidden by default on mobile
    assert_no_selector ".sub-agent-sidebar", visible: true

    # Open mobile menu
    click_button "Menu"
    click_link "Sub-Agents"

    assert_selector ".sub-agent-sidebar"

    # Create agent on mobile
    click_button "New Agent"
    fill_in "Name", with: "Mobile Agent"
    select "Custom", from: "Agent type"
    click_button "Create Sub agent"

    # Conversation should be full-width on mobile
    assert_selector ".sub-agent-conversation"

    # Test touch interactions
    touch_element = find("#message_input")
    touch_element.click
    assert touch_element.matches_style?(outline: /solid/)
  end

  test "accessibility features" do
    sub_agent = sub_agents(:one)
    visit document_sub_agent_path(@document, sub_agent)

    # Check ARIA labels
    assert_selector "[aria-label='Send message']"
    assert_selector "[aria-label='Message input']"
    assert_selector "[role='log']" # Messages container

    # Test keyboard navigation
    find("body").send_keys(:tab)
    assert_matches_selector ":focus", "#message_input"

    find("body").send_keys(:tab)
    assert_matches_selector ":focus", "button[type='submit']"

    # Test screen reader announcements
    fill_in "message_input", with: "Test"
    click_button "Send"

    # Should have live region for new messages
    assert_selector "[aria-live='polite']"
  end

  test "performance with many messages" do
    sub_agent = sub_agents(:one)

    # Create many messages
    100.times do |i|
      sub_agent.messages.create!(
        role: i.even? ? "user" : "assistant",
        content: "Message #{i + 1}",
        user: @user
      )
    end

    visit document_sub_agent_path(@document, sub_agent)

    # Should implement virtual scrolling or pagination
    assert_selector ".message", maximum: 50 # Only recent messages visible
    assert_selector "[data-action='click->sub-agent-conversation#loadMore']"

    # Test lazy loading
    scroll_to find("[data-action='click->sub-agent-conversation#loadMore']")
    click_button "Load more messages"

    assert_selector ".message", minimum: 51
  end

  test "concurrent editing protection" do
    sub_agent = sub_agents(:one)

    # Open in two windows (simulated)
    visit document_sub_agent_path(@document, sub_agent)

    # Simulate another user editing
    sub_agent.update!(status: "completed")

    # Try to send message
    fill_in "message_input", with: "Test"
    click_button "Send"

    # Should show status update
    assert_selector ".status-badge", text: "Completed"
    assert_field "message_input", disabled: true
    assert_text "This agent has been completed"
  end

  private

  def touch_element(element)
    page.driver.browser.action.move_to(element.native).click.perform
  end
end
