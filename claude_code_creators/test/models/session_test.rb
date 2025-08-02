require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email_address: "test@example.com",
      password: "password123"
    )
    @session = Session.new(
      user: @user,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0 Test Browser"
    )
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @session.valid?
  end

  test "should require a user" do
    @session.user = nil
    assert_not @session.valid?
    assert_includes @session.errors[:user], "must exist"
  end

  # Association tests
  test "should belong to user" do
    assert_respond_to @session, :user
    assert_instance_of User, @session.user
  end

  test "should save with minimal attributes" do
    minimal_session = Session.new(user: @user)
    assert minimal_session.save
  end

  test "should save with all attributes" do
    assert @session.save
    @session.reload
    assert_equal @user.id, @session.user_id
    assert_equal "127.0.0.1", @session.ip_address
    assert_equal "Mozilla/5.0 Test Browser", @session.user_agent
  end

  test "should be destroyed when user is destroyed" do
    @session.save!
    assert_difference "Session.count", -1 do
      @user.destroy
    end
  end

  test "should handle nil ip_address" do
    @session.ip_address = nil
    assert @session.valid?
    assert @session.save
  end

  test "should handle nil user_agent" do
    @session.user_agent = nil
    assert @session.valid?
    assert @session.save
  end

  test "should have timestamps" do
    @session.save!
    assert_not_nil @session.created_at
    assert_not_nil @session.updated_at
  end

  test "should allow multiple sessions per user" do
    @session.save!

    second_session = Session.new(
      user: @user,
      ip_address: "192.168.1.1",
      user_agent: "Chrome/91.0"
    )

    assert second_session.save
    assert_equal 2, @user.sessions.count
  end
end
