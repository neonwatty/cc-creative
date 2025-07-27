# frozen_string_literal: true

require "test_helper"

class ContextItemPreviewComponentTest < ViewComponent::TestCase
  include ActionView::Helpers::TagHelper
  def setup
    @user = users(:one)
    @document = documents(:one)
    @context_item = context_items(:code_snippet)
  end

  test "renders context item preview with basic content" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_selector "[data-controller='context-item-preview']"
    assert_selector "h3", text: @context_item.title
    assert_text @context_item.title
  end

  test "renders item type badge" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_selector ".inline-flex", text: @context_item.item_type.capitalize
  end

  test "renders close button" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_selector "button[data-action='click->context-item-preview#close']"
  end

  test "renders insert and copy buttons" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_selector "button[data-action='click->context-item-preview#insertContent']", text: "Insert"
    assert_selector "button[data-action='click->context-item-preview#copyContent']", text: "Copy"
  end

  test "includes proper data attributes" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_selector "[data-context-item-preview-id-value='#{@context_item.id}']"
    assert_selector "[data-context-item-preview-type-value='#{@context_item.item_type}']"
  end

  test "detects code content correctly" do
    code_item = context_items(:code_snippet)
    code_item.update!(content: "def hello_world\n  puts 'Hello, World!'\nend")
    
    component = ContextItemPreviewComponent.new(context_item: code_item)
    assert_equal :code, component.send(:detect_content_type)
  end

  test "detects markdown content correctly" do
    # Create a new item for markdown testing
    markdown_item = ContextItem.new(
      document: @document, 
      user: @user,
      content: "# Hello\n\nThis is **bold** text with [a link](http://example.com)",
      item_type: 'draft',
      title: 'Markdown Test'
    )
    
    component = ContextItemPreviewComponent.new(context_item: markdown_item)
    assert_equal :markdown, component.send(:detect_content_type)
  end

  test "defaults to plain text for simple content" do
    # Create a new item for plain text testing
    plain_item = ContextItem.new(
      document: @document, 
      user: @user,
      content: "This is just some plain text content without any special formatting.",
      item_type: 'draft',
      title: 'Plain Text Test'
    )
    
    component = ContextItemPreviewComponent.new(context_item: plain_item)
    assert_equal :plain_text, component.send(:detect_content_type)
  end

  test "sanitizes markdown content" do
    # Create a new item for markdown sanitization testing  
    malicious_item = ContextItem.new(
      document: @document, 
      user: @user,
      content: "# Hello\n\nThis is **bold** text\n\n<script>alert('xss')</script>",
      item_type: 'draft',
      title: 'Malicious Markdown Test',
      created_at: Time.current
    )
    
    component = ContextItemPreviewComponent.new(context_item: malicious_item)
    
    # Verify it's detected as markdown
    assert_equal :markdown, component.send(:detect_content_type)
    
    render_inline(component)
    
    # Should not contain script tags
    assert_no_selector "script"
    # Should contain sanitized markdown
    assert_selector "h1", text: "Hello"
    assert_selector "strong", text: "bold"
  end

  test "prepares code content with language detection" do
    ruby_item = context_items(:code_snippet)
    ruby_item.update!(content: "```ruby\ndef hello\n  puts 'world'\nend\n```")
    
    component = ContextItemPreviewComponent.new(context_item: ruby_item)
    # The detect_content_type should return :code for this content
    assert_equal :code, component.send(:detect_content_type)
    assert_equal "ruby", component.code_language
  end

  test "includes metadata description when present" do
    @context_item.update!(metadata: { description: "This is a helpful description" })
    
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_text "This is a helpful description"
  end

  test "generates unique modal id" do
    component = ContextItemPreviewComponent.new(context_item: @context_item)
    expected_id = "context-item-preview-#{@context_item.id}"
    
    assert_equal expected_id, component.modal_id
  end

  test "renders with custom action buttons via slots" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item)) do |component|
      component.with_primary_action do
        content_tag(:button, "Custom Action", class: "custom-btn")
      end
    end
    
    assert_selector "button.custom-btn", text: "Custom Action"
  end

  test "does not render when context_item is nil" do
    component = ContextItemPreviewComponent.new(context_item: nil)
    assert_not component.render?
  end

  test "applies correct badge class for different item types" do
    snippet_item = context_items(:code_snippet)
    snippet_item.update!(item_type: 'snippet')
    component = ContextItemPreviewComponent.new(context_item: snippet_item)
    assert_includes component.item_type_badge_class, 'bg-blue-100'

    draft_item = context_items(:code_snippet)
    draft_item.update!(item_type: 'draft')
    component = ContextItemPreviewComponent.new(context_item: draft_item)
    assert_includes component.item_type_badge_class, 'bg-yellow-100'

    version_item = context_items(:code_snippet)
    version_item.update!(item_type: 'version')
    component = ContextItemPreviewComponent.new(context_item: version_item)
    assert_includes component.item_type_badge_class, 'bg-green-100'
  end

  test "includes accessibility attributes" do
    render_inline(ContextItemPreviewComponent.new(context_item: @context_item))
    
    assert_selector "[aria-hidden='true']" # backdrop
    assert_selector "button[aria-label='Close modal']"
    assert_selector "h3#modal-title"
  end
end