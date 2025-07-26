require "test_helper"

class UserTest < ActiveSupport::TestCase
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
    invalid_emails = ["user@", "@example.com", "user.example.com", "user example@test.com"]
    
    invalid_emails.each do |invalid_email|
      @user.email_address = invalid_email
      assert_not @user.valid?, "#{invalid_email} should be invalid"
      assert_includes @user.errors[:email_address], "is invalid"
    end
  end

  test "should accept valid email formats" do
    valid_emails = ["user@example.com", "USER@foo.COM", "A_US-ER@foo.bar.org", "first.last@foo.jp", "alice+bob@baz.cn"]
    
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
end