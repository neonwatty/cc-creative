require "test_helper"

class SubAgentServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @document = documents(:one)
    @sub_agent = sub_agents(:one)
    @service = SubAgentService.new(@sub_agent)
  end

  test "should initialize with sub_agent" do
    assert_equal @sub_agent, @service.instance_variable_get(:@sub_agent)
  end

  test "should create sub_agent" do
    params = {
      name: "New Agent",
      agent_type: "ruby-rails-expert",
      system_prompt: "You are a Ruby expert"
    }
    
    service = SubAgentService.create(@user, @document, params)
    
    assert service.is_a?(SubAgentService)
    sub_agent = service.instance_variable_get(:@sub_agent)
    assert_equal "New Agent", sub_agent.name
    assert_equal "ruby-rails-expert", sub_agent.agent_type
    assert_equal "You are a Ruby expert", sub_agent.system_prompt
    assert_equal @user, sub_agent.user
    assert_equal @document, sub_agent.document
  end

  test "should not create sub_agent with invalid params" do
    params = {
      name: "",
      agent_type: "invalid"
    }
    
    service = SubAgentService.create(@user, @document, params)
    sub_agent = service.instance_variable_get(:@sub_agent)
    
    assert_not sub_agent.valid?
    assert sub_agent.errors.present?
  end

  test "should send user message" do
    message_content = "Hello, agent!"
    
    message = @service.send_message(@user, message_content)
    
    assert message.persisted?
    assert_equal "user", message.role
    assert_equal message_content, message.content
    assert_equal @user, message.user
    assert_equal @sub_agent, message.sub_agent
    
    # Check that assistant response was created
    assistant_message = @sub_agent.messages.last
    assert_equal "assistant", assistant_message.role
    assert assistant_message.content.present?
  end

  test "should not send empty message" do
    message = @service.send_message(@user, "")
    assert_nil message
  end

  test "should not send nil message" do
    message = @service.send_message(@user, nil)
    assert_nil message
  end

  test "should merge content from sub_agent" do
    # Create messages to merge
    @sub_agent.messages.create!(role: "assistant", content: "First response", user: @user)
    @sub_agent.messages.create!(role: "user", content: "Question", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Second response", user: @user)
    
    merged_content = @service.merge_content
    
    assert merged_content.present?
    assert merged_content.include?("First response")
    assert merged_content.include?("Second response")
    assert_not merged_content.include?("Question") # Should only include assistant messages
  end

  test "should return nil when no content to merge" do
    @sub_agent.messages.destroy_all
    
    merged_content = @service.merge_content
    
    assert_nil merged_content
  end

  test "should merge content to document" do
    # Create content to merge
    @sub_agent.messages.create!(role: "assistant", content: "Content to merge", user: @user)
    
    original_content = @document.content.to_s
    result = @service.merge_to_document
    
    assert result
    @document.reload
    assert @document.content.to_s.include?("Content to merge")
    assert @document.content.to_s.include?(original_content) if original_content.present?
  end

  test "should not merge to document when no content" do
    @sub_agent.messages.destroy_all
    
    result = @service.merge_to_document
    
    assert_not result
  end

  test "should update context" do
    new_context = { "key" => "value", "number" => 42 }
    
    @service.update_context(new_context)
    
    @sub_agent.reload
    assert_equal new_context, @sub_agent.context
  end

  test "should merge context" do
    @sub_agent.update!(context: { "existing" => "value" })
    
    @service.merge_context({ "new" => "data", "existing" => "updated" })
    
    @sub_agent.reload
    assert_equal({ "existing" => "updated", "new" => "data" }, @sub_agent.context)
  end

  test "should clear context" do
    @sub_agent.update!(context: { "data" => "value" })
    
    @service.clear_context
    
    @sub_agent.reload
    assert_equal({}, @sub_agent.context)
  end

  test "should activate sub_agent" do
    @sub_agent.update!(status: "idle")
    
    @service.activate!
    
    assert_equal "active", @sub_agent.reload.status
  end

  test "should deactivate sub_agent" do
    @sub_agent.update!(status: "active")
    
    @service.deactivate!
    
    assert_equal "idle", @sub_agent.reload.status
  end

  test "should complete sub_agent" do
    @sub_agent.update!(status: "active")
    
    @service.complete!
    
    assert_equal "completed", @sub_agent.reload.status
  end

  test "should export conversation" do
    # Create messages
    @sub_agent.messages.create!(role: "user", content: "Question", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Answer", user: @user)
    
    export = @service.export_conversation
    
    assert_equal @sub_agent.name, export[:agent_name]
    assert_equal @sub_agent.agent_type, export[:agent_type]
    assert_equal @sub_agent.status, export[:status]
    assert_equal @sub_agent.context, export[:context]
    assert export[:messages].present?
    assert export[:exported_at].present?
  end

  test "should get summary" do
    @sub_agent.messages.create!(role: "user", content: "Test", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Response", user: @user)
    
    summary = @service.summary
    
    assert_equal @sub_agent.id, summary[:id]
    assert_equal @sub_agent.name, summary[:name]
    assert_equal @sub_agent.agent_type, summary[:agent_type]
    assert_equal @sub_agent.status, summary[:status]
    assert summary[:message_count] > 0
    assert summary[:last_message].present?
  end

  test "should initialize agent" do
    @sub_agent.update!(status: "idle")
    
    result = @service.initialize_agent
    
    assert result
    assert_equal "active", @sub_agent.reload.status
  end

  test "should activate with service method" do
    @sub_agent.update!(status: "idle")
    
    result = @service.activate
    
    assert result
    assert_equal "active", @sub_agent.reload.status
  end

  test "should complete with service method" do
    @sub_agent.update!(status: "active")
    
    result = @service.complete
    
    assert result
    assert_equal "completed", @sub_agent.reload.status
  end

  test "should handle errors in activate" do
    # Force an error by making the sub_agent invalid
    @sub_agent.stubs(:activate!).raises(StandardError, "Test error")
    
    result = @service.activate
    
    assert_not result
    assert @service.errors.include?("Failed to activate agent: Test error")
  end

  test "should handle errors in complete" do
    @sub_agent.stubs(:complete!).raises(StandardError, "Test error")
    
    result = @service.complete
    
    assert_not result
    assert @service.errors.include?("Failed to complete agent: Test error")
  end

  test "should handle errors in send_message" do
    @sub_agent.messages.stubs(:create!).raises(StandardError, "Database error")
    
    message = @service.send_message(@user, "Test message")
    
    assert_nil message
    assert @service.errors.include?("Failed to send message: Database error")
  end

  test "should handle errors in merge_to_document" do
    @sub_agent.messages.create!(role: "assistant", content: "Test", user: @user)
    @sub_agent.document.stubs(:update!).raises(StandardError, "Update error")
    
    result = @service.merge_to_document
    
    assert_not result
    assert @service.errors.include?("Failed to merge to document: Update error")
  end

  test "should build conversation history" do
    # Create some messages
    @sub_agent.messages.create!(role: "user", content: "First question", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "First answer", user: @user)
    @sub_agent.messages.create!(role: "user", content: "Second question", user: @user)
    
    history = @service.send(:conversation_history)
    
    assert history.is_a?(Array)
    assert history.all? { |h| h.has_key?(:role) && h.has_key?(:content) }
  end
end