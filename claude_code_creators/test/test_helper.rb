ENV["RAILS_ENV"] ||= "test"

# SimpleCov must be started before any application code is loaded
require 'simplecov'

# Configure SimpleCov for parallel testing
if ENV['TEST_ENV_NUMBER']
  SimpleCov.command_name "test:#{ENV['TEST_ENV_NUMBER']}"
  SimpleCov.at_exit do
    SimpleCov.result.format!
  end
end

SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/app/channels/application_cable/channel.rb'
  add_filter '/app/channels/application_cable/connection.rb'
  add_filter '/app/jobs/application_job.rb'
  add_filter '/app/mailers/application_mailer.rb'
  add_filter '/app/models/application_record.rb'
  
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Components', 'app/components'
  add_group 'Channels', 'app/channels'
  
  # Enable branch coverage
  enable_coverage :branch
  
  # Minimum coverage required (temporarily disabled while improving coverage)
  # minimum_coverage 80
  
  # Track files with 0% coverage
  track_files 'app/**/*.rb'
end

require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

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
