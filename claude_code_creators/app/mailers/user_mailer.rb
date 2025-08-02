class UserMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    mail(to: @user.email_address, subject: "Please confirm your email address")
  end
end
