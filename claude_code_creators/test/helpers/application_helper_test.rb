require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # format_date tests
  test "format_date returns empty string for nil" do
    assert_equal "", format_date(nil)
  end

  test "format_date formats today's date" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      date = Time.current
      assert_equal "Today at 2:30 PM", format_date(date)
    end
  end

  test "format_date formats yesterday's date" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      date = 1.day.ago
      assert_equal "Yesterday at 2:30 PM", format_date(date)
    end
  end

  test "format_date formats date within last 7 days" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do # Monday
      date = Time.zone.local(2024, 1, 12, 10, 15, 0) # Friday
      assert_equal "Friday at 10:15 AM", format_date(date)
    end
  end

  test "format_date formats older dates with full date" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      date = Time.zone.local(2023, 12, 25, 10, 0, 0)
      assert_equal "December 25, 2023", format_date(date)
    end
  end

  test "format_date handles midnight correctly" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      date = Time.zone.local(2024, 1, 15, 0, 0, 0)
      assert_equal "Today at 12:00 AM", format_date(date)
    end
  end

  test "format_date handles noon correctly" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      date = Time.zone.local(2024, 1, 15, 12, 0, 0)
      assert_equal "Today at 12:00 PM", format_date(date)
    end
  end

  test "format_date handles edge of 7 days ago" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      # Exactly 7 days ago
      date = Time.zone.local(2024, 1, 8, 14, 30, 0)
      assert_equal "Monday at 2:30 PM", format_date(date)
      
      # More than 7 days ago
      date = Time.zone.local(2024, 1, 7, 14, 30, 0)
      assert_equal "January 07, 2024", format_date(date)
    end
  end

  # truncate_content tests
  test "truncate_content returns empty string for nil" do
    assert_equal "", truncate_content(nil)
  end

  test "truncate_content returns empty string for blank content" do
    assert_equal "", truncate_content("")
    assert_equal "", truncate_content("   ")
  end

  test "truncate_content truncates long text to default length" do
    long_text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    result = truncate_content(long_text)
    assert result.length <= 100
    assert result.end_with?("...")
  end

  test "truncate_content does not truncate short text" do
    short_text = "This is a short text"
    assert_equal short_text, truncate_content(short_text)
  end

  test "truncate_content respects custom length parameter" do
    text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    result = truncate_content(text, 20)
    assert result.length <= 20
    assert result.end_with?("...")
  end

  test "truncate_content truncates at word boundaries" do
    text = "Lorem ipsum dolor sit amet consectetur"
    # Should truncate at word boundary, not in middle of word
    result = truncate_content(text, 25)
    assert_not result.include?("consecte...")
    assert result =~ /Lorem ipsum dolor.../
  end

  test "truncate_content handles rich text content" do
    # Mock rich text object
    rich_text = Struct.new(:to_plain_text).new("This is rich text content that should be truncated")
    result = truncate_content(rich_text, 20)
    assert result.length <= 20
    assert result.start_with?("This is rich...")
  end

  test "truncate_content converts non-string objects to string" do
    # Test with number
    assert_equal "12345", truncate_content(12345)
    
    # Test with array
    result = truncate_content(["apple", "banana", "orange"])
    assert result.start_with?('["apple"')
  end

  test "truncate_content handles exact length match" do
    text = "a" * 100
    result = truncate_content(text, 100)
    assert_equal text, result
  end

  test "truncate_content handles text slightly over limit" do
    text = "a" * 101
    result = truncate_content(text, 100)
    assert result.end_with?("...")
    assert result.length <= 100
  end
end