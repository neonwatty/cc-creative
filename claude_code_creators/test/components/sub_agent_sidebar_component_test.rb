require "test_helper"

class SubAgentSidebarComponentTest < ViewComponent::TestCase
  setup do
    @document = documents(:one)
    @user = users(:one)
    @sub_agent = sub_agents(:one)
  end

  test "renders sidebar with sub agents" do
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    # Check main container
    assert_selector ".sub-agent-sidebar"
    
    # Check header
    assert_selector "h3", text: "Sub-Agents"
    assert_selector "[data-action='click->sub-agent-sidebar#createAgent']", text: "New Agent"
    
    # Check sub agent item
    assert_selector ".sub-agent-item"
    assert_text @sub_agent.name
    assert_selector ".badge"
    assert_text @sub_agent.agent_type.humanize
  end

  test "renders empty state when no sub agents" do
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector ".text-gray-500", text: "No sub-agents created yet"
  end

  test "shows active status with green indicator" do
    @sub_agent.update!(status: "active")
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector ".bg-green-500"
    assert_text "Active"
  end

  test "shows idle status with yellow indicator" do
    @sub_agent.update!(status: "idle")
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector ".bg-yellow-500"
    assert_text "Idle"
  end

  test "shows completed status with gray indicator" do
    @sub_agent.update!(status: "completed")
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector ".bg-gray-500"
    assert_text "Completed"
  end

  test "displays message count when messages exist" do
    @sub_agent.messages.create!(role: "user", content: "Test", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Response", user: @user)
    
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_text "2 messages"
  end

  test "displays singular message text for one message" do
    @sub_agent.messages.create!(role: "user", content: "Test", user: @user)
    
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_text "1 message"
  end

  test "renders drag handle for reordering" do
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-sidebar-target='dragHandle']"
  end

  test "renders multiple sub agents" do
    agent1 = @sub_agent
    agent2 = SubAgent.create!(
      name: "Second Agent",
      agent_type: "javascript-package-expert",
      user: @user,
      document: @document
    )
    
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector ".sub-agent-item", count: 2
    assert_text agent1.name
    assert_text agent2.name
  end

  test "includes stimulus controller and targets" do
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector "[data-controller='sub-agent-sidebar']"
    assert_selector "[data-sub-agent-sidebar-document-id-value='#{@document.id}']"
    assert_selector "[data-sub-agent-sidebar-target='agentsList']"
  end

  test "renders sortable container with correct attributes" do
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector ".sortable-container[data-sub-agent-sidebar-target='agentsList']"
  end

  test "includes click action to select agent" do
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    assert_selector "[data-action='click->sub-agent-sidebar#selectAgent']"
    assert_selector "[data-sub-agent-id='#{@sub_agent.id}']"
  end

  test "displays all agent type badges correctly" do
    agent_types = [
      'ruby-rails-expert',
      'javascript-package-expert',
      'tailwind-css-expert',
      'test-runner-fixer',
      'error-debugger',
      'project-orchestrator',
      'git-auto-commit',
      'custom'
    ]
    
    agents = agent_types.map do |type|
      SubAgent.create!(
        name: "#{type} Agent",
        agent_type: type,
        user: @user,
        document: @document
      )
    end
    
    rendered = render_inline(SubAgentSidebarComponent.new(
      document: @document,
      current_user: @user
    ))
    
    agent_types.each do |type|
      assert_text type.humanize
    end
  end
end