require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @record = Object.new
    @policy = ApplicationPolicy.new(@user, @record)
  end

  # Test initialization
  test "initializes with user and record" do
    assert_equal @user, @policy.user
    assert_equal @record, @policy.record
  end

  # Test default permissions (all should be false)
  test "index? returns false by default" do
    assert_not @policy.index?
  end

  test "show? returns false by default" do
    assert_not @policy.show?
  end

  test "create? returns false by default" do
    assert_not @policy.create?
  end

  test "new? delegates to create?" do
    assert_equal @policy.create?, @policy.new?
  end

  test "update? returns false by default" do
    assert_not @policy.update?
  end

  test "edit? delegates to update?" do
    assert_equal @policy.update?, @policy.edit?
  end

  test "destroy? returns false by default" do
    assert_not @policy.destroy?
  end

  # Test Scope class
  test "Scope initializes with user and scope" do
    scope = ActiveRecord::Relation
    policy_scope = ApplicationPolicy::Scope.new(@user, scope)

    # Use send to access private methods
    assert_equal @user, policy_scope.send(:user)
    assert_equal scope, policy_scope.send(:scope)
  end

  test "Scope#resolve raises NoMethodError" do
    scope = ActiveRecord::Relation
    policy_scope = ApplicationPolicy::Scope.new(@user, scope)

    error = assert_raises(NoMethodError) do
      policy_scope.resolve
    end

    assert_match /You must define #resolve in/, error.message
  end

  # Test with nil user
  test "handles nil user" do
    policy = ApplicationPolicy.new(nil, @record)
    assert_nil policy.user
    assert_equal @record, policy.record
    assert_not policy.index?
  end

  # Test with nil record
  test "handles nil record" do
    policy = ApplicationPolicy.new(@user, nil)
    assert_equal @user, policy.user
    assert_nil policy.record
    assert_not policy.show?
  end

  # Test attr_reader accessibility
  test "user and record are read-only" do
    assert_not_respond_to @policy, :user=
    assert_not_respond_to @policy, :record=
  end
end
