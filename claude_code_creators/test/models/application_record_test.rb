require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "ApplicationRecord inherits from ActiveRecord::Base" do
    assert ApplicationRecord < ActiveRecord::Base
  end

  test "ApplicationRecord is marked as primary abstract class" do
    assert ApplicationRecord.abstract_class?
  end

  test "ApplicationRecord serves as base class for models" do
    # Create a test model that inherits from ApplicationRecord
    test_model = Class.new(ApplicationRecord) do
      self.table_name = "users" # Use existing table for testing
    end

    assert test_model < ApplicationRecord
    assert test_model < ActiveRecord::Base
  end

  test "Models inherit connection from ApplicationRecord" do
    # Create a test model
    test_model = Class.new(ApplicationRecord) do
      self.table_name = "users"
    end

    # Should use the same connection as ApplicationRecord
    assert_equal ApplicationRecord.connection, test_model.connection
  end

  test "ApplicationRecord provides base configuration to all models" do
    # Test that abstract class configuration is set
    assert ApplicationRecord.abstract_class?

    # Test that it can be used as a base for other models
    test_model = Class.new(ApplicationRecord)
    refute test_model.abstract_class?
  end
end
