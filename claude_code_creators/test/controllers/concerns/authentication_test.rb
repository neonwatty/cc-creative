require "test_helper"

class AuthenticationTest < ActionController::TestCase
  # Create a test controller that includes the Authentication concern
  class TestController < ApplicationController
    include Authentication
    
    def index
      render plain: "Success"
    end
    
    def public_action
      render plain: "Public"
    end
    
    allow_unauthenticated_access only: :public_action
  end
  
  setup do
    @controller = TestController.new
    @user = users(:john)
    @session = sessions(:john_session)
    
    # Set up routes for test controller
    Rails.application.routes.draw do
      get "test" => "authentication_test/test#index"
      get "test/public" => "authentication_test/test#public_action"
      resources :sessions, only: [:new, :create, :destroy]
      root to: "welcome#index"
    end
  end
  
  teardown do
    # Reset routes after test
    Rails.application.reload_routes!
  end
  
  # Test authenticated? helper method
  test "authenticated? returns false when no session exists" do
    get :index
    assert_not @controller.send(:authenticated?)
  end
  
  test "authenticated? returns true when valid session exists" do
    cookies.signed[:session_id] = @session.id
    get :index
    assert @controller.send(:authenticated?)
  end
  
  # Test require_authentication
  test "require_authentication redirects to login when not authenticated" do
    get :index
    assert_redirected_to new_session_path
  end
  
  test "require_authentication stores return URL in session" do
    get :index
    assert_equal "http://test.host/test", session[:return_to_after_authenticating]
  end
  
  test "require_authentication allows access when authenticated" do
    cookies.signed[:session_id] = @session.id
    get :index
    assert_response :success
    assert_equal "Success", response.body
  end
  
  # Test allow_unauthenticated_access
  test "allow_unauthenticated_access skips authentication for specified actions" do
    get :public_action
    assert_response :success
    assert_equal "Public", response.body
  end
  
  # Test resume_session
  test "resume_session sets Current.session and Current.user when valid cookie exists" do
    cookies.signed[:session_id] = @session.id
    
    @controller.send(:resume_session)
    
    assert_equal @session, Current.session
    assert_equal @user, Current.user
  end
  
  test "resume_session returns nil when no cookie exists" do
    result = @controller.send(:resume_session)
    assert_nil result
    assert_nil Current.session
    assert_nil Current.user
  end
  
  test "resume_session returns nil when session not found" do
    cookies.signed[:session_id] = "invalid-id"
    
    result = @controller.send(:resume_session)
    assert_nil result
    assert_nil Current.session
    assert_nil Current.user
  end
  
  # Test find_session_by_cookie
  test "find_session_by_cookie returns session when valid cookie exists" do
    cookies.signed[:session_id] = @session.id
    
    found_session = @controller.send(:find_session_by_cookie)
    assert_equal @session, found_session
  end
  
  test "find_session_by_cookie returns nil when no cookie exists" do
    found_session = @controller.send(:find_session_by_cookie)
    assert_nil found_session
  end
  
  test "find_session_by_cookie returns nil when session not found" do
    cookies.signed[:session_id] = "nonexistent-id"
    
    found_session = @controller.send(:find_session_by_cookie)
    assert_nil found_session
  end
  
  # Test after_authentication_url
  test "after_authentication_url returns stored URL and clears it" do
    session[:return_to_after_authenticating] = "/documents"
    
    url = @controller.send(:after_authentication_url)
    assert_equal "/documents", url
    assert_nil session[:return_to_after_authenticating]
  end
  
  test "after_authentication_url returns root_url when no stored URL" do
    url = @controller.send(:after_authentication_url)
    assert_equal root_url, url
  end
  
  # Test start_new_session_for
  test "start_new_session_for creates new session for user" do
    @request.user_agent = "Test Browser"
    @request.remote_ip = "127.0.0.1"
    
    assert_difference "Session.count", 1 do
      new_session = @controller.send(:start_new_session_for, @user)
      
      assert_equal @user, new_session.user
      assert_equal "Test Browser", new_session.user_agent
      assert_equal "127.0.0.1", new_session.ip_address
      assert_equal new_session, Current.session
    end
  end
  
  test "start_new_session_for sets permanent signed cookie" do
    new_session = @controller.send(:start_new_session_for, @user)
    
    assert_equal new_session.id, cookies.signed[:session_id]
    # Cookie should be permanent (check that it was set)
    assert cookies[:session_id]
  end
  
  # Test terminate_session
  test "terminate_session destroys current session and clears cookie" do
    cookies.signed[:session_id] = @session.id
    Current.session = @session
    
    assert_difference "Session.count", -1 do
      @controller.send(:terminate_session)
    end
    
    assert_nil cookies[:session_id]
  end
  
  # Test helper_method
  test "authenticated? is available as helper method" do
    assert @controller.class._helper_methods.include?(:authenticated?)
  end
  
  # Test concern inclusion
  test "including Authentication adds before_action" do
    callbacks = TestController._process_action_callbacks.select { |cb| cb.kind == :before }
    auth_callbacks = callbacks.select { |cb| cb.filter == :require_authentication }
    
    assert_not_empty auth_callbacks
  end
  
  test "class inherits allow_unauthenticated_access method" do
    assert TestController.respond_to?(:allow_unauthenticated_access)
  end
end