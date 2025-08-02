require 'rails_helper'

RSpec.describe "ContextItems", type: :request do
  let(:user) { create(:user) }
  let(:document) { create(:document, user: user) }
  let(:context_item) { create(:context_item, document: document, user: user) }

  before do
    sign_in user
  end

  describe "GET /documents/:document_id/context_items" do
    it "returns http success" do
      get document_context_items_path(document)
      expect(response).to have_http_status(:success)
    end

    it "displays context items for the document" do
      context_item
      get document_context_items_path(document)
      expect(response.body).to include(context_item.title)
    end
  end

  describe "GET /documents/:document_id/context_items/:id" do
    it "returns http success" do
      get document_context_item_path(document, context_item)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /documents/:document_id/context_items" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          context_item: {
            title: "New Context Item",
            content: "Some content",
            item_type: "snippet",
            metadata: { key: "value" }.to_json
          }
        }
      end

      it "creates a new context item" do
        expect {
          post document_context_items_path(document), params: valid_params
        }.to change(ContextItem, :count).by(1)
      end

      it "assigns the correct user and document" do
        post document_context_items_path(document), params: valid_params
        context_item = ContextItem.last
        expect(context_item.user).to eq(user)
        expect(context_item.document).to eq(document)
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          context_item: {
            title: "",
            content: "",
            item_type: "invalid"
          }
        }
      end

      it "does not create a new context item" do
        expect {
          post document_context_items_path(document), params: invalid_params
        }.not_to change(ContextItem, :count)
      end
    end
  end

  describe "PATCH /documents/:document_id/context_items/:id" do
    let(:new_attributes) do
      {
        context_item: {
          title: "Updated Title",
          content: "Updated content"
        }
      }
    end

    it "updates the context item" do
      patch document_context_item_path(document, context_item), params: new_attributes
      context_item.reload
      expect(context_item.title).to eq("Updated Title")
      expect(context_item.content).to eq("Updated content")
    end
  end

  describe "DELETE /documents/:document_id/context_items/:id" do
    it "destroys the context item" do
      context_item
      expect {
        delete document_context_item_path(document, context_item)
      }.to change(ContextItem, :count).by(-1)
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let(:other_document) { create(:document, user: other_user) }

    before do
      sign_out user
      sign_in other_user
    end

    it "prevents access to other users' document context items" do
      get document_context_items_path(document)
      expect(response).to redirect_to(documents_path)
    end

    it "prevents viewing other users' context items" do
      get document_context_item_path(document, context_item)
      expect(response).to redirect_to(documents_path)
    end

    it "prevents creating context items on other users' documents" do
      post document_context_items_path(document), params: {
        context_item: { title: "Test", content: "Test", item_type: "snippet" }
      }
      expect(response).to redirect_to(documents_path)
    end
  end
end
