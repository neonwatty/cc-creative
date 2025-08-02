ENV["RAILS_ENV"] ||= "test"

# SimpleCov must be started before any application code is loaded
require "simplecov"

require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
# require "webmock/minitest"

# Load support files
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Use a shared tmp folder for parallel tests
    parallelize_setup do |worker|
      SimpleCov.command_name "minitest-#{worker}"
    end

    parallelize_teardown do |worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Clear cache after each test to prevent interference
    teardown do
      Rails.cache.clear if defined?(Rails.cache)
    end

    # Add more helper methods to be used by all tests here...

    # Disable real HTTP connections except for localhost
    # WebMock.disable_net_connect!(allow_localhost: true)

    # Authentication test helpers
    def sign_in_as(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
      user
    end

    def sign_out
      delete session_url
    end

    def authenticated_user
      users(:one)
    end
  end
end

# Action Controller test helpers
class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
    user
  end

  def sign_out
    delete session_url
  end
end
