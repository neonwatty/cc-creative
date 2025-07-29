require "test_helper"

class ContextItemTest < ActiveSupport::TestCase
  test "should have valid factory" do
    context_item = context_items(:snippet_one)
    assert context_item.valid?
  end

  test "should require content" do
    context_item = ContextItem.new(
      document: documents(:one),
      user: users(:alice),
      item_type: "snippet",
      title: "Test"
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:content], "can't be blank"
  end

  test "should require valid item_type" do
    context_item = ContextItem.new(
      document: documents(:one),
      user: users(:alice),
      content: "Test content",
      title: "Test",
      item_type: "invalid"
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:item_type], "is not included in the list"
  end

  test "should set default position on create" do
    context_item = ContextItem.create!(
      document: documents(:one),
      user: users(:alice),
      content: "New content",
      title: "New Item",
      item_type: "snippet"
    )
    assert_equal 4, context_item.position # Should be max + 1
  end

  test "should order by position and created_at" do
    items = documents(:one).context_items.ordered
    assert_equal "Test Snippet", items.first.title
  end

  test "should filter by type" do
    snippets = documents(:one).context_items.by_type("snippet")
    assert_equal 1, snippets.count
    assert_equal "snippet", snippets.first.item_type
  end
end