require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @user.update!(email_address: "test@example.com")
  end

  test "reset" do
    mail = PasswordsMailer.reset(@user)

    assert_equal "Reset your password", mail.subject
    assert_equal [ "test@example.com" ], mail.to
    assert_equal [ "noreply@claudecodecreators.com" ], mail.from

    # Check content that's actually in the email
    assert_match @user.name, mail.body.encoded
    assert_match "Reset Password", mail.body.encoded
    assert_match "Claude Code Creators", mail.body.encoded
    assert_match "expire in", mail.body.encoded
  end

  test "reset email includes user in instance variable" do
    mail = PasswordsMailer.reset(@user)

    # The mailer should set @user instance variable
    assert_not_nil mail
    assert_equal @user.email_address, mail.to.first
  end

  test "reset email is multipart" do
    mail = PasswordsMailer.reset(@user)
    assert mail.multipart?
  end

  test "reset email has correct headers" do
    mail = PasswordsMailer.reset(@user)

    assert_equal "Reset your password", mail.subject
    assert_equal [ "test@example.com" ], mail.to
    assert_equal [ "noreply@claudecodecreators.com" ], mail.from
  end
end
