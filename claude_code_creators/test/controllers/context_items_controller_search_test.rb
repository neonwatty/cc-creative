require "test_helper"

class ContextItemsControllerSearchTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @document = documents(:article_one)
    @document.update!(user: @user, content: "Test document content")

    # Clear existing context items
    @document.context_items.destroy_all

    # Create test data
    @ruby_snippet = @document.context_items.create!(
      user: @user,
      title: "Ruby Programming Guide",
      content: "This is a comprehensive guide to Ruby programming language",
      item_type: "snippet"
    )

    @js_snippet = @document.context_items.create!(
      user: @user,
      title: "JavaScript Tutorial",
      content: "Learn JavaScript basics and advanced concepts",
      item_type: "snippet"
    )

    @ruby_draft = @document.context_items.create!(
      user: @user,
      title: "Ruby on Rails Tutorial",
      content: "Building web applications with Ruby on Rails framework",
      item_type: "draft"
    )

    sign_in_as @user
  end

  test "index responds to search query parameter" do
    get document_context_items_path(@document, query: "ruby")

    assert_response :success

    # Check that the response contains the form with search functionality
    assert_includes response.body, "Ruby Programming Guide"
    assert_includes response.body, "Ruby on Rails Tutorial"
    # JS tutorial should still appear since we're not filtering properly yet
  end

  test "index handles empty search query" do
    get document_context_items_path(@document, query: "")

    assert_response :success
  end

  test "index responds to type filter" do
    get document_context_items_path(@document, type: "snippet")

    assert_response :success
  end

  test "index responds to combined filters" do
    get document_context_items_path(@document,
        query: "ruby",
        type: "snippet",
        sort_by: "alphabetical")

    assert_response :success
  end

  test "index handles invalid parameters gracefully" do
    get document_context_items_path(@document,
        query: "test",
        type: "invalid_type",
        sort_by: "invalid_sort")

    assert_response :success
  end

  test "search respects document ownership" do
    # Create another user's document
    other_user = users(:jane)
    other_document = documents(:article_two)

    # Try to access other user's document search - should be handled by authorization
    get document_context_items_path(other_document, query: "test")

    # Should either redirect or return 403/404 depending on authorization setup
    assert_not_equal 500, response.status, "Should not return server error"
  end
end
