# frozen_string_literal: true

class EditorComponent < ViewComponent::Base
  def initialize(document:, current_user:, options: {})
    @document = document
    @current_user = current_user
    @options = options
    @show_presence_indicators = options.fetch(:show_presence, true)
    @enable_collaboration = options.fetch(:enable_collaboration, false)
  end

  private

  attr_reader :document, :current_user, :options

  def editor_toolbar_items
    [
      # Text formatting
      { action: "bold", icon: "format-bold", tooltip: "Bold (⌘B)", group: "format" },
      { action: "italic", icon: "format-italic", tooltip: "Italic (⌘I)", group: "format" },
      { action: "strike", icon: "format-strikethrough", tooltip: "Strikethrough", group: "format" },
      { action: "underline", icon: "format-underline", tooltip: "Underline (⌘U)", group: "format" },
      { divider: true },

      # Structure
      { action: "heading1", icon: "format-header-1", tooltip: "Heading 1", group: "structure" },
      { action: "heading2", icon: "format-header-2", tooltip: "Heading 2", group: "structure" },
      { action: "heading3", icon: "format-header-3", tooltip: "Heading 3", group: "structure" },
      { action: "quote", icon: "format-quote-close", tooltip: "Quote", group: "structure" },
      { divider: true },

      # Lists and blocks
      { action: "bullet", icon: "format-list-bulleted", tooltip: "Bullet List", group: "lists" },
      { action: "number", icon: "format-list-numbered", tooltip: "Numbered List", group: "lists" },
      { action: "code", icon: "code-tags", tooltip: "Code Block", group: "lists" },
      { divider: true },

      # Media and links
      { action: "link", icon: "link", tooltip: "Add Link (⌘K)", group: "media" },
      { action: "attachFile", icon: "paperclip", tooltip: "Attach File", group: "media" },
      { action: "table", icon: "table", tooltip: "Insert Table", group: "media" },
      { divider: true },

      # History
      { action: "undo", icon: "undo", tooltip: "Undo (⌘Z)", group: "history" },
      { action: "redo", icon: "redo", tooltip: "Redo (⌘⇧Z)", group: "history" }
    ]
  end

  def editor_class
    base_classes = [
      "trix-editor",
      "min-h-[500px]",
      "prose",
      "prose-lg",
      "max-w-none",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-creative-primary-200",
      "focus:ring-offset-2",
      "transition-all",
      "duration-200",
      "ease-creative"
    ]

    # Creative-focused prose styling
    prose_classes = [
      "prose-headings:font-display",
      "prose-headings:font-semibold",
      "prose-headings:text-creative-neutral-900",
      "prose-h1:text-heading-xl",
      "prose-h2:text-heading-lg",
      "prose-h3:text-heading-md",
      "prose-p:text-content-base",
      "prose-p:leading-relaxed",
      "prose-a:text-creative-primary-600",
      "prose-a:no-underline",
      "prose-a:font-medium",
      "hover:prose-a:text-creative-primary-700",
      "prose-strong:text-creative-neutral-900",
      "prose-strong:font-semibold",
      "prose-code:bg-creative-neutral-100",
      "prose-code:text-creative-accent-purple",
      "prose-code:px-1.5",
      "prose-code:py-0.5",
      "prose-code:rounded",
      "prose-code:font-mono",
      "prose-code:text-sm",
      "prose-pre:bg-creative-neutral-900",
      "prose-pre:text-creative-neutral-100",
      "prose-pre:border-l-4",
      "prose-pre:border-creative-primary-500",
      "prose-blockquote:border-l-creative-secondary-500",
      "prose-blockquote:text-creative-neutral-700",
      "prose-blockquote:italic"
    ]

    # Dark mode variants
    dark_classes = [
      "dark:prose-headings:text-creative-neutral-100",
      "dark:prose-p:text-creative-neutral-300",
      "dark:prose-a:text-creative-primary-400",
      "dark:hover:prose-a:text-creative-primary-300",
      "dark:prose-strong:text-creative-neutral-100",
      "dark:prose-code:bg-creative-neutral-800",
      "dark:prose-code:text-creative-accent-amber",
      "dark:prose-blockquote:text-creative-neutral-400",
      "dark:focus:ring-creative-primary-400"
    ]

    (base_classes + prose_classes + dark_classes).join(" ")
  end

  def toolbar_class
    [
      "editor-toolbar",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "rounded-t-xl",
      "p-3",
      "flex",
      "items-center",
      "justify-between",
      "shadow-creative-sm",
      "dark:shadow-creative-dark-sm",
      "transition-colors",
      "duration-200"
    ].join(" ")
  end

  def editor_wrapper_class
    [
      "editor-wrapper",
      "card",
      "!p-0",
      "overflow-hidden",
      "shadow-creative-md",
      "dark:shadow-creative-dark-md",
      "transition-shadow",
      "duration-300",
      "hover:shadow-creative-lg",
      "dark:hover:shadow-creative-dark-lg"
    ].join(" ")
  end

  def editor_content_class
    [
      "border",
      "border-t-0",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "rounded-b-xl",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "p-6",
      "transition-colors",
      "duration-200"
    ].join(" ")
  end

  def status_bar_class
    [
      "mt-4",
      "flex",
      "items-center",
      "justify-between",
      "text-sm",
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400",
      "px-1"
    ].join(" ")
  end

  def show_presence_indicators?
    @show_presence_indicators && @enable_collaboration
  end

  def collaboration_enabled?
    @enable_collaboration
  end

  def word_count_display
    return "0 words" unless document.persisted?

    count = document.word_count
    reading_time = document.reading_time

    "#{count} words • #{reading_time} min read"
  end

  def editor_data_attributes
    attrs = {
      controller: "editor",
      "editor-document-id-value" => document.id,
      "editor-user-id-value" => current_user.id
    }

    if document.persisted?
      attrs["editor-autosave-url-value"] = url_helpers.document_path(document)
    end

    if collaboration_enabled?
      attrs["editor-collaboration-enabled-value"] = true
      attrs["editor-presence-channel-value"] = "document_#{document.id}"
    end

    attrs
  end

  private

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
