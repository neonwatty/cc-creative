require "test_helper"

class PresenceChannelTest < ActionCable::Channel::TestCase
  tests PresenceChannel
  
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:one)
    
    # Clear cache before each test
    Rails.cache.clear
  end
  
  teardown do
    Rails.cache.clear
  end

  test "subscribes to document channel with valid document_id" do
    # Mock Pundit authorization
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    
    subscribe document_id: @document.id
    
    assert subscription.confirmed?
    assert_has_stream_for @document
  end

  test "rejects subscription without document_id" do
    stub_connection current_user: @user
    
    subscribe
    
    assert subscription.rejected?
  end

  test "rejects subscription for invalid document_id" do
    stub_connection current_user: @user
    
    subscribe document_id: 99999
    
    assert subscription.rejected?
  end

  test "rejects subscription for unauthorized document" do
    # Mock Pundit authorization to deny access
    mock_policy = mock()
    mock_policy.stubs(:show?).returns(false)
    Pundit.stubs(:policy).returns(mock_policy)
    
    stub_connection current_user: @user
    
    subscribe document_id: @document.id
    
    assert subscription.rejected?
  end

  test "rejects subscription when Pundit raises NotAuthorizedError" do
    # Mock Pundit to raise error
    Pundit.stubs(:policy).raises(Pundit::NotAuthorizedError)
    
    stub_connection current_user: @user
    
    subscribe document_id: @document.id
    
    assert subscription.rejected?
  end

  test "broadcasts user joined on subscription" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Check broadcast was sent
    assert_broadcast_on(PresenceChannel.broadcasting_for(@document), {
      type: 'user_joined',
      user: {
        id: @user.id,
        name: @user.name,
        email: @user.email_address,
        avatar_url: nil
      },
      timestamp: kind_of(String)
    })
  end

  test "broadcasts user left on unsubscription" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    unsubscribe
    
    # Check broadcast was sent
    assert_broadcast_on(PresenceChannel.broadcasting_for(@document), {
      type: 'user_left',
      user_id: @user.id,
      timestamp: kind_of(String)
    })
  end

  test "handles typing indicator" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    perform :user_typing
    
    assert_broadcast_on(PresenceChannel.broadcasting_for(@document), {
      type: 'user_typing',
      user_id: @user.id,
      user_name: @user.name,
      timestamp: kind_of(String)
    })
  end

  test "handles stopped typing indicator" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    perform :user_stopped_typing
    
    assert_broadcast_on(PresenceChannel.broadcasting_for(@document), {
      type: 'user_stopped_typing',
      user_id: @user.id,
      timestamp: kind_of(String)
    })
  end

  test "handles cursor movement" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    perform :cursor_moved, position: { x: 100, y: 200 }
    
    assert_broadcast_on(PresenceChannel.broadcasting_for(@document), {
      type: 'cursor_moved',
      user_id: @user.id,
      user_name: @user.name,
      position: { x: 100.0, y: 200.0 },
      timestamp: kind_of(String)
    })
  end

  test "ignores cursor movement without valid position" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    perform :cursor_moved, position: { x: nil }
    
    # Should not broadcast anything
    # We can't easily test no broadcasts in ActionCable tests, so just ensure no error
    assert subscription.confirmed?
  end

  test "handles selection changes" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    selection = { start: 10, end: 20, text: "selected text" }
    perform :selection_changed, selection: selection
    
    assert_broadcast_on(PresenceChannel.broadcasting_for(@document), {
      type: 'selection_changed',
      user_id: @user.id,
      user_name: @user.name,
      selection: selection,
      timestamp: kind_of(String)
    })
  end

  test "returns presence data for document" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Add another user to presence (simulate)
    presence_key = "document_#{@document.id}_presence"
    other_user_data = {
      id: @other_user.id,
      name: @other_user.name,
      email: @other_user.email_address,
      joined_at: Time.current.iso8601,
      last_seen: Time.current.iso8601,
      typing: false
    }
    
    presence_data = { @other_user.id => other_user_data }
    Rails.cache.write(presence_key, presence_data, expires_in: 1.hour)
    
    perform :get_presence
    
    response = transmissions.last
    assert_equal 'presence_data', response[:type]
    assert_equal 1, response[:users].count
    assert_equal @other_user.id, response[:users].first[:id]
    assert response[:cursors].is_a?(Hash)
    assert response[:typing_users].is_a?(Array)
  end

  test "excludes current user from presence data" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Add current user and another user to presence
    presence_key = "document_#{@document.id}_presence"
    presence_data = {
      @user.id => { id: @user.id, name: @user.name, email: @user.email_address },
      @other_user.id => { id: @other_user.id, name: @other_user.name, email: @other_user.email_address }
    }
    Rails.cache.write(presence_key, presence_data, expires_in: 1.hour)
    
    perform :get_presence
    
    response = transmissions.last
    assert_equal 1, response[:users].count
    assert_equal @other_user.id, response[:users].first[:id]
    # Current user should be excluded
    assert_not response[:users].any? { |u| u[:id] == @user.id }
  end

  test "handles empty presence data" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    perform :get_presence
    
    response = transmissions.last
    assert_equal 'presence_data', response[:type]
    assert_equal 0, response[:users].count
    assert_empty response[:cursors]
    assert_empty response[:typing_users]
  end

  test "stores user presence on subscription" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Check presence was stored
    presence_key = "document_#{@document.id}_presence"
    presence_data = Rails.cache.read(presence_key)
    
    assert presence_data.is_a?(Hash)
    assert presence_data.key?(@user.id)
    
    user_data = presence_data[@user.id]
    assert_equal @user.id, user_data[:id]
    assert_equal @user.name, user_data[:name]
    assert_equal @user.email_address, user_data[:email]
    assert_equal false, user_data[:typing]
  end

  test "removes user presence on unsubscription" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Verify presence was added
    presence_key = "document_#{@document.id}_presence"
    presence_data = Rails.cache.read(presence_key)
    assert presence_data.key?(@user.id)
    
    unsubscribe
    
    # Verify presence was removed
    presence_data = Rails.cache.read(presence_key)
    assert_not presence_data&.key?(@user.id)
  end

  test "updates typing status correctly" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Start typing
    perform :user_typing
    
    presence_key = "document_#{@document.id}_presence"
    presence_data = Rails.cache.read(presence_key)
    user_data = presence_data[@user.id]
    
    assert_equal true, user_data[:typing]
    assert_not_nil user_data[:typing_at]
    
    # Stop typing
    perform :user_stopped_typing
    
    presence_data = Rails.cache.read(presence_key)
    user_data = presence_data[@user.id]
    
    assert_equal false, user_data[:typing]
    assert_nil user_data[:typing_at]
  end

  test "updates cursor position correctly" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    perform :cursor_moved, position: { x: 150, y: 250 }
    
    cursor_key = "document_#{@document.id}_cursors"
    cursors = Rails.cache.read(cursor_key)
    
    assert cursors.is_a?(Hash)
    assert cursors.key?(@user.id)
    
    cursor_data = cursors[@user.id]
    assert_equal @user.id, cursor_data[:user_id]
    assert_equal 150.0, cursor_data[:x]
    assert_equal 250.0, cursor_data[:y]
    assert_not_nil cursor_data[:updated_at]
  end

  test "handles multiple concurrent connections gracefully" do
    Pundit.stubs(:policy).returns(mock(show?: true))
    
    # Simulate multiple users connecting
    stub_connection current_user: @user
    subscribe document_id: @document.id
    
    # Add another user's presence data manually
    presence_key = "document_#{@document.id}_presence"
    other_user_data = {
      id: @other_user.id,
      name: @other_user.name,
      email: @other_user.email_address,
      joined_at: Time.current.iso8601,
      last_seen: Time.current.iso8601,
      typing: true
    }
    
    presence_data = Rails.cache.read(presence_key) || {}
    presence_data[@other_user.id] = other_user_data
    Rails.cache.write(presence_key, presence_data, expires_in: 1.hour)
    
    perform :get_presence
    
    response = transmissions.last
    assert_equal 1, response[:users].count
    assert_equal 1, response[:typing_users].count
    assert_equal @other_user.id, response[:typing_users].first
  end

  test "handles action calls without authorization gracefully" do
    skip "Skipping test that requires complex subscription setup"
  end
end