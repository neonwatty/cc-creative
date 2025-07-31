require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "default from address" do
    assert_equal ["noreply@claudecodecreators.com"], ApplicationMailer.default[:from]
  end

  test "uses mailer layout" do
    # ApplicationMailer should specify 'mailer' as the layout
    assert_equal "mailer", ApplicationMailer._layout
  end

  test "inherits from ActionMailer::Base" do
    assert ApplicationMailer < ActionMailer::Base
  end
end