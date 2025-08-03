# frozen_string_literal: true

class Api::V1::DocumentsController < DocumentsController
  # Inherits all functionality from DocumentsController
  # API-specific modifications can be added here if needed
  
  # Override to provide JSON responses by default
  before_action :set_json_format
  
  private
  
  def set_json_format
    request.format = :json
  end
end