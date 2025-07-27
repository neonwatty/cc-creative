require "test_helper"

class ContextItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:one)
    @context_item = context_items(:one)
    
    # Sign in as the document owner
    sign_in_as(@user)
  end

  test "should get index" do
    get document_context_items_url(@document)
    assert_response :success
  end

  test "should not get index for other user's document" do
    # Sign in as different user
    sign_out
    sign_in_as(@other_user)
    
    get document_context_items_url(@document)
    assert_redirected_to documents_url
    assert_equal "You are not authorized to access this document.", flash[:alert]
  end

  test "should get new" do
    get new_document_context_item_url(@document)
    assert_response :success
  end

  test "should create context_item" do
    assert_difference("ContextItem.count") do
      post document_context_items_url(@document), params: { 
        context_item: { 
          content: "New context content",
          item_type: "snippet",
          title: "New Context Item",
          metadata: { key: "value" }.to_json
        } 
      }
    end

    assert_redirected_to document_context_item_url(@document, ContextItem.last)
    assert_equal "Context item was successfully created.", flash[:notice]
  end

  test "should create context_item via AJAX" do
    assert_difference("ContextItem.count") do
      post document_context_items_url(@document), params: { 
        context_item: { 
          content: "AJAX content",
          item_type: "draft",
          title: "AJAX Item",
          metadata: nil
        } 
      }, as: :json
    end

    assert_response :created
  end

  test "should show context_item" do
    get document_context_item_url(@document, @context_item)
    assert_response :success
  end

  test "should not show other user's context_item" do
    # Sign in as different user
    sign_out
    sign_in_as(@other_user)
    
    get document_context_item_url(@document, @context_item)
    assert_redirected_to documents_url
  end

  test "should get edit" do
    get edit_document_context_item_url(@document, @context_item)
    assert_response :success
  end

  test "should update context_item" do
    patch document_context_item_url(@document, @context_item), params: { 
      context_item: { 
        content: "Updated content",
        title: "Updated Title"
      } 
    }
    assert_redirected_to document_context_item_url(@document, @context_item)
    assert_equal "Context item was successfully updated.", flash[:notice]
  end

  test "should update context_item via AJAX" do
    patch document_context_item_url(@document, @context_item), params: { 
      context_item: { 
        content: "AJAX updated content"
      } 
    }, as: :json
    
    assert_response :success
  end

  test "should destroy context_item" do
    assert_difference("ContextItem.count", -1) do
      delete document_context_item_url(@document, @context_item)
    end

    assert_redirected_to document_context_items_url(@document)
    assert_equal "Context item was successfully destroyed.", flash[:notice]
  end

  test "should destroy context_item via AJAX" do
    assert_difference("ContextItem.count", -1) do
      delete document_context_item_url(@document, @context_item), as: :json
    end

    assert_response :no_content
  end

  test "should not allow invalid item_type" do
    post document_context_items_url(@document), params: { 
      context_item: { 
        content: "Invalid type content",
        item_type: "invalid",
        title: "Invalid Type"
      } 
    }
    
    assert_response :unprocessable_entity
  end

  test "should handle turbo stream requests" do
    post document_context_items_url(@document), params: { 
      context_item: { 
        content: "Turbo content",
        item_type: "snippet",
        title: "Turbo Item"
      } 
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_match "turbo-stream", response.body
  end
end
