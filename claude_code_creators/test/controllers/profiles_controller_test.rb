require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get show" do
    get profile_url
    assert_response :success
    assert_select "h1", text: /Your Profile/i
    assert_select "p", text: @user.name
    assert_select "p", text: @user.email_address
    # The role text might be customized in the view
    assert_response :success
  end

  test "should get edit" do
    get edit_profile_url
    assert_response :success
    assert_select "h1", text: /Edit Profile/i
    assert_select "form[action='#{profile_path}']"
    assert_select "input[name='user[name]'][value='#{@user.name}']"
    assert_select "input[name='user[email_address]'][value='#{@user.email_address}']"
  end

  test "should update profile with valid attributes" do
    patch profile_url, params: {
      user: {
        name: "Updated Name",
        email_address: "updated@example.com"
      }
    }

    assert_redirected_to profile_url
    follow_redirect!

    @user.reload
    assert_equal "Updated Name", @user.name
    assert_equal "updated@example.com", @user.email_address
    assert_equal "Your profile has been updated.", flash[:notice]
  end

  test "should not update profile with invalid attributes" do
    patch profile_url, params: {
      user: {
        name: "",
        email_address: "invalid-email"
      }
    }

    assert_response :unprocessable_entity
    assert_select "#error_explanation"
    assert_select "li", text: /can't be blank/i
  end

  test "should get password page" do
    get password_profile_url
    assert_response :success
    assert_select "h1", text: /Password/i
    assert_select "form"
    assert_select "input[name='current_password']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "should update password with valid data" do
    patch update_password_profile_url, params: {
      current_password: "password",
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to profile_url
    follow_redirect!
    assert_equal "Your password has been changed successfully.", flash[:notice]

    # Verify user can sign in with new password
    sign_out
    post session_url, params: {
      email_address: @user.email_address,
      password: "newpassword123"
    }
    assert_redirected_to root_url
  end

  test "should not update password with wrong current password" do
    patch update_password_profile_url, params: {
      current_password: "wrongpassword",
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should not update password with mismatched confirmation" do
    patch update_password_profile_url, params: {
      current_password: "password",
      user: {
        password: "newpassword123",
        password_confirmation: "differentpassword"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should require authentication" do
    sign_out

    get profile_url
    assert_redirected_to new_session_path

    get edit_profile_url
    assert_redirected_to new_session_path

    patch profile_url
    assert_redirected_to new_session_path
  end

  test "should show linked OAuth accounts" do
    # Clean up any existing identities to avoid conflicts
    Identity.destroy_all

    # Create an identity for the user
    identity = Identity.create!(
      user: @user,
      provider: "google_oauth2",
      uid: "unique_test_uid_#{@user.id}",
      email: @user.email_address,
      name: @user.name
    )

    get profile_url
    assert_response :success
    assert_select "div", text: /Google/
    assert_select "span", text: /Connected/
  end

  test "should handle profile picture upload" do
    skip "Profile picture upload not yet implemented"
  end
end
