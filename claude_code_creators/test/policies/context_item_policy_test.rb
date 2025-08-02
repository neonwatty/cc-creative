require "test_helper"

class ContextItemPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:one)
    @context_item = context_items(:one)
    @other_document = documents(:two)
  end

  test "user can view their own context items" do
    policy = ContextItemPolicy.new(@user, @document)
    assert policy.index?
  end

  test "user cannot view other user's context items" do
    policy = ContextItemPolicy.new(@other_user, @document)
    assert_not policy.index?
  end

  test "user can show their own context item" do
    policy = ContextItemPolicy.new(@user, @context_item)
    assert policy.show?
  end

  test "user cannot show other user's context item" do
    # Create a context item for other user's document
    other_context_item = context_items(:two)
    policy = ContextItemPolicy.new(@user, other_context_item)
    assert_not policy.show?
  end

  test "user can create context item for their own document" do
    new_context_item = @document.context_items.build(user: @user)
    policy = ContextItemPolicy.new(@user, new_context_item)
    assert policy.create?
  end

  test "user cannot create context item for other user's document" do
    new_context_item = @other_document.context_items.build(user: @user)
    policy = ContextItemPolicy.new(@user, new_context_item)
    assert_not policy.create?
  end

  test "user can update their own context item" do
    policy = ContextItemPolicy.new(@user, @context_item)
    assert policy.update?
  end

  test "user cannot update other user's context item" do
    other_context_item = context_items(:two)
    policy = ContextItemPolicy.new(@user, other_context_item)
    assert_not policy.update?
  end

  test "user can destroy their own context item" do
    policy = ContextItemPolicy.new(@user, @context_item)
    assert policy.destroy?
  end

  test "user cannot destroy other user's context item" do
    other_context_item = context_items(:two)
    policy = ContextItemPolicy.new(@user, other_context_item)
    assert_not policy.destroy?
  end

  test "scope returns only user's context items" do
    scope = ContextItemPolicy::Scope.new(@user, ContextItem).resolve

    # All returned context items should belong to user's documents
    scope.each do |context_item|
      assert_equal @user.id, context_item.document.user_id
    end

    # Should not include context items from other users' documents
    other_user_context_items = ContextItem.joins(:document).where(documents: { user_id: @other_user.id })
    assert_empty scope & other_user_context_items
  end
end
