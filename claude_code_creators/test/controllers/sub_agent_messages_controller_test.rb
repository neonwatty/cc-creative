require "test_helper"

class SubAgentMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @document = documents(:one)
    @document.update!(user: @user, content: "This is test document content.")  # Ensure document belongs to user and has content

    # Create sub_agent directly instead of using fixtures to avoid validation issues
    @sub_agent = SubAgent.create!(
      user: @user,
      document: @document,
      name: "Test Agent",
      agent_type: "ruby-rails-expert",
      status: "active",
      system_prompt: "You are a test agent."
    )

    sign_in_as(@user)
  end

  test "should create message with valid content via JSON" do
    assert_difference("@sub_agent.messages.count", 2) do  # user message + assistant response
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: { message: "Hello, sub agent!" },
           headers: { "Content-Type": "application/json" },
           as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "user", json_response["message"]["role"]
    assert_equal "Hello, sub agent!", json_response["message"]["content"]
    assert_equal @user.id, json_response["message"]["user"]["id"]
  end

  test "should create message with valid content via turbo stream" do
    assert_difference("@sub_agent.messages.count", 2) do  # user message + assistant response
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: { message: "Hello via turbo!" },
           headers: { "Accept": "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.content_type
  end

  test "should not create message with blank content via JSON" do
    assert_no_difference("@sub_agent.messages.count") do
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: { message: "   " },
           headers: { "Content-Type": "application/json" },
           as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Message cannot be blank", json_response["error"]
  end

  test "should not create message with blank content via turbo stream" do
    assert_no_difference("@sub_agent.messages.count") do
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: { message: "" },
           headers: { "Accept": "text/vnd.turbo-stream.html" }
    end

    assert_response :unprocessable_entity
  end

  test "should not create message without message parameter via JSON" do
    assert_no_difference("@sub_agent.messages.count") do
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: {},
           headers: { "Content-Type": "application/json" },
           as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Message cannot be blank", json_response["error"]
  end

  test "should require authentication" do
    sign_out

    post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
         params: { message: "Hello!" },
         as: :json

    assert_response :unauthorized
  end

  test "should require document authorization" do
    # Create another user's document
    other_user = users(:two)
    other_document = documents(:two)
    other_document.update!(user: other_user, content: "Other user's document content.")
    other_sub_agent = SubAgent.create!(
      user: other_user,
      document: other_document,
      name: "Other User Agent",
      agent_type: "javascript-package-expert",
      status: "active",
      system_prompt: "You are another test agent."
    )

    # Attempt to access another user's document should be unauthorized
    post document_sub_agent_sub_agent_messages_url(other_document, other_sub_agent),
         params: { message: "Unauthorized access!" },
         as: :json

    # Expect either a 403 Forbidden or redirect, depending on error handling
    assert_includes [ 302, 401, 403 ], response.status
  end

  test "should require sub_agent authorization" do
    # Create a sub_agent for a document the user doesn't own
    other_user = users(:two)
    other_document = documents(:two)
    other_document.update!(user: other_user, content: "Unauthorized user's document content.")
    other_sub_agent = SubAgent.create!(
      user: other_user,
      document: other_document,
      name: "Unauthorized Agent",
      agent_type: "test-runner-fixer",
      status: "active",
      system_prompt: "You are an unauthorized test agent."
    )

    # Attempt to access another user's sub_agent should be unauthorized
    post document_sub_agent_sub_agent_messages_url(other_document, other_sub_agent),
         params: { message: "Unauthorized sub agent access!" },
         as: :json

    # Expect either a 403 Forbidden or redirect, depending on error handling
    assert_includes [ 302, 401, 403 ], response.status
  end

  test "should handle service failure gracefully via JSON" do
    # Mock the SubAgentService to fail
    SubAgentService.any_instance.stubs(:send_message).returns(nil)

    assert_no_difference("@sub_agent.messages.count") do
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: { message: "This will fail" },
           headers: { "Content-Type": "application/json" },
           as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Failed to send message", json_response["error"]
  end

  test "should handle service failure gracefully via turbo stream" do
    # Mock the SubAgentService to fail
    SubAgentService.any_instance.stubs(:send_message).returns(nil)

    assert_no_difference("@sub_agent.messages.count") do
      post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
           params: { message: "This will fail" },
           headers: { "Accept": "text/vnd.turbo-stream.html" }
    end

    assert_response :unprocessable_entity
  end

  test "should return correct JSON structure for message" do
    post document_sub_agent_sub_agent_messages_url(@document, @sub_agent),
         params: { message: "Test message structure" },
         headers: { "Content-Type": "application/json" },
         as: :json

    assert_response :success
    json_response = JSON.parse(response.body)

    assert json_response["success"]
    message_data = json_response["message"]

    # Check all expected fields are present
    assert message_data.key?("id")
    assert message_data.key?("role")
    assert message_data.key?("content")
    assert message_data.key?("user")
    assert message_data.key?("created_at")
    assert message_data.key?("formatted_time")

    # Check user nested data
    user_data = message_data["user"]
    assert user_data.key?("id")
    assert user_data.key?("name")

    # Check values
    assert_equal "user", message_data["role"]
    assert_equal "Test message structure", message_data["content"]
    assert_equal @user.id, user_data["id"]
    assert_equal @user.name, user_data["name"]
    assert_match(/\d+:\d+\s[AP]M/, message_data["formatted_time"])
  end
end
