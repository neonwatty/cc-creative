# frozen_string_literal: true

class EditorComponent < ViewComponent::Base
  def initialize(document:, current_user:)
    @document = document
    @current_user = current_user
  end

  private

  attr_reader :document, :current_user

  def editor_toolbar_items
    [
      { action: "bold", icon: "format-bold", tooltip: "Bold (Cmd+B)" },
      { action: "italic", icon: "format-italic", tooltip: "Italic (Cmd+I)" },
      { action: "strike", icon: "format-strikethrough", tooltip: "Strikethrough" },
      { action: "link", icon: "link", tooltip: "Add Link (Cmd+K)" },
      { divider: true },
      { action: "heading", icon: "format-header", tooltip: "Heading" },
      { action: "quote", icon: "format-quote-close", tooltip: "Quote" },
      { action: "code", icon: "code-tags", tooltip: "Code Block" },
      { action: "bullet", icon: "format-list-bulleted", tooltip: "Bullet List" },
      { action: "number", icon: "format-list-numbered", tooltip: "Numbered List" },
      { divider: true },
      { action: "attachFile", icon: "paperclip", tooltip: "Attach File" },
      { action: "undo", icon: "undo", tooltip: "Undo (Cmd+Z)" },
      { action: "redo", icon: "redo", tooltip: "Redo (Cmd+Shift+Z)" }
    ]
  end

  def editor_class
    "trix-editor min-h-[400px] prose prose-lg max-w-none focus:outline-none " \
    "prose-headings:font-bold prose-a:text-blue-600 prose-code:bg-gray-100 " \
    "prose-pre:bg-gray-900 prose-pre:text-gray-100"
  end
end
