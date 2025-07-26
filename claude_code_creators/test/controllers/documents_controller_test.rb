require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:document_one)
    sign_in_as(@user)
  end

  test "should get index" do
    get documents_url
    assert_response :success
    assert_select "h1", text: /Documents/i
  end

  test "should get new" do
    get new_document_url
    assert_response :success
    assert_select "h1", text: /New Document/i
  end

  test "should create document" do
    assert_difference('Document.count') do
      post documents_url, params: { 
        document: { 
          title: "New Document",
          content: "New content",
          description: "New description",
          tag_list: "tag1, tag2"
        } 
      }
    end

    assert_redirected_to document_url(Document.last)
    assert_equal 'Document was successfully created.', flash[:notice]
  end

  test "should show document" do
    get document_url(@document)
    assert_response :success
    assert_select "h1", text: @document.title
  end

  test "should get edit" do
    get edit_document_url(@document)
    assert_response :success
    assert_select "h1", text: /Edit Document/i
  end

  test "should update document" do
    patch document_url(@document), params: { 
      document: { 
        title: "Updated Title",
        content: "Updated content"
      } 
    }
    assert_redirected_to document_url(@document)
    assert_equal 'Document was successfully updated.', flash[:notice]
    
    @document.reload
    assert_equal "Updated Title", @document.title
    assert_equal "Updated content", @document.content.to_plain_text
  end

  test "should destroy document" do
    assert_difference('Document.count', -1) do
      delete document_url(@document)
    end

    assert_redirected_to documents_url
    assert_equal 'Document was successfully deleted.', flash[:notice]
  end

  test "should not show other users document" do
    # Simulate the other user's document
    other_document = documents(:document_two)
    
    get document_url(other_document)
    assert_redirected_to documents_url
    assert_equal 'You are not authorized to access this document.', flash[:alert]
  end

  test "should not edit other users document" do
    other_document = documents(:document_two)
    
    get edit_document_url(other_document)
    assert_redirected_to documents_url
    assert_equal 'You are not authorized to access this document.', flash[:alert]
  end

  test "should not update other users document" do
    other_document = documents(:document_two)
    
    patch document_url(other_document), params: { 
      document: { title: "Hacked!" } 
    }
    assert_redirected_to documents_url
    assert_equal 'You are not authorized to access this document.', flash[:alert]
    
    other_document.reload
    assert_not_equal "Hacked!", other_document.title
  end

  test "should not destroy other users document" do
    other_document = documents(:document_two)
    
    assert_no_difference('Document.count') do
      delete document_url(other_document)
    end
    
    assert_redirected_to documents_url
    assert_equal 'You are not authorized to access this document.', flash[:alert]
  end

  test "should handle non-existent document" do
    get document_url(id: 'non-existent')
    assert_redirected_to documents_url
    assert_equal 'Document not found.', flash[:alert]
  end

  test "should handle invalid document params on create" do
    assert_no_difference('Document.count') do
      post documents_url, params: { 
        document: { 
          title: "",  # Invalid - blank title
          content: "Content"
        } 
      }
    end

    assert_response :unprocessable_entity
    assert_select "div#error_explanation"
  end

  test "should handle invalid document params on update" do
    patch document_url(@document), params: { 
      document: { 
        title: "",  # Invalid - blank title
        content: "Updated content"
      } 
    }
    
    assert_response :unprocessable_entity
    assert_select "div#error_explanation"
    
    @document.reload
    assert_not_equal "", @document.title
  end
  
  test "should duplicate document" do
    assert_difference('Document.count', 1) do
      post duplicate_document_url(@document)
    end
    
    new_document = Document.last
    assert_redirected_to edit_document_url(new_document)
    assert_equal 'Document was successfully duplicated.', flash[:notice]
    assert_equal "#{@document.title} (Copy)", new_document.title
    assert_equal @document.description, new_document.description
    assert_equal @document.tags, new_document.tags
  end
  
  test "should autosave document" do
    patch autosave_document_url(@document), params: { 
      document: { content: "Autosaved content" } 
    }, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'saved', json_response['status']
    assert json_response['updated_at'].present?
    
    @document.reload
    assert_equal "Autosaved content", @document.content.to_plain_text
  end
  
  test "should handle autosave errors" do
    # Force an error by making the document invalid
    @document.update_column(:title, nil)
    
    patch autosave_document_url(@document), params: { 
      document: { content: "New content" } 
    }, as: :json
    
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert json_response['errors'].present?
  end
end