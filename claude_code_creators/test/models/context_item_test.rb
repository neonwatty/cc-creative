require "test_helper"

class ContextItemTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @document = documents(:article_one)
  end

  test "should be valid with all required attributes" do
    context_item = ContextItem.new(
      document: @document,
      user: @user,
      content: "Test content",
      item_type: "snippet",
      title: "Test Snippet"
    )
    assert context_item.valid?
  end

  test "should require content" do
    context_item = ContextItem.new(
      document: @document,
      user: @user,
      item_type: "snippet",
      title: "Test"
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:content], "can't be blank"
  end

  test "should require item_type" do
    context_item = ContextItem.new(
      document: @document,
      user: @user,
      content: "Test content",
      title: "Test"
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:item_type], "can't be blank"
  end

  test "should require title" do
    context_item = ContextItem.new(
      document: @document,
      user: @user,
      content: "Test content",
      item_type: "snippet"
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:title], "can't be blank"
  end

  test "should only allow valid item_types" do
    context_item = ContextItem.new(
      document: @document,
      user: @user,
      content: "Test content",
      item_type: "invalid",
      title: "Test"
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:item_type], "is not included in the list"
  end

  test "should accept valid item_types" do
    %w[snippet draft version].each do |item_type|
      context_item = ContextItem.new(
        document: @document,
        user: @user,
        content: "Test content",
        item_type: item_type,
        title: "Test #{item_type}"
      )
      assert context_item.valid?
    end
  end

  test "should limit title length to 255 characters" do
    context_item = ContextItem.new(
      document: @document,
      user: @user,
      content: "Test content",
      item_type: "snippet",
      title: "a" * 256
    )
    assert_not context_item.valid?
    assert_includes context_item.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "type check methods work correctly" do
    snippet = ContextItem.new(item_type: "snippet")
    assert snippet.snippet?
    assert_not snippet.draft?
    assert_not snippet.version?

    draft = ContextItem.new(item_type: "draft")
    assert draft.draft?
    assert_not draft.snippet?
    assert_not draft.version?

    version = ContextItem.new(item_type: "version")
    assert version.version?
    assert_not version.snippet?
    assert_not version.draft?
  end

  test "scopes filter correctly" do
    # Create test data
    snippet = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Snippet content",
      item_type: "snippet",
      title: "Test Snippet"
    )
    draft = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Draft content",
      item_type: "draft",
      title: "Test Draft"
    )
    version = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Version content",
      item_type: "version",
      title: "Test Version"
    )

    assert_includes ContextItem.snippets, snippet
    assert_not_includes ContextItem.snippets, draft
    assert_not_includes ContextItem.snippets, version

    assert_includes ContextItem.drafts, draft
    assert_not_includes ContextItem.drafts, snippet
    assert_not_includes ContextItem.drafts, version

    assert_includes ContextItem.versions, version
    assert_not_includes ContextItem.versions, snippet
    assert_not_includes ContextItem.versions, draft
  end

  test "recent scope orders by created_at descending" do
    # Clear existing context items from fixtures
    ContextItem.destroy_all
    
    old_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Old content",
      item_type: "snippet",
      title: "Old",
      created_at: 2.days.ago
    )
    new_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "New content",
      item_type: "snippet",
      title: "New",
      created_at: 1.hour.ago
    )

    recent_items = ContextItem.recent
    assert_equal new_item, recent_items.first
    assert_equal old_item, recent_items.last
  end

  test "metadata is initialized as empty hash" do
    context_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Test content",
      item_type: "snippet",
      title: "Test"
    )
    assert_equal({}, context_item.metadata)
  end

  test "can store and retrieve metadata" do
    context_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Test content",
      item_type: "snippet",
      title: "Test",
      metadata: { language: "ruby", line_count: 10 }
    )
    context_item.reload
    assert_equal "ruby", context_item.metadata["language"]
    assert_equal 10, context_item.metadata["line_count"]
  end

  # Search functionality tests
  test "search_content is populated on save" do
    context_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Ruby code example",
      item_type: "snippet",
      title: "Example Code"
    )
    
    assert_equal "example code ruby code example snippet", context_item.search_content
  end

  test "search_content is updated when content changes" do
    context_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Original content",
      item_type: "snippet",
      title: "Original Title"
    )
    
    context_item.update!(content: "Updated content", title: "New Title")
    assert_equal "new title updated content snippet", context_item.search_content
  end

  test "search scope finds items by query" do
    # Clear existing items
    ContextItem.destroy_all
    
    item1 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Ruby on Rails tutorial",
      item_type: "snippet",
      title: "Rails Guide"
    )
    
    item2 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "JavaScript async/await",
      item_type: "snippet",
      title: "JS Tips"
    )
    
    # Search for "rails"
    results = ContextItem.search("rails")
    assert_includes results, item1
    assert_not_includes results, item2
    
    # Search for "javascript"
    results = ContextItem.search("javascript")
    assert_includes results, item2
    assert_not_includes results, item1
    
    # Case insensitive search
    results = ContextItem.search("RAILS")
    assert_includes results, item1
  end

  test "search scope returns all items when query is blank" do
    ContextItem.destroy_all
    
    3.times do |i|
      ContextItem.create!(
        document: @document,
        user: @user,
        content: "Content #{i}",
        item_type: "snippet",
        title: "Title #{i}"
      )
    end
    
    assert_equal 3, ContextItem.search("").count
    assert_equal 3, ContextItem.search(nil).count
  end

  test "search scope handles special characters" do
    item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Code with special chars: $var = 'test';",
      item_type: "snippet",
      title: "PHP Example"
    )
    
    # Should handle special SQL characters
    results = ContextItem.search("$var")
    assert_includes results, item
    
    results = ContextItem.search("'test'")
    assert_includes results, item
  end

  test "by_type scope filters by item type" do
    ContextItem.destroy_all
    
    snippet = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Snippet content",
      item_type: "snippet",
      title: "Test Snippet"
    )
    
    draft = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Draft content",
      item_type: "draft",
      title: "Test Draft"
    )
    
    assert_includes ContextItem.by_type("snippet"), snippet
    assert_not_includes ContextItem.by_type("snippet"), draft
    
    assert_includes ContextItem.by_type("draft"), draft
    assert_not_includes ContextItem.by_type("draft"), snippet
    
    # Returns all when type is blank
    assert_equal 2, ContextItem.by_type("").count
    assert_equal 2, ContextItem.by_type(nil).count
  end

  test "by_date_range scope filters by date range" do
    ContextItem.destroy_all
    
    old_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Old content",
      item_type: "snippet",
      title: "Old Item",
      created_at: 1.month.ago
    )
    
    recent_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Recent content",
      item_type: "snippet",
      title: "Recent Item",
      created_at: 1.day.ago
    )
    
    future_item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Future content",
      item_type: "snippet",
      title: "Future Item",
      created_at: 1.day.from_now
    )
    
    # Test with start date only
    results = ContextItem.by_date_range(2.days.ago, nil)
    assert_includes results, recent_item
    assert_includes results, future_item
    assert_not_includes results, old_item
    
    # Test with end date only
    results = ContextItem.by_date_range(nil, Time.current)
    assert_includes results, old_item
    assert_includes results, recent_item
    assert_not_includes results, future_item
    
    # Test with both dates
    results = ContextItem.by_date_range(1.week.ago, Time.current)
    assert_includes results, recent_item
    assert_not_includes results, old_item
    assert_not_includes results, future_item
    
    # Returns all when both dates are blank
    assert_equal 3, ContextItem.by_date_range(nil, nil).count
  end

  test "filtered_search combines all filters" do
    ContextItem.destroy_all
    
    # Create test items
    old_snippet = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Old Ruby snippet",
      item_type: "snippet",
      title: "Ruby Code",
      created_at: 1.month.ago
    )
    
    recent_snippet = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Recent Ruby snippet",
      item_type: "snippet",
      title: "Ruby Tutorial",
      created_at: 1.hour.ago
    )
    
    recent_draft = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Recent Ruby draft",
      item_type: "draft",
      title: "Ruby Draft",
      created_at: 1.hour.ago
    )
    
    other_snippet = ContextItem.create!(
      document: @document,
      user: @user,
      content: "JavaScript code",
      item_type: "snippet",
      title: "JS Example",
      created_at: 1.hour.ago
    )
    
    # Test with all filters
    results = ContextItem.filtered_search(
      query: "ruby",
      item_type: "snippet",
      date_from: 1.day.ago,
      date_to: Time.current
    )
    
    assert_includes results, recent_snippet
    assert_not_includes results, old_snippet # Too old
    assert_not_includes results, recent_draft # Wrong type
    assert_not_includes results, other_snippet # Doesn't match query
  end

  test "search_with_highlights returns items with highlights" do
    ContextItem.destroy_all
    
    item = ContextItem.create!(
      document: @document,
      user: @user,
      content: "This is a test of the search functionality",
      item_type: "snippet",
      title: "Search Test Example"
    )
    
    results = ContextItem.search_with_highlights("search")
    
    assert_equal 1, results.length
    result = results.first
    
    assert_equal item, result[:item]
    assert_equal "<mark>Search</mark> Test Example", result[:highlights][:title]
    assert result[:highlights][:content].include?("<mark>search</mark>")
  end

  test "search_with_highlights returns empty array for blank query" do
    assert_equal [], ContextItem.search_with_highlights("")
    assert_equal [], ContextItem.search_with_highlights(nil)
  end

  test "highlight_text marks matching text" do
    item = ContextItem.new
    
    # Basic highlighting
    result = item.highlight_text("Hello world", "world")
    assert_equal "Hello <mark>world</mark>", result
    
    # Case insensitive
    result = item.highlight_text("Hello WORLD", "world")
    assert_equal "Hello <mark>WORLD</mark>", result
    
    # Multiple occurrences
    result = item.highlight_text("Ruby is great, I love Ruby", "Ruby")
    assert_equal "<mark>Ruby</mark> is great, I love <mark>Ruby</mark>", result
  end

  test "highlight_text truncates long content" do
    item = ContextItem.new
    long_text = "The quick brown fox jumps over the lazy dog. " * 10 # 450 chars
    
    result = item.highlight_text(long_text, "fox", max_length: 100)
    # Text should be truncated (result will be longer due to mark tags)
    assert result.include?("..."), "Expected truncated text to include ellipsis"
    assert result.include?("<mark>fox</mark>"), "Expected highlighting to be preserved"
  end

  test "highlight_text handles special regex characters" do
    item = ContextItem.new
    
    result = item.highlight_text("Price is $10.00", "$10.00")
    assert_equal "Price is <mark>$10.00</mark>", result
    
    result = item.highlight_text("Use [brackets] here", "[brackets]")
    assert_equal "Use <mark>[brackets]</mark> here", result
  end

  test "search_highlights returns highlighted title and content" do
    item = ContextItem.new(
      title: "Ruby Programming Guide",
      content: "Learn Ruby programming with ruby code examples and Ruby development"
    )
    
    highlights = item.search_highlights("ruby")
    
    assert_equal "<mark>Ruby</mark> Programming Guide", highlights[:title]
    assert highlights[:content].include?("<mark>Ruby</mark>"), "Expected content to highlight 'Ruby'"
    assert highlights[:content].include?("<mark>ruby</mark>"), "Expected content to highlight 'ruby'"
  end

  test "search_highlights returns empty hash for blank query" do
    item = ContextItem.new(title: "Test", content: "Content")
    
    assert_equal({}, item.search_highlights(""))
    assert_equal({}, item.search_highlights(nil))
  end

  test "position is set automatically on create" do
    ContextItem.destroy_all
    
    # Create first item
    item1 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "First",
      item_type: "snippet",
      title: "First Item"
    )
    assert_equal 1, item1.position
    
    # Create second item of same type
    item2 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Second",
      item_type: "snippet",
      title: "Second Item"
    )
    assert_equal 2, item2.position
    
    # Create item of different type - should have position 1
    item3 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Draft",
      item_type: "draft",
      title: "First Draft"
    )
    assert_equal 1, item3.position
  end

  test "ordered scope sorts by position then created_at" do
    ContextItem.destroy_all
    
    # Create items with specific positions and times - need to update position after creation
    item1 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "First",
      item_type: "snippet",
      title: "Item 1",
      created_at: 2.hours.ago
    )
    item1.update_column(:position, 2)
    
    item2 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Second",
      item_type: "snippet",
      title: "Item 2",
      created_at: 1.hour.ago
    )
    item2.update_column(:position, 1)
    
    item3 = ContextItem.create!(
      document: @document,
      user: @user,
      content: "Third",
      item_type: "snippet",
      title: "Item 3",
      created_at: 30.minutes.ago
    )
    item3.update_column(:position, 2)
    
    ordered = ContextItem.ordered.to_a
    
    # item2 comes first (position 1)
    assert_equal item2, ordered[0]
    
    # For position 2, more recent item3 comes before item1
    assert_equal item3, ordered[1]
    assert_equal item1, ordered[2]
  end
end
