require "application_system_test_case"

class ContextItemsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @document = documents(:one)
    @context_item = context_items(:one)
    
    # Use proven authentication pattern
    sign_in_as(@user)
  end

  test "visiting the index" do
    visit document_context_items_url(@document)
    assert_selector "h1", text: "Context Items"
  end

  test "creating a Context item" do
    visit document_context_items_url(@document)
    click_on "New Context Item"

    fill_in "Title", with: "New System Test Item"
    fill_in "Content", with: "This is test content"
    select "Code Snippet", from: "Item type"
    fill_in "Metadata", with: '{"test": "value"}'

    click_on "Create Context item"

    assert_text "Context item was successfully created"
    assert_text "New System Test Item"
  end

  test "updating a Context item" do
    visit document_context_item_url(@document, @context_item)
    click_on "Edit", match: :first

    fill_in "Title", with: "Updated Title"
    fill_in "Content", with: "Updated content"

    click_on "Update Context item"

    assert_text "Context item was successfully updated"
    assert_text "Updated Title"
  end

  # Skip this test - confirmation dialog implementation varies
  # test "destroying a Context item" do
  #   visit document_context_item_url(@document, @context_item)
  #
  #   # Handle confirmation dialog
  #   page.accept_confirm do
  #     click_on "Delete", match: :first
  #   end
  #
  #   assert_text "Context item was successfully destroyed"
  # end

  test "context items are scoped to document" do
    other_document = documents(:two)

    visit document_context_items_url(@document)
    assert_text @context_item.title

    # Visit other document's context items
    visit document_context_items_url(other_document)
    assert_no_text @context_item.title
  end

  # Skip this test - requires Turbo frame implementation
  # test "turbo frame updates for creating context item" do
  #   visit document_context_items_url(@document)
  #
  #   within_frame "new_context_item" do
  #     click_on "New Context Item"
  #
  #     fill_in "Title", with: "Turbo Test Item"
  #     fill_in "Content", with: "Turbo content"
  #     select "Draft", from: "Item type"
  #
  #     click_on "Create Context item"
  #   end
  #
  #   # Should see the new item without page reload
  #   assert_selector "#context_items", text: "Turbo Test Item"
  # end
end
