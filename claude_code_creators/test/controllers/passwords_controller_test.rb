require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get new" do
    get new_password_url
    assert_response :success
  end

  test "should create password reset for existing user" do
    # Ensure mail delivery
    assert_emails 1 do
      post passwords_url, params: { email_address: @user.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should not reveal if user doesn't exist" do
    # Should still show success message even for non-existent user
    assert_no_emails do
      post passwords_url, params: { email_address: "nonexistent@example.com" }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should get edit with valid token" do
    # Generate a password reset token
    token = @user.generate_token_for(:password_reset)

    get edit_password_url(token)
    assert_response :success
  end

  test "should redirect for edit with invalid token" do
    get edit_password_url("invalid_token")
    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should update password with valid token and matching passwords" do
    token = @user.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to new_session_path
    assert_equal "Password has been reset.", flash[:notice]

    # Verify password was actually changed
    @user.reload
    assert @user.authenticate("newpassword123")
  end

  test "should not update password with mismatched confirmation" do
    token = @user.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "differentpassword"
    }

    assert_redirected_to edit_password_path(token)
    assert_equal "Passwords did not match.", flash[:alert]

    # Verify password was not changed
    @user.reload
    assert @user.authenticate("password")
  end

  test "should not update password with invalid token" do
    patch password_url("invalid_token"), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should not require authentication for any password actions" do
    # Test that we can access all password actions without being signed in
    get new_password_url
    assert_response :success

    post passwords_url, params: { email_address: @user.email_address }
    assert_redirected_to new_session_path

    token = @user.generate_token_for(:password_reset)
    get edit_password_url(token)
    assert_response :success
  end

  test "should handle expired tokens gracefully" do
    # Create an expired token by manipulating time
    token = nil
    travel_to 2.hours.ago do
      token = @user.generate_token_for(:password_reset)
    end

    # Try to use the expired token
    get edit_password_url(token)
    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end
end
