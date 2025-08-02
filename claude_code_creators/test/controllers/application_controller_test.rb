require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "application controller exists and inherits from ActionController::Base" do
    assert ApplicationController < ActionController::Base
  end
end
