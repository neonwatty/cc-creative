# frozen_string_literal: true

class Api::V1::CollaborationController < CollaborationController
  # Inherits all functionality from CollaborationController
  # API-specific modifications can be added here if needed
  
  private
  
  # Override to handle API-specific document finding
  def set_document
    @document = Document.find(params[:document_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "document_not_found" }, status: :not_found
  end
  
  # Override authentication to return JSON instead of redirecting
  def request_authentication
    render json: { error: "Authentication required" }, status: :unauthorized
  end
end