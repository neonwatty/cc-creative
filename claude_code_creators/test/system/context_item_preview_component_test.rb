# frozen_string_literal: true

require "application_system_test_case"

class ContextItemPreviewComponentSystemTest < ApplicationSystemTestCase
  def setup
    @user = users(:john)
    @document = documents(:one)
    @context_item = context_items(:code_snippet)

    # Create a test page that includes the component
    visit_test_page_with_component
  end

  test "opens and closes modal" do
    # Modal should be hidden initially
    assert_no_selector ".context-item-preview-modal:not(.hidden)"

    # Trigger modal open (this would normally be done by parent component)
    show_modal

    # Modal should be visible
    assert_selector ".context-item-preview-modal:not(.hidden)"
    assert_text @context_item.title

    # Close via close button
    click_button "Close modal"

    # Modal should be hidden again
    assert_selector ".context-item-preview-modal.hidden"
  end

  test "closes modal with escape key" do
    show_modal
    assert_selector ".context-item-preview-modal:not(.hidden)"

    # Press escape key
    find("body").send_keys(:escape)

    # Modal should be hidden
    assert_selector ".context-item-preview-modal.hidden"
  end

  test "closes modal when clicking backdrop" do
    show_modal
    assert_selector ".context-item-preview-modal:not(.hidden)"

    # Click backdrop (not the modal panel)
    find("[data-context-item-preview-target='backdrop']").click

    # Modal should be hidden
    assert_selector ".context-item-preview-modal.hidden"
  end

  test "copy button functionality" do
    show_modal

    # Mock clipboard API
    page.evaluate_script(<<~JS)
      navigator.clipboard = {
        writeText: function(text) {
          window.lastCopiedText = text;
          return Promise.resolve();
        }
      };
    JS

    click_button "Copy"

    # Check that content was "copied"
    copied_text = page.evaluate_script("window.lastCopiedText")
    assert_includes copied_text, @context_item.content

    # Check feedback
    assert_text "Copied!"
  end

  test "insert button dispatches custom event" do
    show_modal

    # Listen for the custom event
    page.evaluate_script(<<~JS)
      window.insertEventFired = false;
      document.addEventListener('context-item-preview:insert', function(event) {
        window.insertEventFired = true;
        window.insertEventDetail = event.detail;
      });
    JS

    click_button "Insert"

    # Check that event was fired
    event_fired = page.evaluate_script("window.insertEventFired")
    assert event_fired

    # Check event detail
    event_detail = page.evaluate_script("window.insertEventDetail")
    assert_equal @context_item.id, event_detail["contextItemId"]
    assert_equal @context_item.item_type, event_detail["itemType"]
  end

  test "keyboard shortcut cmd+shift+i triggers insert" do
    show_modal

    # Listen for the custom event
    page.evaluate_script(<<~JS)
      window.insertEventFired = false;
      document.addEventListener('context-item-preview:insert', function(event) {
        window.insertEventFired = true;
      });
    JS

    # Simulate Cmd+Shift+I (or Ctrl+Shift+I on non-Mac)
    find("body").send_keys([ :command, :shift, "i" ])

    # Check that event was fired
    event_fired = page.evaluate_script("window.insertEventFired")
    assert event_fired

    # Modal should be closed after insert
    assert_selector ".context-item-preview-modal.hidden"
  end

  test "focus management" do
    show_modal

    # Modal panel should be focused
    assert_equal "DIV", evaluate_script("document.activeElement.tagName")

    # Tab through focusable elements
    find("body").send_keys(:tab)
    assert_equal "BUTTON", evaluate_script("document.activeElement.tagName")
  end

  test "displays content based on type detection" do
    # Test code content
    @context_item.update!(content: "def hello\n  puts 'world'\nend")
    visit_test_page_with_component
    show_modal

    assert_selector ".code-content"
    assert_selector "pre code"

    # Test markdown content
    @context_item.update!(content: "# Hello\n\nThis is **bold** text")
    visit_test_page_with_component
    show_modal

    assert_selector ".markdown-content"
    assert_selector "h1", text: "Hello"
    assert_selector "strong", text: "bold"
  end

  test "shows language badge for code content" do
    @context_item.update!(content: "```ruby\ndef hello\n  puts 'world'\nend\n```")
    visit_test_page_with_component
    show_modal

    assert_text "ruby"
  end

  test "displays metadata description when present" do
    @context_item.update!(metadata: { description: "This explains the snippet" })
    visit_test_page_with_component
    show_modal

    assert_text "This explains the snippet"
  end

  test "syntax highlighting preparation" do
    @context_item.update!(content: "def hello\n  puts 'world'\nend")
    visit_test_page_with_component
    show_modal

    # Check that code blocks are marked for syntax highlighting or have Prism classes
    assert_selector "code.syntax-ready, code[class*='language-']"
  end

  test "content formatting for different types" do
    # Test code content formatting
    @context_item.update!(content: "console.log('hello')", item_type: "snippet")
    visit_test_page_with_component
    show_modal

    # Listen for formatted content
    page.evaluate_script(<<~JS)
      window.formattedContent = null;
      document.addEventListener('context-item-preview:insert', function(event) {
        window.formattedContent = event.detail.content;
      });
    JS

    click_button "Insert"

    formatted_content = page.evaluate_script("window.formattedContent")
    assert_includes formatted_content, "```"
    assert_includes formatted_content, "console.log('hello')"
  end

  private

  def visit_test_page_with_component
    # Create a simple test page that includes our component
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <script src="https://cdn.tailwindcss.com"></script>
          <script type="module">
            import { Application } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"
            window.Stimulus = Application.start()
      #{'      '}
            import ContextItemPreviewController from "/assets/controllers/context_item_preview_controller.js"
            Stimulus.register("context-item-preview", ContextItemPreviewController)
          </script>
        </head>
        <body>
          <div id="test-container">
            #{render_component_html}
          </div>
          <button id="show-modal" onclick="showModal()">Show Modal</button>
      #{'    '}
          <script>
            function showModal() {
              const modal = document.querySelector('.context-item-preview-modal');
              modal.classList.remove('hidden');
            }
          </script>
        </body>
      </html>
    HTML

    # Write to a temporary file and visit
    File.write(Rails.root.join("tmp", "test_preview.html"), html_content)
    visit "/tmp/test_preview.html"
  rescue StandardError
    # Fallback: use a basic Rails view for testing
    visit root_path
    page.execute_script(<<~JS)
      document.body.innerHTML = `
        #{render_component_html.gsub('`', '\`')}
        <button id="show-modal" onclick="document.querySelector('.context-item-preview-modal').classList.remove('hidden')">Show Modal</button>
      `;
    JS
  end

  def render_component_html
    ApplicationController.render(
      ContextItemPreviewComponent.new(context_item: @context_item),
      layout: false
    )
  end

  def show_modal
    page.execute_script("document.querySelector('.context-item-preview-modal').classList.remove('hidden')")
    # Wait for modal to be visible
    assert_selector ".context-item-preview-modal:not(.hidden)"
  end
end
