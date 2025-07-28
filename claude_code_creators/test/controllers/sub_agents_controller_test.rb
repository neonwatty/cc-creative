require "test_helper"

class SubAgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @document = documents(:one)
    @sub_agent = sub_agents(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get document_sub_agents_url(@document)
    assert_response :success
  end

  test "should get index as JSON" do
    get document_sub_agents_url(@document, format: :json)
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    assert json_response.is_a?(Array)
  end

  test "should get new" do
    get new_document_sub_agent_url(@document)
    assert_response :success
  end

  test "should create sub_agent" do
    assert_difference("SubAgent.count") do
      post document_sub_agents_url(@document), params: {
        sub_agent: {
          name: "New Test Agent",
          agent_type: "ruby-rails-expert"
        }
      }
    end

    assert_redirected_to document_sub_agent_url(@document, SubAgent.last)
    assert_equal "Sub-agent was successfully created and initialized.", flash[:notice]
  end

  test "should create sub_agent via turbo stream" do
    assert_difference("SubAgent.count") do
      post document_sub_agents_url(@document), params: {
        sub_agent: {
          name: "New Test Agent",
          agent_type: "ruby-rails-expert"
        }
      }, as: :turbo_stream
    end

    assert_response :success
    assert_match "turbo-stream", @response.content_type
  end

  test "should not create sub_agent with invalid params" do
    assert_no_difference("SubAgent.count") do
      post document_sub_agents_url(@document), params: {
        sub_agent: {
          name: "",
          agent_type: "invalid-type"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show sub_agent" do
    get document_sub_agent_url(@document, @sub_agent)
    assert_response :success
  end

  test "should show sub_agent as JSON" do
    get document_sub_agent_url(@document, @sub_agent, format: :json)
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    assert_equal @sub_agent.id, json_response["id"]
  end

  test "should get edit" do
    get edit_document_sub_agent_url(@document, @sub_agent)
    assert_response :success
  end

  test "should update sub_agent" do
    patch document_sub_agent_url(@document, @sub_agent), params: {
      sub_agent: {
        name: "Updated Agent Name"
      }
    }
    
    assert_redirected_to document_sub_agent_url(@document, @sub_agent)
    assert_equal "Sub-agent was successfully updated.", flash[:notice]
    
    @sub_agent.reload
    assert_equal "Updated Agent Name", @sub_agent.name
  end

  test "should update sub_agent via turbo stream" do
    patch document_sub_agent_url(@document, @sub_agent), params: {
      sub_agent: {
        name: "Updated Agent Name"
      }
    }, as: :turbo_stream
    
    assert_response :success
    assert_match "turbo-stream", @response.content_type
  end

  test "should not update sub_agent with invalid params" do
    patch document_sub_agent_url(@document, @sub_agent), params: {
      sub_agent: {
        name: "",
        agent_type: "invalid"
      }
    }
    
    assert_response :unprocessable_entity
  end

  test "should destroy sub_agent" do
    assert_difference("SubAgent.count", -1) do
      delete document_sub_agent_url(@document, @sub_agent)
    end

    assert_redirected_to document_sub_agents_url(@document)
    assert_equal "Sub-agent was successfully destroyed.", flash[:notice]
  end

  test "should destroy sub_agent via turbo stream" do
    assert_difference("SubAgent.count", -1) do
      delete document_sub_agent_url(@document, @sub_agent), as: :turbo_stream
    end

    assert_response :success
    assert_match "turbo-stream", @response.content_type
  end

  test "should activate sub_agent" do
    @sub_agent.update!(status: "idle")
    
    post activate_document_sub_agent_url(@document, @sub_agent)

    assert_redirected_to document_sub_agent_url(@document, @sub_agent)
    assert_equal "Sub-agent activated successfully.", flash[:notice]
    assert_equal "active", @sub_agent.reload.status
  end

  test "should complete sub_agent" do
    post complete_document_sub_agent_url(@document, @sub_agent)

    assert_redirected_to document_sub_agent_url(@document, @sub_agent)
    assert_equal "Sub-agent completed successfully.", flash[:notice]
    assert_equal "completed", @sub_agent.reload.status
  end

  test "should pause sub_agent" do
    post pause_document_sub_agent_url(@document, @sub_agent)

    assert_redirected_to document_sub_agent_url(@document, @sub_agent)
    assert_equal "Sub-agent paused.", flash[:notice]
  end

  # Authorization tests
  test "should not allow unauthorized user to access sub_agents" do
    sign_out
    get document_sub_agents_url(@document)
    assert_redirected_to new_session_url
  end

  test "should not allow user to access other user's sub_agents" do
    other_user = users(:two)
    other_document = documents(:two)
    other_sub_agent = SubAgent.create!(
      name: "Other Agent",
      agent_type: "custom",
      user: other_user,
      document: other_document
    )
    
    get document_sub_agent_url(other_document, other_sub_agent)
    assert_redirected_to documents_url
  end

  test "should enforce document ownership" do
    other_document = documents(:two)
    
    get document_sub_agents_url(other_document)
    assert_redirected_to documents_url
  end

  test "should handle sub_agent not found" do
    get document_sub_agent_url(@document, id: "99999999")
    assert_response :not_found
  rescue ActiveRecord::RecordNotFound
    # Expected behavior
    assert true
  end

  test "should handle document not found" do
    assert_raises(ActionController::UrlGenerationError) do
      get document_sub_agents_url(id: "nonexistent")
    end
  end

  # Filtering tests
  test "should get index with status filter" do
    @sub_agent.update!(status: "active")
    SubAgent.create!(
      name: "Idle Agent",
      agent_type: "custom",
      status: "idle",
      user: @user,
      document: @document
    )
    
    get document_sub_agents_url(@document, status: "active")
    assert_response :success
  end

  test "should get index with agent_type filter" do
    @sub_agent.update!(agent_type: "ruby-rails-expert")
    SubAgent.create!(
      name: "JS Agent",
      agent_type: "javascript-package-expert",
      user: @user,
      document: @document
    )
    
    get document_sub_agents_url(@document, agent_type: "ruby-rails-expert")
    assert_response :success
  end
end