require "test_helper"

class ContextItemsHelperTest < ActionView::TestCase
  setup do
    @context_item = context_items(:one)
    @context_item.update!(
      title: "Test Context Item",
      content: "This is a test content for the context item",
      item_type: "snippet"
    )
  end

  # context_item_preview_modal tests
  test "context_item_preview_modal returns nil for nil context item" do
    assert_nil context_item_preview_modal(nil)
  end

  test "context_item_preview_modal renders component without block" do
    # Mock the component rendering
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).with(context_item: @context_item).returns(mock_component)
    expects(:render).with(mock_component).returns("<div>rendered</div>")
    
    result = context_item_preview_modal(@context_item)
    assert_equal "<div>rendered</div>", result
  end

  test "context_item_preview_modal renders component with block" do
    # Mock the component rendering with block
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).with(context_item: @context_item).returns(mock_component)
    expects(:render).with(mock_component).yields.returns("<div>rendered with block</div>")
    
    result = context_item_preview_modal(@context_item) { "block content" }
    assert_equal "<div>rendered with block</div>", result
  end

  # context_item_preview_button tests
  test "context_item_preview_button returns nil for nil context item" do
    assert_nil context_item_preview_button(nil)
  end

  test "context_item_preview_button generates button with default text" do
    result = context_item_preview_button(@context_item)
    assert_match /Preview Test Context Item/, result
    assert_match /button/, result
    assert_match /data-action="click-&gt;context-sidebar#showPreview"/, result
    assert_match /data-context-item-id="#{@context_item.id}"/, result
  end

  test "context_item_preview_button uses custom text when provided" do
    result = context_item_preview_button(@context_item, text: "Custom Preview")
    assert_match /Custom Preview/, result
    assert_no_match /Preview Test Context Item/, result
  end

  test "context_item_preview_button truncates long titles" do
    @context_item.update!(title: "This is a very long title that should be truncated in the preview button")
    result = context_item_preview_button(@context_item)
    assert_match /Preview This is a very long title.../, result
  end

  test "context_item_preview_button merges custom options" do
    result = context_item_preview_button(@context_item, class: "custom-class", id: "preview-btn")
    assert_match /custom-class/, result
    assert_match /id="preview-btn"/, result
  end

  # context_item_card tests
  test "context_item_card returns nil for nil context item" do
    assert_nil context_item_card(nil)
  end

  test "context_item_card renders card with item details" do
    travel_to Time.zone.local(2024, 1, 15, 14, 30, 0) do
      @context_item.update!(created_at: 2.hours.ago)
      
      result = context_item_card(@context_item)
      
      # Check structure
      assert_match /<div class="bg-white overflow-hidden shadow rounded-lg/, result
      
      # Check title
      assert_match /Test Context Item/, result
      
      # Check item type badge
      assert_match /Snippet/, result
      assert_match /bg-blue-100 text-blue-800/, result
      
      # Check content preview
      assert_match /This is a test content for the context item/, result
      
      # Check timestamp
      assert_match /about 2 hours ago/, result
    end
  end

  test "context_item_card truncates long content" do
    long_content = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation."
    @context_item.update!(content: long_content)
    
    result = context_item_card(@context_item)
    
    # Should truncate to 100 characters
    assert_match /Lorem ipsum/, result
    assert_match /\.\.\./, result
    assert_no_match /quis nostrud exercitation/, result
  end

  test "context_item_card strips HTML tags from content" do
    @context_item.update!(content: "<p>HTML <strong>content</strong> with <em>tags</em></p>")
    
    result = context_item_card(@context_item)
    
    # Should strip tags
    assert_match /HTML content with tags/, result
    assert_no_match /<p>/, result
    assert_no_match /<strong>/, result
  end

  test "context_item_card includes custom CSS classes" do
    result = context_item_card(@context_item, class: "custom-card-class")
    assert_match /custom-card-class/, result
  end

  # item_type_badge_classes tests
  test "item_type_badge_classes returns correct classes for snippet" do
    assert_equal "bg-blue-100 text-blue-800", item_type_badge_classes("snippet")
  end

  test "item_type_badge_classes returns correct classes for draft" do
    assert_equal "bg-yellow-100 text-yellow-800", item_type_badge_classes("draft")
  end

  test "item_type_badge_classes returns correct classes for version" do
    assert_equal "bg-green-100 text-green-800", item_type_badge_classes("version")
  end

  test "item_type_badge_classes returns default classes for unknown type" do
    assert_equal "bg-gray-100 text-gray-800", item_type_badge_classes("unknown")
    assert_equal "bg-gray-100 text-gray-800", item_type_badge_classes("custom")
  end

  # context_item_content_type tests
  test "context_item_content_type returns Unknown for nil context item" do
    assert_equal "Unknown", context_item_content_type(nil)
  end

  test "context_item_content_type detects markdown content" do
    @context_item.update!(content: "# Markdown Header\n\nSome **bold** text")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:markdown)
    
    assert_equal "Markdown", context_item_content_type(@context_item)
  end

  test "context_item_content_type detects code content with language" do
    @context_item.update!(content: "```ruby\ndef hello\n  puts 'world'\nend\n```")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:code)
    mock_component.stubs(:code_language).returns("ruby")
    
    assert_equal "Ruby Code", context_item_content_type(@context_item)
  end

  test "context_item_content_type detects code content without language" do
    @context_item.update!(content: "function test() { return true; }")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:code)
    mock_component.stubs(:code_language).returns(nil)
    
    assert_equal "Code", context_item_content_type(@context_item)
  end

  test "context_item_content_type returns Text for plain content" do
    @context_item.update!(content: "Just plain text content")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:text)
    
    assert_equal "Text", context_item_content_type(@context_item)
  end

  # syntax_language_indicator tests
  test "syntax_language_indicator returns empty string for nil context item" do
    assert_equal "", syntax_language_indicator(nil)
  end

  test "syntax_language_indicator returns empty string for non-code content" do
    @context_item.update!(content: "Just plain text")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:text)
    
    assert_equal "", syntax_language_indicator(@context_item)
  end

  test "syntax_language_indicator returns language badge for code content" do
    @context_item.update!(content: "```python\nprint('hello')\n```")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:code)
    mock_component.stubs(:code_language).returns("python")
    
    result = syntax_language_indicator(@context_item)
    assert_match /PYTHON/, result
    assert_match /font-mono/, result
    assert_match /bg-gray-100 text-gray-800/, result
  end

  test "syntax_language_indicator returns empty for code without language" do
    @context_item.update!(content: "some code here")
    
    # Mock the component behavior
    mock_component = mock("component")
    ContextItemPreviewComponent.stubs(:new).returns(mock_component)
    mock_component.stubs(:send).with(:detect_content_type).returns(:code)
    mock_component.stubs(:code_language).returns(nil)
    
    assert_equal "", syntax_language_indicator(@context_item)
  end
end