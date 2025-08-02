# frozen_string_literal: true

require "test_helper"

class EditorComponentTest < ViewComponent::TestCase
  def test_component_renders_something_useful
    document = documents(:document_one)
    user = users(:one)

    rendered = render_inline(EditorComponent.new(document: document, current_user: user))

    # Check that the editor wrapper is rendered
    assert_selector ".editor-wrapper"

    # Check that the toolbar is rendered with buttons
    assert_selector ".editor-toolbar"
    assert_selector "button[data-trix-action='bold']"
    assert_selector "button[data-trix-action='italic']"

    # Check that word count display is present
    assert_selector "[data-editor-target='wordCount']"

    # Check that status indicators are present
    assert_selector "[data-editor-target='status']"
    assert_selector "[data-editor-target='lastSaved']"
  end
end
