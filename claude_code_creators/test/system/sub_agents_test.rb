require "application_system_test_case"

class SubAgentsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @document = documents(:one)
    sign_in_as(@user)
  end

  test "creating a new sub-agent" do
    visit document_url(@document)
    
    # Click on sub-agents tab or button
    click_on "Sub-Agents"
    
    # Click new agent button
    click_on "New Agent"
    
    # Fill in the form
    fill_in "Name", with: "Test Helper Agent"
    select "Ruby Rails Expert", from: "Agent type"
    fill_in "System prompt", with: "You are a helpful Ruby on Rails expert assistant."
    
    # Submit the form
    click_on "Create Sub-agent"
    
    # Verify creation
    assert_text "Sub-agent created successfully"
    assert_text "Test Helper Agent"
    assert_text "Ruby Rails Expert"
    assert_text "Active"
  end

  test "sending messages to sub-agent" do
    sub_agent = SubAgent.create!(
      name: "Chat Agent",
      agent_type: "ruby-rails-expert",
      user: @user,
      document: @document
    )
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Type a message
    fill_in "message", with: "Hello, can you help me with Rails?"
    
    # Send the message (can use Enter key or button)
    click_on "Send"
    
    # Verify message appears
    assert_text "Hello, can you help me with Rails?"
    
    # Wait for and verify assistant response
    assert_text "assistant", wait: 10
  end

  test "merging sub-agent content to document" do
    sub_agent = SubAgent.create!(
      name: "Content Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    # Create some messages
    sub_agent.messages.create!(role: "assistant", content: "Here is some valuable content to merge.", user: @user)
    sub_agent.messages.create!(role: "assistant", content: "And some more useful information.", user: @user)
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Click merge button
    click_on "Merge to Document"
    
    # Configure merge options
    choose "Append to end"
    check "Include agent name"
    check "Add separator"
    
    # Confirm merge
    click_on "Merge Content"
    
    # Verify success
    assert_text "Content merged successfully"
    
    # Check document contains merged content
    visit document_url(@document)
    assert_text "Here is some valuable content to merge"
    assert_text "And some more useful information"
  end

  test "managing multiple sub-agents" do
    # Create multiple agents
    agent1 = SubAgent.create!(name: "Agent 1", agent_type: "ruby-rails-expert", user: @user, document: @document)
    agent2 = SubAgent.create!(name: "Agent 2", agent_type: "javascript-package-expert", user: @user, document: @document)
    agent3 = SubAgent.create!(name: "Agent 3", agent_type: "tailwind-css-expert", user: @user, document: @document)
    
    visit document_sub_agents_url(@document)
    
    # Verify all agents are listed
    assert_text "Agent 1"
    assert_text "Agent 2"
    assert_text "Agent 3"
    
    # Click on one agent
    click_on "Agent 2"
    
    # Verify we're viewing that agent
    assert_text "Javascript Package Expert"
    assert_selector "[data-sub-agent-id='#{agent2.id}']"
  end

  test "changing sub-agent status" do
    sub_agent = SubAgent.create!(
      name: "Status Test Agent",
      agent_type: "custom",
      status: "active",
      user: @user,
      document: @document
    )
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Verify current status
    assert_text "Active"
    
    # Change to idle
    click_on "Set Idle"
    assert_text "Idle"
    
    # Change to completed
    click_on "Complete"
    assert_text "Completed"
    
    # Verify input is disabled
    assert_selector "textarea[disabled]"
  end

  test "exporting sub-agent conversation" do
    sub_agent = SubAgent.create!(
      name: "Export Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    # Create conversation
    sub_agent.messages.create!(role: "user", content: "What is Rails?", user: @user)
    sub_agent.messages.create!(role: "assistant", content: "Rails is a web framework.", user: @user)
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Click export
    click_on "Export"
    
    # Verify export dialog/download
    assert_text "Export Conversation"
  end

  test "deleting a sub-agent" do
    sub_agent = SubAgent.create!(
      name: "Delete Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    visit document_sub_agents_url(@document)
    
    # Find and click delete for the specific agent
    within "[data-sub-agent-id='#{sub_agent.id}']" do
      click_on "Delete"
    end
    
    # Confirm deletion
    accept_confirm do
      click_on "Delete"
    end
    
    # Verify deletion
    assert_text "Sub-agent deleted successfully"
    assert_no_text "Delete Test Agent"
  end

  test "keyboard shortcuts" do
    sub_agent = SubAgent.create!(
      name: "Shortcut Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Type a message
    message_input = find("textarea[name='message']")
    message_input.fill_in with: "Test message"
    
    # Use Ctrl+Enter to send (simulated)
    message_input.send_keys [:control, :enter]
    
    # Verify message was sent
    assert_text "Test message"
  end

  test "real-time updates via ActionCable" do
    sub_agent = SubAgent.create!(
      name: "Real-time Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    # Open in two windows to test real-time
    visit document_sub_agent_url(@document, sub_agent)
    
    # In a new window
    within_window open_new_window do
      visit document_sub_agent_url(@document, sub_agent)
      
      # Send message in second window
      fill_in "message", with: "Message from window 2"
      click_on "Send"
    end
    
    # Verify message appears in first window
    assert_text "Message from window 2"
  end

  test "drag and drop to reorder agents" do
    agent1 = SubAgent.create!(name: "First Agent", agent_type: "custom", user: @user, document: @document)
    agent2 = SubAgent.create!(name: "Second Agent", agent_type: "custom", user: @user, document: @document)
    agent3 = SubAgent.create!(name: "Third Agent", agent_type: "custom", user: @user, document: @document)
    
    visit document_sub_agents_url(@document)
    
    # Drag third agent to first position
    draggable = find("[data-sub-agent-id='#{agent3.id}'] [data-sub-agent-sidebar-target='dragHandle']")
    droppable = find("[data-sub-agent-id='#{agent1.id}']")
    
    draggable.drag_to(droppable)
    
    # Verify new order
    agents = all(".sub-agent-item")
    assert_equal "Third Agent", agents[0].text
    assert_equal "First Agent", agents[1].text
    assert_equal "Second Agent", agents[2].text
  end

  test "filtering agents by status" do
    SubAgent.create!(name: "Active Agent", agent_type: "custom", status: "active", user: @user, document: @document)
    SubAgent.create!(name: "Idle Agent", agent_type: "custom", status: "idle", user: @user, document: @document)
    SubAgent.create!(name: "Completed Agent", agent_type: "custom", status: "completed", user: @user, document: @document)
    
    visit document_sub_agents_url(@document)
    
    # Filter by active
    select "Active", from: "status_filter"
    assert_text "Active Agent"
    assert_no_text "Idle Agent"
    assert_no_text "Completed Agent"
    
    # Filter by completed
    select "Completed", from: "status_filter"
    assert_no_text "Active Agent"
    assert_no_text "Idle Agent"
    assert_text "Completed Agent"
  end

  test "updating agent context" do
    sub_agent = SubAgent.create!(
      name: "Context Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Open context editor
    click_on "Edit Context"
    
    # Update context
    fill_in "context", with: '{"preference": "formal", "topic": "Rails"}'
    click_on "Save Context"
    
    # Verify context updated
    assert_text "Context updated"
    assert_text "preference: formal"
    assert_text "topic: Rails"
  end

  test "handling errors gracefully" do
    sub_agent = SubAgent.create!(
      name: "Error Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    
    visit document_sub_agent_url(@document, sub_agent)
    
    # Try to send empty message
    click_on "Send"
    
    # Verify error message
    assert_text "Message cannot be empty"
    
    # Try to merge with no content
    sub_agent.messages.destroy_all
    click_on "Merge to Document"
    assert_text "No content to merge"
  end
end