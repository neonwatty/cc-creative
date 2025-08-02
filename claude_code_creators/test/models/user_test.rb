require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  def setup
    @user = User.new(
      name: "Test User",
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should require name" do
    @user.name = ""
    assert_not @user.valid?
    assert_includes @user.errors[:name], "can't be blank"
  end

  test "should require email_address" do
    @user.email_address = ""
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test "should require valid email format" do
    invalid_emails = [ "user@", "@example.com", "user.example.com", "user example@test.com" ]

    invalid_emails.each do |invalid_email|
      @user.email_address = invalid_email
      assert_not @user.valid?, "#{invalid_email} should be invalid"
      assert_includes @user.errors[:email_address], "is invalid"
    end
  end

  test "should accept valid email formats" do
    valid_emails = [ "user@example.com", "USER@foo.COM", "A_US-ER@foo.bar.org", "first.last@foo.jp", "alice+bob@baz.cn" ]

    valid_emails.each do |valid_email|
      @user.email_address = valid_email
      assert @user.valid?, "#{valid_email} should be valid"
    end
  end

  test "should require unique email_address" do
    @user.save!
    duplicate_user = User.new(
      name: "Another User",
      email_address: @user.email_address.upcase, # Test case insensitivity
      password: "password123"
    )
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  test "should normalize email_address" do
    @user.email_address = "  TEST@EXAMPLE.COM  "
    @user.save!
    assert_equal "test@example.com", @user.email_address
  end

  # Password tests
  test "should require password" do
    @user.password = ""
    @user.password_confirmation = ""
    assert_not @user.valid?
  end

  test "should require password confirmation to match" do
    @user.password_confirmation = "different"
    assert_not @user.valid?
  end

  test "should have secure password" do
    @user.save!
    assert @user.authenticate("password123")
    assert_not @user.authenticate("wrongpassword")
  end

  # Association tests
  test "should have many sessions" do
    assert_respond_to @user, :sessions
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.sessions
  end

  test "should have many documents" do
    assert_respond_to @user, :documents
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.documents
  end

  test "should destroy associated sessions when destroyed" do
    @user.save!
    session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test Browser")

    assert_difference "Session.count", -1 do
      @user.destroy
    end
  end

  test "should destroy associated documents when destroyed" do
    @user.save!
    document = @user.documents.create!(
      title: "Test Document",
      content: "Test content",
      description: "Test description"
    )

    assert_difference "Document.count", -1 do
      @user.destroy
    end
  end

  # Authentication tests
  test "should authenticate with correct password" do
    @user.save!
    assert @user.authenticate("password123")
  end

  test "should not authenticate with incorrect password" do
    @user.save!
    assert_not @user.authenticate("wrongpassword")
  end

  test "should have password digest after saving" do
    @user.save!
    assert_not_nil @user.password_digest
    assert @user.password_digest.present?
  end

  # Rails 8 authentication specific tests
  test "should work with authenticate_by class method" do
    @user.save!

    authenticated_user = User.authenticate_by(
      email_address: @user.email_address,
      password: "password123"
    )

    assert_equal @user, authenticated_user
  end

  test "should return nil for authenticate_by with wrong password" do
    @user.save!

    authenticated_user = User.authenticate_by(
      email_address: @user.email_address,
      password: "wrongpassword"
    )

    assert_nil authenticated_user
  end

  test "should return nil for authenticate_by with non-existent email" do
    authenticated_user = User.authenticate_by(
      email_address: "nonexistent@example.com",
      password: "password123"
    )

    assert_nil authenticated_user
  end

  # Edge cases
  test "should handle email with extra spaces" do
    @user.email_address = "  test@example.com  "
    assert @user.valid?
    @user.save!
    assert_equal "test@example.com", @user.email_address
  end

  test "should be case insensitive for email uniqueness" do
    @user.email_address = "test@example.com"
    @user.save!

    duplicate_user = User.new(
      name: "Another User",
      email_address: "TEST@EXAMPLE.COM",
      password: "password123"
    )

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  # Token generation tests
  test "generates password reset token" do
    @user.save!
    token = @user.generate_token_for(:password_reset)

    assert_not_nil token
    assert token.length > 20
  end

  test "finds user by valid password reset token" do
    @user.save!
    token = @user.generate_token_for(:password_reset)

    found_user = User.find_by_password_reset_token(token)
    assert_equal @user, found_user
  end

  test "returns nil for invalid password reset token" do
    @user.save!

    found_user = User.find_by_password_reset_token("invalid_token")
    assert_nil found_user
  end

  test "finds user by valid password reset token with bang method" do
    @user.save!
    token = @user.generate_token_for(:password_reset)

    found_user = User.find_by_password_reset_token!(token)
    assert_equal @user, found_user
  end

  test "raises error for invalid password reset token with bang method" do
    @user.save!

    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_password_reset_token!("invalid_token")
    end
  end

  test "generates email confirmation token" do
    @user.save!
    token = @user.generate_token_for(:email_confirmation)

    assert_not_nil token
    assert token.length > 20
  end

  test "finds user by valid email confirmation token" do
    @user.save!
    token = @user.generate_token_for(:email_confirmation)

    found_user = User.find_by_email_confirmation_token(token)
    assert_equal @user, found_user
  end

  test "returns nil for invalid email confirmation token" do
    @user.save!

    found_user = User.find_by_email_confirmation_token("invalid_token")
    assert_nil found_user
  end

  test "finds user by valid email confirmation token with bang method" do
    @user.save!
    token = @user.generate_token_for(:email_confirmation)

    found_user = User.find_by_email_confirmation_token!(token)
    assert_equal @user, found_user
  end

  test "raises error for invalid email confirmation token with bang method" do
    @user.save!

    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_email_confirmation_token!("invalid_token")
    end
  end

  # Email confirmation tests
  test "confirms email successfully" do
    @user.save!
    assert_not @user.email_confirmed?

    @user.confirm_email!

    assert @user.reload.email_confirmed?
    assert_not_nil @user.email_confirmed_at
    assert @user.email_confirmed_at <= Time.current
  end

  test "sends confirmation email" do
    @user.save!

    assert_enqueued_emails 1 do
      @user.send_confirmation_email
    end

    assert_enqueued_email_with UserMailer, :confirmation, args: [ @user ]
  end

  # Token expiration tests
  test "password reset token expires after 2 hours" do
    @user.save!
    token = @user.generate_token_for(:password_reset)

    # Token should be valid now
    assert User.find_by_password_reset_token(token)

    # Travel 3 hours into the future
    travel 3.hours do
      assert_nil User.find_by_password_reset_token(token)
    end
  end

  test "email confirmation token expires after 24 hours" do
    @user.save!
    token = @user.generate_token_for(:email_confirmation)

    # Token should be valid now
    assert User.find_by_email_confirmation_token(token)

    # Travel 25 hours into the future
    travel 25.hours do
      assert_nil User.find_by_email_confirmation_token(token)
    end
  end

  # Role tests
  test "has role enum with correct values" do
    assert_equal "user", @user.role

    @user.role = :editor
    assert @user.editor?
    assert_not @user.admin?
    assert_not @user.user?

    @user.role = :admin
    assert @user.admin?
    assert_not @user.editor?
    assert_not @user.user?
  end
end
