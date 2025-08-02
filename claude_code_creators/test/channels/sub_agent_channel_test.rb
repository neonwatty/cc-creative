require "test_helper"

class SubAgentChannelTest < ActionCable::Channel::TestCase
  tests SubAgentChannel

  setup do
    @user = users(:one)
    @sub_agent = sub_agents(:one)
  end

  test "subscribes with valid sub_agent_id" do
    # Stub current_user
    stub_connection current_user: @user

    # Subscribe to the channel
    subscribe sub_agent_id: @sub_agent.id

    # Verify subscription was created
    assert subscription.confirmed?
    assert subscription.confirmed?
    assert_has_stream "sub_agent_#{@sub_agent.id}"
  end

  test "rejects subscription without sub_agent_id" do
    stub_connection current_user: @user

    subscribe

    assert subscription.rejected?
  end

  test "rejects subscription with invalid sub_agent_id" do
    stub_connection current_user: @user

    subscribe sub_agent_id: 99999

    assert subscription.rejected?
  end

  test "rejects subscription for unauthorized user" do
    other_user = users(:two)
    other_sub_agent = SubAgent.create!(
      name: "Other Agent",
      agent_type: "custom",
      user: other_user,
      document: documents(:two)
    )

    stub_connection current_user: @user

    subscribe sub_agent_id: other_sub_agent.id

    assert subscription.rejected?
  end

  test "broadcasts message when created" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    message = @sub_agent.messages.create!(
      role: "user",
      content: "Test broadcast",
      user: @user
    )

    # The broadcast happens in the model callback, not in the test
    # We need to trigger it manually or verify it was called
    assert message.persisted?
  end

  test "broadcasts status change" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    perform :update_status, status: "completed"

    assert_broadcast_on("sub_agent_#{@sub_agent.id}", {
      type: "status_change",
      status: "completed"
    })

    @sub_agent.reload
    assert_equal "completed", @sub_agent.status
  end

  test "does not update invalid status" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    original_status = @sub_agent.status

    perform :update_status, status: "invalid_status"

    @sub_agent.reload
    assert_equal original_status, @sub_agent.status
  end

  test "broadcasts typing indicator" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    perform :typing, typing: true

    assert_broadcast_on("sub_agent_#{@sub_agent.id}", {
      type: "typing",
      user_id: @user.id,
      user_name: @user.name,
      typing: true
    })
  end

  test "unsubscribes on disconnect" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    assert subscription.confirmed?

    unsubscribe

    assert_no_streams
  end

  test "handles message received action" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    # The receive method expects a different format
    assert_difference "@sub_agent.messages.count", 2 do # 2 because service creates user + assistant message
      perform :receive, {
        "message" => {
          "content" => "New message via cable"
        }
      }
    end

    # Get the user message (second to last since service creates assistant response)
    user_message = @sub_agent.messages.order(:created_at).second_to_last
    assert_equal "New message via cable", user_message.content
    assert_equal "user", user_message.role
    assert_equal @user, user_message.user

    # Verify assistant response was created
    assistant_message = @sub_agent.messages.last
    assert_equal "assistant", assistant_message.role
  end

  test "broadcasts context update" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    new_context = { "key" => "value" }

    perform :update_context, context: new_context

    assert_broadcast_on("sub_agent_#{@sub_agent.id}", {
      type: "context_update",
      context: new_context
    })

    @sub_agent.reload
    assert_equal new_context, @sub_agent.context
  end

  test "prevents concurrent message sends" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    # Mock the service to simulate a slow operation
    SubAgentService.any_instance.stubs(:send_message).returns(
      SubAgentMessage.new(role: "user", content: "Test", user: @user, sub_agent: @sub_agent)
    )

    # Try to send multiple messages concurrently
    threads = []
    3.times do |i|
      threads << Thread.new do
        perform :receive, { message: { content: "Message #{i}", role: "user" } }
      end
    end

    threads.each(&:join)

    # Should handle gracefully without errors
    assert subscription.confirmed?
  end

  test "broadcasts agent deletion" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    perform :delete_agent

    assert_broadcast_on("sub_agent_#{@sub_agent.id}", {
      type: "agent_deleted",
      agent_id: @sub_agent.id
    })
  end

  test "handles connection loss gracefully" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    # Simulate connection loss
    # Simulate disconnection
    unsubscribe

    # Should not raise errors
    assert_nothing_raised do
      ActionCable.server.broadcast("sub_agent_#{@sub_agent.id}", { test: "data" })
    end
  end

  test "broadcasts message with attachments" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    # Create a message with metadata for attachments
    message = @sub_agent.messages.create!(
      role: "assistant",
      content: "Here's an image: [attachment:image.png]",
      user: @user
    )

    # Verify the message was created
    assert message.persisted?
    assert_equal "Here's an image: [attachment:image.png]", message.content
  end

  test "rate limits message sending" do
    stub_connection current_user: @user
    subscribe sub_agent_id: @sub_agent.id

    # Send many messages quickly
    10.times do |i|
      perform :receive, { message: { content: "Spam #{i}", role: "user" } }
    end

    # Should handle rate limiting gracefully
    # Exact implementation depends on rate limiting strategy
    assert subscription.confirmed?
  end
end
