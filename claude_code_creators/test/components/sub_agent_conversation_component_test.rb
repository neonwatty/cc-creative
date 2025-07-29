require "test_helper"

class SubAgentConversationComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers
  
  setup do
    @sub_agent = sub_agents(:one)
    @user = users(:one)
    @document = documents(:one)
  end

  test "renders conversation interface" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    # Check main container
    assert_selector "[data-controller='sub-agent-conversation']"
    
    # Check header elements
    assert_text @sub_agent.name
    assert_text @sub_agent.status.capitalize
  end

  test "renders messages list" do
    # Create some Claude messages for the sub agent
    session = claude_sessions(:one)
    session.claude_messages.create!(role: "user", content: "Hello", sub_agent_name: @sub_agent.name)
    session.claude_messages.create!(role: "assistant", content: "Hi there!", sub_agent_name: @sub_agent.name)
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-conversation-target='messageList']"
    assert_text "Hello"
    assert_text "Hi there!"
  end

  test "renders empty state when no messages" do
    # Ensure no claude messages exist
    @sub_agent.claude_messages.destroy_all
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_text "Start a conversation by typing a message below"
  end

  test "renders input form" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "form.flex.items-end.space-x-3"
    assert_selector "textarea[placeholder='Type your message...']"
    assert_selector "button[type='submit']", text: "Send"
  end

  test "renders action buttons" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "button", text: "Merge to Document"
    assert_selector "button", text: "Export"
    assert_selector "button", text: "Clear"
  end

  test "displays user messages with correct styling" do
    session = claude_sessions(:one)
    session.claude_messages.create!(
      role: "user", 
      content: "User message", 
      sub_agent_name: @sub_agent.name
    )
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".bg-blue-600.text-white"
    assert_text "User message"
  end

  test "displays assistant messages with correct styling" do
    session = claude_sessions(:one)
    session.claude_messages.create!(
      role: "assistant", 
      content: "Assistant response", 
      sub_agent_name: @sub_agent.name
    )
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".bg-gray-100.text-gray-900"
    assert_text "Assistant response"
  end

  test "shows loading indicator when sub agent is active" do
    @sub_agent.update!(status: 'active')
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    # Loading indicator is only shown when agent is active and processing
    assert_text "Agent is currently processing"
  end

  test "includes keyboard shortcut data attribute" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "textarea[data-action*='keydown.enter']"
  end

  test "renders status badges correctly" do
    statuses = ["active", "idle", "completed"]
    
    statuses.each do |status|
      @sub_agent.update!(status: status)
      rendered = render_inline(SubAgentConversationComponent.new(
        sub_agent: @sub_agent,
        current_user: @user
      ))
      
      assert_selector "span.inline-flex.items-center", text: status.capitalize
    end
  end

  test "includes necessary data attributes" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-conversation-sub-agent-id-value='#{@sub_agent.id}']"
    assert_selector "[data-sub-agent-conversation-document-id-value='#{@sub_agent.document_id}']"
  end

  test "renders context display if context exists" do
    @sub_agent.update!(context: { "key" => "value", "setting" => "enabled" })
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".context-display"
    assert_text "Context"
    assert_text "key: value"
    assert_text "setting: enabled"
  end

  test "does not render context display if context is empty" do
    @sub_agent.update!(context: {})
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_no_selector ".context-display"
  end

  test "displays message timestamps" do
    message = @sub_agent.messages.create!(
      role: "user", 
      content: "Test message", 
      user: @user,
      created_at: 1.hour.ago
    )
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".message-timestamp"
  end

  test "disables input when sub agent is completed" do
    @sub_agent.update!(status: "completed")
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "textarea[disabled]"
    assert_selector "button[type='submit'][disabled]"
    assert_text "This conversation has been completed"
  end

  test "includes message templates for dynamic updates" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "template[data-sub-agent-conversation-target='messageTemplate']"
    assert_selector "template[data-sub-agent-conversation-target='assistantMessageTemplate']"
  end

  test "includes main controller data attributes" do
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-controller='sub-agent-conversation']"
    assert_selector "[data-sub-agent-conversation-sub-agent-id-value='#{@sub_agent.id}']"
  end

  test "renders markdown content in messages" do
    session = claude_sessions(:one)
    session.claude_messages.create!(
      role: "assistant", 
      content: "Here is **bold** and *italic* text with `code`", 
      sub_agent_name: @sub_agent.name
    )
    
    rendered = render_inline(SubAgentConversationComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    # The component should have a markdown renderer
    assert_selector ".message-content"
  end
end