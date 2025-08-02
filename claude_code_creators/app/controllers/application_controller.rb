class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Temporarily disabled for test compatibility
  # allow_browser versions: :modern

  # Pundit error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_user

  private

  def current_user
    Current.user
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to access this document."
    redirect_to documents_url
  end
end
