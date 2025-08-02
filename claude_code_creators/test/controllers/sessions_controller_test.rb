require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  teardown do
    # Clear rate limit store after each test to prevent interference
    Rails.cache.clear if defined?(Rails.cache)
  end

  test "should get new" do
    get new_session_url
    assert_response :success
  end

  test "should create session with valid credentials" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    assert_redirected_to root_url
    assert_not_nil cookies[:session_id]
  end

  test "should not create session with invalid email" do
    post session_url, params: {
      email_address: "nonexistent@example.com",
      password: "password"
    }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should not create session with invalid password" do
    post session_url, params: {
      email_address: @user.email_address,
      password: "wrongpassword"
    }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should destroy session" do
    # First sign in
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }
    assert_not_nil cookies[:session_id]

    # Then sign out
    delete session_url
    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "should redirect to requested page after authentication" do
    # Try to access protected page
    get documents_url
    assert_redirected_to new_session_path

    # Sign in
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    # Should redirect to originally requested page
    assert_redirected_to documents_url
  end

  test "should rate limit login attempts" do
    # Make 10 login attempts quickly
    10.times do
      post session_url, params: {
        email_address: "test@example.com",
        password: "wrongpassword"
      }
    end

    # 11th attempt should be rate limited
    post session_url, params: {
      email_address: "test@example.com",
      password: "wrongpassword"
    }

    assert_redirected_to new_session_url
    assert_equal "Try again later.", flash[:alert]
  end

  test "should create session record with user agent and ip" do
    assert_difference "Session.count", 1 do
      post session_url, params: {
        email_address: @user.email_address,
        password: "password"
      },
      headers: { "User-Agent" => "Test Browser" }
    end

    session = Session.last
    assert_equal @user, session.user
    assert_not_nil session.ip_address, "IP address should not be nil"
    assert_not_nil session.user_agent, "User agent should not be nil"
  end

  test "should not require authentication for new action" do
    get new_session_url
    assert_response :success
  end

  test "should not require authentication for create action" do
    post session_url, params: {
      email_address: "test@example.com",
      password: "password"
    }
    # Should redirect (either to root or new_session), not to authentication
    assert_response :redirect
  end

  test "should not create session for unconfirmed email" do
    # Create unconfirmed user
    unconfirmed_user = User.create!(
      name: "Unconfirmed User",
      email_address: "unconfirmed@example.com",
      password: "password",
      email_confirmed: false
    )

    post session_url, params: {
      email_address: unconfirmed_user.email_address,
      password: "password"
    }

    assert_redirected_to new_session_path
    assert_equal "Please confirm your email address before signing in. Check your inbox for the confirmation email.", flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "should handle login with existing identity" do
    # Create an identity linked to the user
    identity = @user.identities.create!(
      provider: "google",
      uid: "12345",
      email: @user.email_address,
      name: @user.name
    )

    # Now login with the user
    post session_url, params: {
      email_address: @user.email_address,
      password: "password"
    }

    # Should login successfully
    assert_redirected_to root_url
    assert_not_nil cookies[:session_id]
  end

  test "destroy action clears session" do
    # First sign in
    sign_in_as(@user)

    # Then sign out
    delete session_url

    assert_redirected_to new_session_path
    # Cookie might be empty string rather than nil
    assert cookies[:session_id].blank?
  end

  test "new action renders login form" do
    get new_session_url

    assert_response :success
    # The form might post to session_url not session_path
    assert_select "form"
  end
end
