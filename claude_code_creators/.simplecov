# frozen_string_literal: true

SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_filter "/bin/"
  add_filter "/log/"
  add_filter "/tmp/"
  add_filter "/public/"
  add_filter "/storage/"

  # Filter out base classes that are just Rails boilerplate
  add_filter "/app/channels/application_cable/"
  add_filter "/app/jobs/application_job.rb"
  add_filter "/app/mailers/application_mailer.rb"
  add_filter "/app/models/application_record.rb"
  add_filter "/app/controllers/application_controller.rb" unless File.read("app/controllers/application_controller.rb").lines.count > 10

  # Coverage groups
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Helpers", "app/helpers"
  add_group "Mailers", "app/mailers"
  add_group "Components", "app/components"
  add_group "Channels", "app/channels"
  add_group "Policies", "app/policies"

  # Enable branch coverage
  enable_coverage :branch

  # Track all Ruby files in app directory
  track_files "app/**/*.rb"

  # Set minimum coverage expectations (temporarily disabled to see actual coverage)
  # minimum_coverage line: 80, branch: 60

  # Configure for parallel testing
  SimpleCov.command_name "test:#{ENV['TEST_ENV_NUMBER']}" if ENV["TEST_ENV_NUMBER"]

  # Refuse to run tests if coverage data from previous run wasn't merged
  refuse_coverage_drop if ENV["CI"]
end

# Configure result merging for parallel tests
SimpleCov.at_exit do
  SimpleCov.result.format! if SimpleCov.result
end
