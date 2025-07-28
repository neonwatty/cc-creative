require "test_helper"

class SubAgentPolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:one)
    @other_document = documents(:two)
    @sub_agent = sub_agents(:rails_expert)
    @other_sub_agent = sub_agents(:css_expert)
  end
  
  test "user can view their own sub_agents" do
    policy = SubAgentPolicy.new(@user, @sub_agent)
    assert policy.show?
  end
  
  test "user cannot view other user's sub_agents" do
    policy = SubAgentPolicy.new(@user, @other_sub_agent)
    assert_not policy.show?
  end
  
  test "user can create sub_agent for their own document" do
    new_agent = @document.sub_agents.build(user: @user)
    policy = SubAgentPolicy.new(@user, new_agent)
    assert policy.create?
  end
  
  test "user cannot create sub_agent for other user's document" do
    new_agent = @other_document.sub_agents.build(user: @user)
    policy = SubAgentPolicy.new(@user, new_agent)
    assert_not policy.create?
  end
  
  test "user can update their own sub_agent" do
    policy = SubAgentPolicy.new(@user, @sub_agent)
    assert policy.update?
  end
  
  test "user cannot update other user's sub_agent" do
    policy = SubAgentPolicy.new(@user, @other_sub_agent)
    assert_not policy.update?
  end
  
  test "user can destroy their own sub_agent" do
    policy = SubAgentPolicy.new(@user, @sub_agent)
    assert policy.destroy?
  end
  
  test "user cannot destroy other user's sub_agent" do
    policy = SubAgentPolicy.new(@user, @other_sub_agent)
    assert_not policy.destroy?
  end
  
  test "user can activate their own sub_agent" do
    policy = SubAgentPolicy.new(@user, @sub_agent)
    assert policy.activate?
  end
  
  test "user can complete their own sub_agent" do
    policy = SubAgentPolicy.new(@user, @sub_agent)
    assert policy.complete?
  end
  
  test "user can pause their own sub_agent" do
    policy = SubAgentPolicy.new(@user, @sub_agent)
    assert policy.pause?
  end
  
  test "scope returns only user's sub_agents" do
    scope = SubAgentPolicy::Scope.new(@user, SubAgent)
    resolved = scope.resolve
    
    assert_includes resolved, @sub_agent
    assert_includes resolved, sub_agents(:js_expert)
    assert_not_includes resolved, @other_sub_agent
  end
  
  test "document owner can manage sub_agents created by others" do
    # Create a sub_agent on user one's document but owned by another user
    shared_agent = SubAgent.create!(
      document: @document,
      user: @other_user,
      agent_type: 'error-debugger'
    )
    
    policy = SubAgentPolicy.new(@user, shared_agent)
    assert policy.show?
    assert policy.update?
    assert policy.destroy?
  end
end