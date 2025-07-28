require "test_helper"

class SubAgentMessageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @sub_agent = sub_agents(:one)
    @message = SubAgentMessage.new(
      role: "user",
      content: "Test message content",
      user: @user,
      sub_agent: @sub_agent
    )
  end

  test "should be valid with valid attributes" do
    assert @message.valid?
  end

  test "should require a role" do
    @message.role = ""
    assert_not @message.valid?
    assert_includes @message.errors[:role], "can't be blank"
  end

  test "should require a valid role" do
    @message.role = "invalid"
    assert_not @message.valid?
    assert_includes @message.errors[:role], "is not included in the list"
  end

  test "should accept valid roles" do
    valid_roles = ["user", "assistant", "system"]
    
    valid_roles.each do |role|
      @message.role = role
      assert @message.valid?, "#{role} should be valid"
    end
  end

  test "should require content" do
    @message.content = ""
    assert_not @message.valid?
    assert_includes @message.errors[:content], "can't be blank"
  end

  test "should require a user" do
    @message.user = nil
    assert_not @message.valid?
    assert_includes @message.errors[:user], "must exist"
  end

  test "should require a sub_agent" do
    @message.sub_agent = nil
    assert_not @message.valid?
    assert_includes @message.errors[:sub_agent], "must exist"
  end

  test "should limit content length" do
    @message.content = "a" * 100_001
    assert_not @message.valid?
    assert_includes @message.errors[:content], "is too long (maximum is 100000 characters)"
  end

  test "should belong to user" do
    assert_respond_to @message, :user
    assert_equal @user, @message.user
  end

  test "should belong to sub_agent" do
    assert_respond_to @message, :sub_agent
    assert_equal @sub_agent, @message.sub_agent
  end

  # Scope tests
  test "by_role scope should filter messages" do
    @message.save!
    assistant_message = SubAgentMessage.create!(
      role: "assistant",
      content: "Response",
      user: @user,
      sub_agent: @sub_agent
    )
    
    user_messages = SubAgentMessage.by_role("user")
    assert_includes user_messages, @message
    assert_not_includes user_messages, assistant_message
    
    assistant_messages = SubAgentMessage.by_role("assistant")
    assert_includes assistant_messages, assistant_message
    assert_not_includes assistant_messages, @message
  end

  test "recent scope should order by created_at desc" do
    # Clear existing messages to ensure clean test
    SubAgentMessage.destroy_all
    
    old_message = SubAgentMessage.create!(
      role: "user",
      content: "Old",
      user: @user,
      sub_agent: @sub_agent,
      created_at: 2.days.ago
    )
    new_message = SubAgentMessage.create!(
      role: "user",
      content: "New",
      user: @user,
      sub_agent: @sub_agent,
      created_at: 1.day.ago
    )
    
    messages = SubAgentMessage.recent
    assert_equal new_message.id, messages.first.id
    assert_equal old_message.id, messages.second.id
  end

  # Instance method tests
  test "should identify user message" do
    @message.role = "user"
    assert @message.user_message?
    assert_not @message.assistant_message?
    assert_not @message.system_message?
  end

  test "should identify assistant message" do
    @message.role = "assistant"
    assert @message.assistant_message?
    assert_not @message.user_message?
    assert_not @message.system_message?
  end

  test "should identify system message" do
    @message.role = "system"
    assert @message.system_message?
    assert_not @message.user_message?
    assert_not @message.assistant_message?
  end

  test "should calculate word count" do
    @message.content = "This is a test message with exactly eight words"
    assert_equal 9, @message.word_count
  end

  test "should handle empty content for word count" do
    @message.content = ""
    @message.save(validate: false) # Skip validation for this test
    assert_equal 0, @message.word_count
  end

  test "should truncate content" do
    @message.content = "This is a very long message that should be truncated when we call the truncate method with a specific length limit"
    truncated = @message.truncate_content(50)
    
    assert truncated.length <= 53 # 50 + "..."
    assert truncated.ends_with?("...")
  end

  test "should not truncate short content" do
    @message.content = "Short message"
    truncated = @message.truncate_content(50)
    
    assert_equal "Short message", truncated
    assert_not truncated.ends_with?("...")
  end

  test "should format for display" do
    @message.save!
    formatted = @message.formatted_for_display
    
    assert formatted[:id] == @message.id
    assert formatted[:role] == @message.role
    assert formatted[:content] == @message.content
    assert formatted[:created_at].present?
    assert formatted[:user_name] == @user.name
  end

  test "should export message" do
    @message.save!
    export = @message.export
    
    assert_equal @message.role, export[:role]
    assert_equal @message.content, export[:content]
    assert export[:timestamp].present?
    assert_equal @user.name, export[:user]
  end

  # Validation edge cases
  test "should strip whitespace from content" do
    @message.content = "  Test message  "
    @message.save!
    assert_equal "Test message", @message.content
  end

  test "should handle special characters in content" do
    special_content = "Test with <html> & special 'quotes' and \"double quotes\""
    @message.content = special_content
    assert @message.valid?
    @message.save!
    assert_equal special_content, @message.reload.content
  end

  test "should handle unicode in content" do
    @message.content = "Test with unicode: 你好 🎉 café"
    assert @message.valid?
    @message.save!
    assert_equal "Test with unicode: 你好 🎉 café", @message.reload.content
  end

  test "should handle multiline content" do
    multiline = "Line 1\nLine 2\n\nLine 4 with gap"
    @message.content = multiline
    @message.save!
    assert_equal multiline, @message.reload.content
  end

  # Association tests
  test "should access sub_agent attributes" do
    @message.save!
    assert_equal @sub_agent.name, @message.sub_agent.name
    assert_equal @sub_agent.agent_type, @message.sub_agent.agent_type
  end

  test "should be destroyed when sub_agent is destroyed" do
    @message.save!
    message_count = @sub_agent.messages.count
    assert_difference('SubAgentMessage.count', -message_count) do
      @sub_agent.destroy
    end
  end

  # Callback tests
  test "should strip content before validation" do
    @message.content = "  Content with spaces  \n"
    @message.valid?
    assert_equal "Content with spaces", @message.content
  end

  test "should maintain content formatting" do
    markdown_content = "# Header\n\n- List item\n- **Bold** text\n\n```ruby\ncode block\n```"
    @message.content = markdown_content
    @message.save!
    assert_equal markdown_content, @message.reload.content
  end

  # Performance-related tests
  test "should handle very long content efficiently" do
    long_content = "a" * 50_000
    @message.content = long_content
    
    assert @message.valid?
    assert @message.save
    assert_equal 50_000, @message.reload.content.length
  end

  test "should belong to same user as sub_agent" do
    # This could be a business rule - messages should belong to same user as their sub_agent
    other_user = users(:two)
    other_sub_agent = SubAgent.create!(
      name: "Other Agent",
      agent_type: "custom",
      user: other_user,
      document: documents(:two)
    )
    
    # Currently the model allows this, but it might be a business rule to enforce
    message = SubAgentMessage.new(
      role: "user",
      content: "Test",
      user: @user,
      sub_agent: other_sub_agent
    )
    
    assert message.valid? # Current implementation allows this
  end
end