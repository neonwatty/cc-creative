# frozen_string_literal: true

# Helper module for testing services
module ServiceTestHelper
  # Add missing assertion methods
  def assert_present(object, message = nil)
    assert object.present?, message || "Expected #{mu_pp(object)} to be present"
  end

  def assert_blank(object, message = nil)
    assert object.blank?, message || "Expected #{mu_pp(object)} to be blank"
  end

  # Mocha helper methods
  def hash_including(expected_hash)
    # Use mocha's has_entries instead of HashIncluding
    has_entries(expected_hash)
  end

  def match(pattern)
    # Use regexp directly
    regexp_matches(pattern)
  end

  # ActionCable mock channels
  def setup_mock_channels
    # Mock NotificationChannel if not defined
    unless defined?(NotificationChannel)
      Object.const_set(:NotificationChannel, Class.new do
        def self.broadcast_to(target, data)
          Rails.logger.info "Mock broadcast to #{target}: #{data}"
        end
      end)
    end

    # Mock ContextChannel if not defined
    unless defined?(ContextChannel)
      Object.const_set(:ContextChannel, Class.new do
        def self.broadcast_to(target, data)
          Rails.logger.info "Mock context broadcast to #{target}: #{data}"
        end
      end)
    end

    # Mock WorkflowChannel if not defined
    unless defined?(WorkflowChannel)
      Object.const_set(:WorkflowChannel, Class.new do
        def self.broadcast_to(target, data)
          Rails.logger.info "Mock workflow broadcast to #{target}: #{data}"
        end
      end)
    end
  end

  # Net timeout error helper
  def setup_net_timeout_error
    unless defined?(Net::TimeoutError)
      Net.const_set(:TimeoutError, Class.new(StandardError))
    end
  end
end

# Include in test classes
ActiveSupport::TestCase.include ServiceTestHelper if defined?(ActiveSupport::TestCase)