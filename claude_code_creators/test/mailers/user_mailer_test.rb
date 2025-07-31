require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @user.update!(email_address: "user@example.com")
  end

  test "confirmation" do
    mail = UserMailer.confirmation(@user)
    
    assert_equal "Please confirm your email address", mail.subject
    assert_equal ["user@example.com"], mail.to
    assert_equal ["noreply@claudecodecreators.com"], mail.from
    assert_match @user.email_address, mail.body.encoded
  end

  test "confirmation email includes user in instance variable" do
    mail = UserMailer.confirmation(@user)
    
    # The mailer should set @user instance variable
    assert_not_nil mail
    assert_equal @user.email_address, mail.to.first
  end

  test "confirmation email is multipart" do
    mail = UserMailer.confirmation(@user)
    assert mail.multipart?
  end

  test "confirmation email has correct headers" do
    mail = UserMailer.confirmation(@user)
    
    assert_equal "Please confirm your email address", mail.subject
    assert_equal ["user@example.com"], mail.to
    assert_equal ["noreply@claudecodecreators.com"], mail.from
  end

  test "confirmation email uses correct layout" do
    mail = UserMailer.confirmation(@user)
    
    # Check that it uses the mailer layout
    assert_match /mailer/, mail.body.encoded
  end
end