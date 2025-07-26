class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create omniauth omniauth_failure ]
  layout "authentication", only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.email_confirmed?
        start_new_session_for user
        
        # Check if there's a pending OAuth identity to link
        if session[:pending_identity]
          identity = Identity.find_or_initialize_by(
            provider: session[:pending_identity]["provider"],
            uid: session[:pending_identity]["uid"]
          )
          identity.user = user
          identity.email = session[:pending_identity]["email"]
          identity.name = session[:pending_identity]["name"]
          
          if identity.save
            session.delete(:pending_identity)
            redirect_to profile_path, notice: "Successfully linked your #{identity.provider.titleize} account!"
            return
          end
        end
        
        redirect_to after_authentication_url
      else
        redirect_to new_session_path, alert: "Please confirm your email address before signing in. Check your inbox for the confirmation email."
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  def omniauth
    auth = request.env['omniauth.auth']
    identity = Identity.find_or_create_from_auth(auth)
    
    if identity.user
      # Existing user with this OAuth account
      start_new_session_for identity.user
      redirect_to after_authentication_url
    elsif authenticated?
      # Logged in user linking new OAuth account
      identity.user = Current.user
      identity.save!
      redirect_to profile_path, notice: "#{auth.provider.titleize} account linked successfully!"
    else
      # New user or need to link to existing account
      if existing_user = User.find_by(email_address: auth.info.email)
        # Email matches existing user
        session[:pending_identity] = {
          provider: auth.provider,
          uid: auth.uid,
          email: auth.info.email,
          name: auth.info.name
        }
        redirect_to new_session_path, notice: "An account with this email already exists. Please sign in to link your #{auth.provider.titleize} account."
      else
        # Create new user
        user = User.new(
          email_address: auth.info.email,
          name: auth.info.name,
          password: SecureRandom.base58(16),
          email_confirmed: true,
          email_confirmed_at: Time.current
        )
        
        if user.save
          identity.user = user
          identity.save!
          start_new_session_for user
          redirect_to root_path, notice: "Welcome! Your account has been created."
        else
          redirect_to new_user_path, alert: "There was an error creating your account. Please try again."
        end
      end
    end
  end

  def omniauth_failure
    redirect_to new_session_path, alert: "Authentication failed. Please try again."
  end
end
