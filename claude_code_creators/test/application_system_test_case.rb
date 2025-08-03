require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Authentication helpers for system tests
  def sign_in_as(user)
    visit new_session_url
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    
    # Verify successful sign-in by checking we're no longer on the sign-in page
    assert_no_content "Sign in"
    assert_content user.name
    
    user
  end

  def sign_out
    click_on "Sign out" if has_link?("Sign out")
  end
end
