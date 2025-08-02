require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  test "ApplicationJob inherits from ActiveJob::Base" do
    assert ApplicationJob < ActiveJob::Base
  end

  test "ApplicationJob is abstract class for other jobs" do
    # Test that we can create a subclass
    test_job_class = Class.new(ApplicationJob) do
      def perform
        "test"
      end
    end

    assert test_job_class < ApplicationJob
    assert test_job_class < ActiveJob::Base
  end

  test "ApplicationJob can be subclassed" do
    # Create a concrete job class
    concrete_job = Class.new(ApplicationJob) do
      def perform(arg)
        "Performed with #{arg}"
      end
    end

    # Test that the job can be instantiated
    job = concrete_job.new
    assert_instance_of concrete_job, job
  end

  test "ApplicationJob provides base configuration" do
    # ApplicationJob doesn't have retry_on or discard_on enabled
    # (they are commented out), so we test that the base class exists
    assert ApplicationJob.respond_to?(:retry_on)
    assert ApplicationJob.respond_to?(:discard_on)
  end
end
