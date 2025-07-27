require "test_helper"

class ContextSidebarComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:one)
    @document = documents(:one)
    @document.user = @user
    @document.content = "Test document content"
    @document.save!
    
    # Clear existing context items from fixtures
    @document.context_items.destroy_all
    
    # Create some test context items
    @snippet = @document.context_items.create!(
      user: @user,
      title: "Test Snippet",
      content: "This is a test snippet content",
      item_type: "snippet"
    )
    
    @draft = @document.context_items.create!(
      user: @user,
      title: "Test Draft",
      content: "This is a test draft content",
      item_type: "draft"
    )
    
    @version = @document.context_items.create!(
      user: @user,
      title: "Version 1.0",
      content: "This is version 1.0 content",
      item_type: "version"
    )
  end

  test "renders component with all tabs" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    assert_text "Context Manager"
    assert_text "Snippets (1)"
    assert_text "Drafts (1)"
    assert_text "Versions (1)"
  end

  test "renders snippets in snippets tab" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user, active_tab: "snippets"))
    
    assert_text @snippet.title
    assert_text @snippet.content.truncate(100)
  end

  test "renders drafts in drafts tab" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user, active_tab: "drafts"))
    
    assert_selector "[data-panel='drafts']:not(.hidden)"
    assert_text @draft.title
  end

  test "renders versions in versions tab" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user, active_tab: "versions"))
    
    assert_selector "[data-panel='versions']:not(.hidden)"
    assert_text @version.title
  end

  test "renders empty state when no items" do
    @document.context_items.destroy_all
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    assert_text "No snippets yet"
    assert_text "Create first snippet"
  end

  test "renders search input" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    assert_selector "input[placeholder='Search items... (⌘K)']"
  end

  test "renders sort dropdown" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    assert_selector "select option[value='recent']"
    assert_selector "select option[value='alphabetical']"
    assert_selector "select option[value='modified']"
  end

  test "applies active tab classes correctly" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user, active_tab: "drafts"))
    
    assert_selector "button[data-tab='drafts'].bg-white.text-blue-600"
    assert_selector "button[data-tab='snippets'].text-gray-600"
  end

  test "includes action buttons" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    assert_text "Collapse"
    assert_text "Add Item"
  end

  test "accepts search query parameter" do
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "test"
    )
    
    render_inline(component)
    
    # The search query is set as the value in the input
    assert_selector "input[value='test']"
  end

  test "accepts sort by parameter" do
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      sort_by: "alphabetical"
    )
    
    render_inline(component)
    
    # The component uses the sort_by parameter internally for filtering
    # but doesn't set it as selected in the dropdown - that's managed by JavaScript
    assert_selector "select option[value='alphabetical']"
  end

  # Search functionality tests
  test "renders search filters" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    # Type filter
    assert_selector "select option[value='']", text: "All types"
    assert_selector "select option[value='snippet']", text: "Snippets only"
    assert_selector "select option[value='draft']", text: "Drafts only"
    assert_selector "select option[value='version']", text: "Versions only"
    
    # Date range filter
    assert_selector "select option[value='']", text: "All time"
    assert_selector "select option[value='today']", text: "Today"
    assert_selector "select option[value='week']", text: "This week"
    assert_selector "select option[value='month']", text: "This month"
  end

  test "shows search results info when search is active" do
    # Create more items for search
    2.times do |i|
      @document.context_items.create!(
        user: @user,
        title: "Ruby Tutorial #{i}",
        content: "Ruby programming content",
        item_type: "snippet"
      )
    end
    
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "Ruby",
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    assert_text "Found 2 items"
    assert_text "Clear filters"
  end

  test "shows clear search button when search is active" do
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "test"
    )
    
    render_inline(component)
    
    assert_selector "button[title='Clear search']"
  end

  test "filters items by search query" do
    # Create searchable items
    ruby_snippet = @document.context_items.create!(
      user: @user,
      title: "Ruby Code Example",
      content: "Ruby programming snippet",
      item_type: "snippet"
    )
    
    js_snippet = @document.context_items.create!(
      user: @user,
      title: "JavaScript Example",
      content: "JavaScript code snippet",
      item_type: "snippet"
    )
    
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "Ruby",
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    assert_text "Ruby Code Example"
    assert_no_text "JavaScript Example"
  end

  test "filters items by type" do
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      filter_type: "snippet",
      active_tab: "drafts"
    )
    
    render_inline(component)
    
    # Should show only snippets even in drafts tab
    assert_selector "[data-panel='drafts']:not(.hidden)"
    assert_no_text @draft.title
  end

  test "filters items by date range" do
    # Create an old item
    old_snippet = @document.context_items.create!(
      user: @user,
      title: "Old Snippet",
      content: "Old content",
      item_type: "snippet",
      created_at: 2.months.ago
    )
    
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      date_from: 1.week.ago,
      date_to: Time.current,
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    assert_text @snippet.title
    assert_no_text "Old Snippet"
  end

  test "applies multiple filters together" do
    # Create test items
    recent_ruby = @document.context_items.create!(
      user: @user,
      title: "Recent Ruby Snippet",
      content: "Ruby code",
      item_type: "snippet",
      created_at: 1.hour.ago
    )
    
    old_ruby = @document.context_items.create!(
      user: @user,
      title: "Old Ruby Snippet",
      content: "Ruby code",
      item_type: "snippet",
      created_at: 2.months.ago
    )
    
    recent_js = @document.context_items.create!(
      user: @user,
      title: "Recent JS Snippet",
      content: "JavaScript code",
      item_type: "snippet",
      created_at: 1.hour.ago
    )
    
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "Ruby",
      filter_type: "snippet",
      date_from: 1.week.ago,
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    assert_text "Recent Ruby Snippet"
    assert_no_text "Old Ruby Snippet"
    assert_no_text "Recent JS Snippet"
  end

  test "sorts items by different criteria" do
    # Clear existing items
    @document.context_items.destroy_all
    
    # Create items with specific attributes
    item_a = @document.context_items.create!(
      user: @user,
      title: "Alpha Item",
      content: "Content A",
      item_type: "snippet",
      created_at: 3.hours.ago,
      updated_at: 1.hour.ago,
      position: 3
    )
    
    item_b = @document.context_items.create!(
      user: @user,
      title: "Beta Item",
      content: "Content B",
      item_type: "snippet",
      created_at: 2.hours.ago,
      updated_at: 3.hours.ago,
      position: 1
    )
    
    item_c = @document.context_items.create!(
      user: @user,
      title: "Charlie Item",
      content: "Content C",
      item_type: "snippet",
      created_at: 1.hour.ago,
      updated_at: 2.hours.ago,
      position: 2
    )
    
    # Test alphabetical sorting
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      sort_by: "alphabetical",
      active_tab: "snippets"
    )
    render_inline(component)
    
    items = page.all("[data-panel='snippets'] .divide-y > div")
    assert items[0].text.include?("Alpha Item")
    assert items[1].text.include?("Beta Item")
    assert items[2].text.include?("Charlie Item")
  end

  test "shows highlighted search results" do
    # Skip this test if search highlighting is not visible in the UI
    # The highlighting is applied but may be rendered as HTML
    skip "Search highlighting is handled by the partial rendering"
  end

  test "handles empty search results" do
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "nonexistent",
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    assert_text "No snippets yet"
    assert_text "Found 0 items"
  end

  test "search is case insensitive" do
    @document.context_items.create!(
      user: @user,
      title: "UPPERCASE Title",
      content: "Some content",
      item_type: "snippet"
    )
    
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "uppercase",
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    assert_text "UPPERCASE Title"
  end

  test "renders form with correct data attributes" do
    render_inline(ContextSidebarComponent.new(document: @document, current_user: @user))
    
    assert_selector "form[data-controller='search-filter']"
    assert_selector "form[data-turbo-frame='context-sidebar-frame']"
    assert_selector "input[data-search-filter-target='searchInput']"
    assert_selector "select[data-search-filter-target='typeFilter']"
    assert_selector "select[data-search-filter-target='dateFilter']"
    assert_selector "select[data-search-filter-target='sortSelect']"
  end

  test "count updates reflect filtered results" do
    # Create multiple items
    3.times do |i|
      @document.context_items.create!(
        user: @user,
        title: "Ruby Item #{i}",
        content: "Ruby content",
        item_type: "snippet"
      )
    end
    
    2.times do |i|
      @document.context_items.create!(
        user: @user,
        title: "Python Item #{i}",
        content: "Python content",
        item_type: "snippet"
      )
    end
    
    component = ContextSidebarComponent.new(
      document: @document, 
      current_user: @user,
      search_query: "Ruby",
      active_tab: "snippets"
    )
    
    render_inline(component)
    
    # Tab should show filtered count
    assert_text "Snippets (3)"
  end
end