require "test_helper"

class SubAgentTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @document = documents(:one)
    @sub_agent = SubAgent.new(
      name: "Test Agent",
      agent_type: "ruby-rails-expert",
      status: "active",
      system_prompt: "You are a Ruby on Rails expert.",
      user: @user,
      document: @document
    )
  end

  test "should be valid with valid attributes" do
    assert @sub_agent.valid?
  end

  test "should require a name" do
    @sub_agent.name = ""
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:name], "can't be blank"
  end

  test "should require an agent_type" do
    @sub_agent.agent_type = ""
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:agent_type], "can't be blank"
  end

  test "should require a valid agent_type" do
    @sub_agent.agent_type = "invalid-type"
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:agent_type], "is not included in the list"
  end

  test "should accept all valid agent types" do
    valid_types = [
      "ruby-rails-expert", "javascript-package-expert", "tailwind-css-expert",
      "test-runner-fixer", "error-debugger", "project-orchestrator",
      "git-auto-commit", "custom"
    ]

    valid_types.each do |agent_type|
      @sub_agent.agent_type = agent_type
      assert @sub_agent.valid?, "#{agent_type} should be valid"
    end
  end

  test "should require a status" do
    @sub_agent.status = ""
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:status], "can't be blank"
  end

  test "should require a valid status" do
    @sub_agent.status = "invalid-status"
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:status], "is not included in the list"
  end

  test "should accept all valid statuses" do
    valid_statuses = [ "active", "idle", "completed" ]

    valid_statuses.each do |status|
      @sub_agent.status = status
      assert @sub_agent.valid?, "#{status} should be valid"
    end
  end

  test "should require a user" do
    @sub_agent.user = nil
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:user], "must exist"
  end

  test "should require a document" do
    @sub_agent.document = nil
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:document], "must exist"
  end

  test "should limit name length to 100 characters" do
    @sub_agent.name = "a" * 101
    assert_not @sub_agent.valid?
    assert_includes @sub_agent.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "should set default status to active" do
    sub_agent = SubAgent.new(
      name: "Test Agent",
      agent_type: "custom",
      user: @user,
      document: @document
    )
    assert_equal "active", sub_agent.status
  end

  test "should initialize empty context" do
    assert_equal({}, @sub_agent.context)
  end

  test "should handle context as JSON" do
    context_data = { "key" => "value", "nested" => { "data" => true } }
    @sub_agent.context = context_data
    @sub_agent.save!
    @sub_agent.reload
    assert_equal context_data, @sub_agent.context
  end

  test "should have messages association" do
    assert @sub_agent.respond_to?(:messages)
    @sub_agent.save!
    assert_equal [], @sub_agent.messages.to_a
  end

  test "should destroy dependent messages" do
    @sub_agent.save!
    message = @sub_agent.messages.create!(
      role: "user",
      content: "Test message",
      user: @user
    )

    assert_difference("SubAgentMessage.count", -1) do
      @sub_agent.destroy
    end
  end

  # Scope tests
  test "active scope should return only active sub agents" do
    @sub_agent.save!
    idle_agent = SubAgent.create!(
      name: "Idle Agent",
      agent_type: "custom",
      status: "idle",
      user: @user,
      document: @document
    )
    completed_agent = SubAgent.create!(
      name: "Completed Agent",
      agent_type: "custom",
      status: "completed",
      user: @user,
      document: @document
    )

    active_agents = SubAgent.active
    assert_includes active_agents, @sub_agent
    assert_not_includes active_agents, idle_agent
    assert_not_includes active_agents, completed_agent
  end

  test "idle scope should return only idle sub agents" do
    @sub_agent.save!
    idle_agent = SubAgent.create!(
      name: "Idle Agent",
      agent_type: "custom",
      status: "idle",
      user: @user,
      document: @document
    )

    idle_agents = SubAgent.idle
    assert_includes idle_agents, idle_agent
    assert_not_includes idle_agents, @sub_agent
  end

  test "completed scope should return only completed sub agents" do
    @sub_agent.save!
    completed_agent = SubAgent.create!(
      name: "Completed Agent",
      agent_type: "custom",
      status: "completed",
      user: @user,
      document: @document
    )

    completed_agents = SubAgent.completed
    assert_includes completed_agents, completed_agent
    assert_not_includes completed_agents, @sub_agent
  end

  test "recent scope should order by created_at desc" do
    SubAgent.destroy_all

    old_agent = SubAgent.create!(
      name: "Old Agent",
      agent_type: "custom",
      user: @user,
      document: @document,
      created_at: 2.days.ago
    )
    new_agent = SubAgent.create!(
      name: "New Agent",
      agent_type: "custom",
      user: @user,
      document: @document,
      created_at: 1.day.ago
    )

    agents = SubAgent.recent
    assert_equal new_agent.id, agents.first.id
    assert_equal old_agent.id, agents.second.id
  end

  test "by_user scope should filter by user" do
    @sub_agent.save!
    other_user = users(:two)
    other_agent = SubAgent.create!(
      name: "Other Agent",
      agent_type: "custom",
      user: other_user,
      document: documents(:two)
    )

    user_agents = SubAgent.by_user(@user)
    assert_includes user_agents, @sub_agent
    assert_not_includes user_agents, other_agent
  end

  test "by_document scope should filter by document" do
    @sub_agent.save!
    other_document = documents(:two)
    other_agent = SubAgent.create!(
      name: "Other Agent",
      agent_type: "custom",
      user: @user,
      document: other_document
    )

    document_agents = SubAgent.by_document(@document)
    assert_includes document_agents, @sub_agent
    assert_not_includes document_agents, other_agent
  end

  test "by_agent_type scope should filter by agent type" do
    @sub_agent.save!
    other_agent = SubAgent.create!(
      name: "Other Agent",
      agent_type: "javascript-package-expert",
      user: @user,
      document: @document
    )

    rails_agents = SubAgent.by_agent_type("ruby-rails-expert")
    assert_includes rails_agents, @sub_agent
    assert_not_includes rails_agents, other_agent
  end

  # Instance method tests
  test "should identify active status" do
    @sub_agent.status = "active"
    assert @sub_agent.active?
    assert_not @sub_agent.idle?
    assert_not @sub_agent.completed?
  end

  test "should identify idle status" do
    @sub_agent.status = "idle"
    assert @sub_agent.idle?
    assert_not @sub_agent.active?
    assert_not @sub_agent.completed?
  end

  test "should identify completed status" do
    @sub_agent.status = "completed"
    assert @sub_agent.completed?
    assert_not @sub_agent.active?
    assert_not @sub_agent.idle?
  end

  test "should count messages" do
    @sub_agent.save!
    assert_equal 0, @sub_agent.message_count

    @sub_agent.messages.create!(role: "user", content: "Test 1", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Test 2", user: @user)

    assert_equal 2, @sub_agent.message_count
  end

  test "should get last message" do
    @sub_agent.save!
    assert_nil @sub_agent.last_message

    first_message = @sub_agent.messages.create!(role: "user", content: "First", user: @user)
    last_message = @sub_agent.messages.create!(role: "assistant", content: "Last", user: @user)

    assert_equal last_message, @sub_agent.last_message
  end

  test "should have conversation with user and assistant messages" do
    @sub_agent.save!
    assert @sub_agent.has_conversation?

    # Add only user messages
    @sub_agent.messages.create!(role: "user", content: "Test 1", user: @user)
    @sub_agent.messages.create!(role: "user", content: "Test 2", user: @user)
    assert_not @sub_agent.has_conversation?

    # Add assistant message
    @sub_agent.messages.create!(role: "assistant", content: "Response", user: @user)
    assert @sub_agent.has_conversation?
  end

  test "should update context" do
    @sub_agent.save!
    new_context = { "key" => "value", "number" => 42 }

    @sub_agent.update_context(new_context)
    @sub_agent.reload
    assert_equal new_context, @sub_agent.context
  end

  test "should merge context" do
    @sub_agent.context = { "existing" => "value" }
    @sub_agent.save!

    @sub_agent.merge_context({ "new" => "data", "existing" => "updated" })
    @sub_agent.reload

    assert_equal({ "existing" => "updated", "new" => "data" }, @sub_agent.context)
  end

  test "should clear context" do
    @sub_agent.context = { "key" => "value" }
    @sub_agent.save!

    @sub_agent.clear_context
    @sub_agent.reload
    assert_equal({}, @sub_agent.context)
  end

  test "should activate sub agent" do
    @sub_agent.status = "idle"
    @sub_agent.save!

    @sub_agent.activate!
    assert_equal "active", @sub_agent.status
  end

  test "should deactivate sub agent" do
    @sub_agent.status = "active"
    @sub_agent.save!

    @sub_agent.deactivate!
    assert_equal "idle", @sub_agent.status
  end

  test "should complete sub agent" do
    @sub_agent.status = "active"
    @sub_agent.save!

    @sub_agent.complete!
    assert_equal "completed", @sub_agent.status
  end

  test "should provide summary" do
    @sub_agent.save!
    @sub_agent.messages.create!(role: "user", content: "Hello", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Hi there", user: @user)

    summary = @sub_agent.summary

    assert_equal @sub_agent.id, summary[:id]
    assert_equal @sub_agent.name, summary[:name]
    assert_equal @sub_agent.agent_type, summary[:agent_type]
    assert_equal @sub_agent.status, summary[:status]
    assert_equal 2, summary[:message_count]
    assert_equal "Hi there", summary[:last_message]
    assert summary[:created_at].present?
    assert summary[:updated_at].present?
  end

  test "should export conversation" do
    @sub_agent.save!
    @sub_agent.messages.create!(role: "user", content: "Question", user: @user)
    @sub_agent.messages.create!(role: "assistant", content: "Answer", user: @user)

    export = @sub_agent.export_conversation

    assert_equal @sub_agent.name, export[:agent_name]
    assert_equal @sub_agent.agent_type, export[:agent_type]
    assert_equal @sub_agent.status, export[:status]
    assert_equal @sub_agent.context, export[:context]
    assert_equal 2, export[:messages].length
    assert export[:exported_at].present?
  end

  # Edge cases and additional tests
  test "should handle nil system_prompt" do
    @sub_agent.system_prompt = nil
    assert @sub_agent.valid?
  end

  test "should handle empty context updates" do
    @sub_agent.save!
    @sub_agent.update_context({})
    assert_equal({}, @sub_agent.context)
  end

  test "should handle nil context in merge" do
    @sub_agent.context = nil
    @sub_agent.save!
    @sub_agent.merge_context({ "key" => "value" })
    assert_equal({ "key" => "value" }, @sub_agent.context)
  end

  test "should handle complex nested context" do
    complex_context = {
      "level1" => {
        "level2" => {
          "level3" => [ "array", "of", "values" ],
          "boolean" => true,
          "number" => 123.45
        }
      }
    }
    @sub_agent.context = complex_context
    @sub_agent.save!
    @sub_agent.reload
    assert_equal complex_context, @sub_agent.context
  end

  test "should handle summary with no messages" do
    @sub_agent.save!
    summary = @sub_agent.summary

    assert_equal 0, summary[:message_count]
    assert_nil summary[:last_message]
  end

  test "should handle export with empty conversation" do
    @sub_agent.save!
    export = @sub_agent.export_conversation

    assert_equal [], export[:messages]
  end

  test "should ensure context is a hash before save" do
    @sub_agent.context = nil
    @sub_agent.save!
    @sub_agent.reload
    assert_equal({}, @sub_agent.context)
  end
end
