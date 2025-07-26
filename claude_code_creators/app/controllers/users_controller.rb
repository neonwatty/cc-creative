class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create confirm_email ]
  layout "authentication", only: %i[ new create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      @user.send_confirmation_email
      redirect_to new_session_path, notice: "Welcome! Please check your email to confirm your account."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def confirm_email
    if user = User.find_by_email_confirmation_token(params[:token])
      user.confirm_email!
      redirect_to new_session_path, notice: "Your email has been confirmed! You can now sign in."
    else
      redirect_to new_session_path, alert: "Invalid or expired confirmation link."
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :role)
  end
end
