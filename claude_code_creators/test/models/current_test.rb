require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    # Clear Current attributes before each test
    Current.reset
  end

  teardown do
    # Ensure Current is reset after each test
    Current.reset
  end

  test "Current inherits from ActiveSupport::CurrentAttributes" do
    assert Current < ActiveSupport::CurrentAttributes
  end

  test "has session attribute" do
    assert Current.respond_to?(:session)
    assert Current.respond_to?(:session=)
  end

  test "has user attribute" do
    assert Current.respond_to?(:user)
    assert Current.respond_to?(:user=)
  end

  test "can set and get session" do
    session = sessions(:john_session)
    Current.session = session

    assert_equal session, Current.session
  end

  test "user method returns session user" do
    session = sessions(:john_session)
    Current.session = session

    # The user method returns session.user, not a directly set user
    assert_equal session.user, Current.user
  end

  test "user returns nil when session is nil" do
    Current.session = nil

    assert_nil Current.user
  end

  test "user returns session's user when session is present" do
    session = sessions(:john_session)
    user = session.user
    Current.session = session

    assert_equal user, Current.user
  end

  test "user method uses safe navigation for session" do
    # Set session to nil to test safe navigation
    Current.session = nil

    # Should not raise NoMethodError and return nil
    assert_nil Current.user
  end

  test "reset clears all attributes" do
    session = sessions(:john_session)

    Current.session = session

    assert_not_nil Current.session
    assert_not_nil Current.user

    Current.reset

    assert_nil Current.session
    assert_nil Current.user
  end

  test "attributes are thread-local" do
    session1 = sessions(:john_session)
    session2 = sessions(:jane_session)

    # Set session in main thread
    Current.session = session1

    # In a new thread, Current should be clean
    thread_session = nil
    thread = Thread.new do
      thread_session = Current.session
      Current.session = session2
      Thread.current[:thread_current_session] = Current.session
    end
    thread.join

    # Main thread should still have session1
    assert_equal session1, Current.session
    # Thread should have had nil initially
    assert_nil thread_session
    # Thread should have set session2
    assert_equal session2, thread[:thread_current_session]
  end

  test "before_reset callback functionality" do
    # Track if callback was called
    callback_called = false

    Current.before_reset do
      callback_called = true
    end

    Current.session = sessions(:john_session)
    Current.reset

    assert callback_called
  end

  test "attributes are isolated per request in Rails" do
    # This test simulates how Rails would use Current
    session1 = sessions(:john_session)
    session2 = sessions(:jane_session)

    # Simulate first request
    Current.session = session1
    assert_equal session1.user, Current.user

    # Simulate request boundary
    Current.reset

    # Simulate second request
    Current.session = session2
    assert_equal session2.user, Current.user
    assert_not_equal session1.user, Current.user
  end
end
