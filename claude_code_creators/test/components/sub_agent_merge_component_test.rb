require "test_helper"

class SubAgentMergeComponentTest < ViewComponent::TestCase
  setup do
    @sub_agent = sub_agents(:one)
    @user = users(:one)
    @document = documents(:one)
    
    # Clear existing messages and create some messages for merging
    @sub_agent.messages.destroy_all
    @sub_agent.messages.create!(role: "assistant", content: "First response", user: @user)
    @sub_agent.messages.create!(role: "user", content: "Question", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Second response", user: @user)
  end

  test "renders merge interface" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    # Check main container
    assert_selector ".sub-agent-merge"
    assert_selector "[data-controller='sub-agent-merge']"
    
    # Check header
    assert_selector "h3", text: "Merge Agent Content"
    assert_text "Merge content from #{@sub_agent.name}"
  end

  test "displays preview of content to merge" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".content-preview"
    assert_selector "[data-sub-agent-merge-target='preview']"
    assert_text "First response"
    assert_text "Second response"
    assert_no_text "Question" # User messages should not be included
  end

  test "shows message count" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_text "2 assistant messages to merge"
  end

  test "renders merge options" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    # Check for merge position options
    assert_selector "input[type='radio'][name='merge_position'][value='end']"
    assert_selector "input[type='radio'][name='merge_position'][value='cursor']"
    assert_selector "input[type='radio'][name='merge_position'][value='beginning']"
    
    assert_text "Append to end"
    assert_text "Insert at cursor"
    assert_text "Insert at beginning"
  end

  test "renders formatting options" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "input[type='checkbox'][name='include_timestamps']"
    assert_selector "input[type='checkbox'][name='include_agent_name']"
    assert_selector "input[type='checkbox'][name='add_separator']"
    
    assert_text "Include timestamps"
    assert_text "Include agent name"
    assert_text "Add separator"
  end

  test "renders action buttons" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "button[data-action='click->sub-agent-merge#merge']", text: "Merge Content"
    assert_selector "button[data-action='click->sub-agent-merge#cancel']", text: "Cancel"
  end

  test "shows empty state when no content to merge" do
    @sub_agent.messages.destroy_all
    
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".empty-state"
    assert_text "No content to merge"
    assert_text "This agent has no assistant messages"
    assert_selector "button[disabled]", text: "Merge Content"
  end

  test "includes necessary data attributes" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-merge-sub-agent-id-value='#{@sub_agent.id}']"
    assert_selector "[data-sub-agent-merge-document-id-value='#{@document.id}']"
  end

  test "shows content preview with truncation for long messages" do
    # Create a long message
    long_content = "This is a very long message. " * 50
    @sub_agent.messages.create!(role: "assistant", content: long_content, user: @user)
    
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".content-preview"
    assert_selector ".truncate-preview"
    assert_text "Show more"
  end

  test "displays word count of content to merge" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_text "words"
    assert_selector ".word-count"
  end

  test "shows warning for large merges" do
    # Create many messages
    20.times do
      @sub_agent.messages.create!(role: "assistant", content: "A response " * 100, user: @user)
    end
    
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".warning"
    assert_text "This will add a large amount of content"
  end

  test "includes custom separator input when option selected" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "input[name='custom_separator']"
    assert_selector "[data-sub-agent-merge-target='customSeparator']"
  end

  test "shows format preview based on selected options" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".format-preview"
    assert_selector "[data-sub-agent-merge-target='formatPreview']"
  end

  test "disables merge for completed agents with no new content" do
    @sub_agent.update!(status: "completed")
    
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_text "Agent completed"
  end

  test "shows agent metadata in merge preview" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector ".agent-metadata"
    assert_text @sub_agent.agent_type.humanize
    assert_text "Created"
  end

  test "includes confirmation dialog attributes" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-merge-target='confirmDialog']"
  end

  test "shows success message target" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-merge-target='successMessage']"
  end

  test "includes loading state target" do
    rendered = render_inline(SubAgentMergeComponent.new(
      sub_agent: @sub_agent,
      current_user: @user
    ))
    
    assert_selector "[data-sub-agent-merge-target='loadingState']"
  end
end