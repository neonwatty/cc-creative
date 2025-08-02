# frozen_string_literal: true

class AIReviewPanelComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(document_id:, user_id:, options: {})
    @document_id = document_id
    @user_id = user_id
    @options = options
    @position = options.fetch(:position, "right") # left, right, bottom, floating
    @size = options.fetch(:size, "medium") # small, medium, large
    @style = options.fetch(:style, "modern") # modern, minimal, compact
    @auto_refresh = options.fetch(:auto_refresh, true)
    @show_filters = options.fetch(:show_filters, true)
    @collapsible = options.fetch(:collapsible, true)
    @max_suggestions = options.fetch(:max_suggestions, 10)
    @enable_ai_chat = options.fetch(:enable_ai_chat, true)
  end

  private

  attr_reader :document_id, :user_id, :options, :position, :size, :style,
              :auto_refresh, :show_filters, :collapsible, :max_suggestions, :enable_ai_chat

  def panel_class
    base_classes = [
      "ai-review-panel",
      "flex",
      "flex-col",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "shadow-creative-xl",
      "transition-all",
      "duration-400",
      "ease-creative-in-out",
      "z-40",
      "overflow-hidden"
    ]

    # Position variants
    case position
    when "left"
      base_classes += [
        "fixed",
        "left-4",
        "top-20",
        "bottom-4",
        "w-96",
        "rounded-2xl"
      ]
    when "right"
      base_classes += [
        "fixed",
        "right-4",
        "top-20",
        "bottom-4",
        "w-96",
        "rounded-2xl"
      ]
    when "bottom"
      base_classes += [
        "fixed",
        "bottom-4",
        "left-4",
        "right-4",
        "h-80",
        "rounded-xl"
      ]
    when "floating"
      base_classes += [
        "absolute",
        "w-96",
        "h-96",
        "rounded-2xl",
        "cursor-move",
        "resize"
      ]
    else
      base_classes += ["relative", "rounded-xl"]
    end

    # Size variants
    case size
    when "small"
      case position
      when "left", "right"
        base_classes += ["w-80"]
      when "bottom"
        base_classes += ["h-64"]
      when "floating"
        base_classes += ["w-80", "h-80"]
      end
    when "large"
      case position
      when "left", "right"
        base_classes += ["w-[28rem]"]
      when "bottom"
        base_classes += ["h-96"]
      when "floating"
        base_classes += ["w-[32rem]", "h-[32rem]"]
      end
    end

    # Style variants
    case style
    when "minimal"
      base_classes += [
        "bg-white/95",
        "dark:bg-creative-neutral-800/95",
        "backdrop-blur-lg",
        "border-creative-neutral-200/70",
        "dark:border-creative-neutral-700/70"
      ]
    when "compact"
      base_classes += [
        "bg-creative-neutral-50",
        "dark:bg-creative-neutral-900",
        "border-creative-neutral-300",
        "dark:border-creative-neutral-600"
      ]
    end

    base_classes.join(" ")
  end

  def header_class
    [
      "ai-review-header",
      "flex",
      "items-center",
      "justify-between",
      "p-4",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-gradient-to-r",
      "from-creative-primary-50",
      "to-creative-secondary-50",
      "dark:from-creative-neutral-800",
      "dark:to-creative-neutral-700"
    ].join(" ")
  end

  def title_class
    [
      "text-lg",
      "font-bold",
      "text-creative-neutral-900",
      "dark:text-creative-neutral-100",
      "flex",
      "items-center",
      "space-x-2"
    ].join(" ")
  end

  def status_class(status)
    base_classes = [
      "status-indicator",
      "px-2",
      "py-1",
      "text-xs",
      "font-semibold",
      "rounded-full",
      "flex",
      "items-center",
      "space-x-1"
    ]

    case status
    when "analyzing"
      base_classes += [
        "bg-creative-primary-100",
        "text-creative-primary-800",
        "dark:bg-creative-primary-900/30",
        "dark:text-creative-primary-300"
      ]
    when "complete"
      base_classes += [
        "bg-creative-secondary-100",
        "text-creative-secondary-800",
        "dark:bg-creative-secondary-900/30",
        "dark:text-creative-secondary-300"
      ]
    when "error"
      base_classes += [
        "bg-creative-accent-rose/10",
        "text-red-700",
        "dark:bg-red-900/30",
        "dark:text-red-300"
      ]
    else
      base_classes += [
        "bg-creative-neutral-100",
        "text-creative-neutral-700",
        "dark:bg-creative-neutral-700",
        "dark:text-creative-neutral-300"
      ]
    end

    base_classes.join(" ")
  end

  def filters_class
    [
      "ai-review-filters",
      "flex",
      "items-center",
      "justify-between",
      "p-3",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-750",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "space-x-2"
    ].join(" ")
  end

  def filter_button_class(active = false)
    base_classes = [
      "filter-btn",
      "px-3",
      "py-1",
      "text-xs",
      "font-medium",
      "rounded-lg",
      "transition-all",
      "duration-200",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-creative-primary-500",
      "focus:ring-offset-2"
    ]

    if active
      base_classes += [
        "bg-creative-primary-600",
        "text-white",
        "shadow-creative-sm"
      ]
    else
      base_classes += [
        "bg-white",
        "dark:bg-creative-neutral-700",
        "text-creative-neutral-700",
        "dark:text-creative-neutral-300",
        "border",
        "border-creative-neutral-300",
        "dark:border-creative-neutral-600",
        "hover:bg-creative-neutral-100",
        "dark:hover:bg-creative-neutral-600"
      ]
    end

    base_classes.join(" ")
  end

  def content_class
    [
      "ai-review-content",
      "flex-1",
      "overflow-hidden",
      "flex",
      "flex-col"
    ].join(" ")
  end

  def suggestions_list_class
    [
      "suggestions-list",
      "flex-1",
      "overflow-y-auto",
      "scrollbar-thin",
      "scrollbar-thumb-creative-neutral-300",
      "dark:scrollbar-thumb-creative-neutral-600",
      "scrollbar-track-transparent",
      "divide-y",
      "divide-creative-neutral-200",
      "dark:divide-creative-neutral-700"
    ].join(" ")
  end

  def suggestion_class(severity)
    base_classes = [
      "suggestion-item",
      "p-4",
      "hover:bg-creative-neutral-50",
      "dark:hover:bg-creative-neutral-750",
      "transition-colors",
      "duration-200",
      "cursor-pointer",
      "group"
    ]

    # Add severity-specific styling
    case severity
    when "critical"
      base_classes += ["border-l-4", "border-red-500"]
    when "warning"
      base_classes += ["border-l-4", "border-creative-accent-amber"]
    when "info"
      base_classes += ["border-l-4", "border-creative-primary-500"]
    when "suggestion"
      base_classes += ["border-l-4", "border-creative-secondary-500"]
    end

    base_classes.join(" ")
  end

  def severity_icon_class(severity)
    base_classes = [
      "severity-icon",
      "w-5",
      "h-5",
      "flex-shrink-0"
    ]

    case severity
    when "critical"
      base_classes += ["text-red-500"]
    when "warning"
      base_classes += ["text-creative-accent-amber"]
    when "info"
      base_classes += ["text-creative-primary-500"]
    when "suggestion"
      base_classes += ["text-creative-secondary-500"]
    end

    base_classes.join(" ")
  end

  def suggestion_content_class
    [
      "suggestion-content",
      "flex-1",
      "ml-3"
    ].join(" ")
  end

  def suggestion_title_class
    [
      "suggestion-title",
      "text-sm",
      "font-semibold",
      "text-creative-neutral-900",
      "dark:text-creative-neutral-100",
      "group-hover:text-creative-primary-600",
      "dark:group-hover:text-creative-primary-400",
      "transition-colors",
      "duration-200"
    ].join(" ")
  end

  def suggestion_description_class
    [
      "suggestion-description",
      "text-sm",
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400",
      "mt-1",
      "line-clamp-2"
    ].join(" ")
  end

  def suggestion_meta_class
    [
      "suggestion-meta",
      "flex",
      "items-center",
      "justify-between",
      "mt-2",
      "text-xs",
      "text-creative-neutral-500",
      "dark:text-creative-neutral-500"
    ].join(" ")
  end

  def action_button_class(variant = "primary")
    base_classes = [
      "action-btn",
      "px-2",
      "py-1",
      "text-xs",
      "font-medium",
      "rounded",
      "transition-all",
      "duration-200",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-offset-1"
    ]

    case variant
    when "primary"
      base_classes += [
        "bg-creative-primary-600",
        "text-white",
        "hover:bg-creative-primary-700",
        "focus:ring-creative-primary-500"
      ]
    when "secondary"
      base_classes += [
        "bg-creative-neutral-200",
        "dark:bg-creative-neutral-600",
        "text-creative-neutral-700",
        "dark:text-creative-neutral-300",
        "hover:bg-creative-neutral-300",
        "dark:hover:bg-creative-neutral-500",
        "focus:ring-creative-neutral-500"
      ]
    when "success"
      base_classes += [
        "bg-creative-secondary-600",
        "text-white",
        "hover:bg-creative-secondary-700",
        "focus:ring-creative-secondary-500"
      ]
    when "danger"
      base_classes += [
        "bg-red-600",
        "text-white",
        "hover:bg-red-700",
        "focus:ring-red-500"
      ]
    end

    base_classes.join(" ")
  end

  def chat_section_class
    [
      "ai-chat-section",
      "border-t",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800"
    ].join(" ")
  end

  def chat_input_class
    [
      "chat-input",
      "w-full",
      "px-3",
      "py-2",
      "text-sm",
      "border-0",
      "bg-white",
      "dark:bg-creative-neutral-700",
      "text-creative-neutral-900",
      "dark:text-creative-neutral-100",
      "placeholder-creative-neutral-500",
      "dark:placeholder-creative-neutral-400",
      "focus:outline-none",
      "focus:ring-0",
      "resize-none"
    ].join(" ")
  end

  def empty_state_class
    [
      "empty-state",
      "flex",
      "flex-col",
      "items-center",
      "justify-center",
      "py-12",
      "text-center",
      "space-y-4"
    ].join(" ")
  end

  def loading_state_class
    [
      "loading-state",
      "flex",
      "flex-col",
      "items-center",
      "justify-center",
      "py-8",
      "text-center",
      "space-y-3"
    ].join(" ")
  end

  def panel_data_attributes
    {
      controller: "ai-review-panel",
      "ai_review_panel_document_id_value": document_id,
      "ai_review_panel_user_id_value": user_id,
      "ai_review_panel_position_value": position,
      "ai_review_panel_auto_refresh_value": auto_refresh,
      "ai_review_panel_max_suggestions_value": max_suggestions,
      "ai_review_panel_enable_ai_chat_value": enable_ai_chat,
      action: [
        "ai-review:suggestion-received->ai-review-panel#handleNewSuggestion",
        "ai-review:analysis-complete->ai-review-panel#handleAnalysisComplete",
        "ai-review:status-changed->ai-review-panel#handleStatusChange"
      ].join(" ")
    }
  end

  def sample_suggestions
    [
      {
        id: 1,
        severity: "critical",
        title: "Memory Leak Detected",
        description: "Event listeners are not being properly cleaned up in widget destruction, causing memory accumulation.",
        line: 45,
        file: "widget_container.js",
        timestamp: 2.minutes.ago,
        actions: ["Fix Automatically", "Show Details", "Ignore"]
      },
      {
        id: 2,
        severity: "warning",
        title: "Performance Optimization",
        description: "Consider debouncing the resize handler to improve performance during window resizing.",
        line: 127,
        file: "widget_container.js",
        timestamp: 5.minutes.ago,
        actions: ["Apply Fix", "Learn More"]
      },
      {
        id: 3,
        severity: "info",
        title: "Code Style",
        description: "Consider using const instead of let for variables that don't get reassigned.",
        line: 23,
        file: "widget_framework.js",
        timestamp: 8.minutes.ago,
        actions: ["Fix", "Ignore"]
      },
      {
        id: 4,
        severity: "suggestion",
        title: "Enhancement Opportunity",
        description: "You could add keyboard shortcuts for widget management to improve user experience.",
        line: nil,
        file: "general",
        timestamp: 10.minutes.ago,
        actions: ["Implement", "Later"]
      }
    ]
  end

  def filter_options
    [
      { id: "all", label: "All", count: 12 },
      { id: "critical", label: "Critical", count: 1 },
      { id: "warning", label: "Warning", count: 3 },
      { id: "info", label: "Info", count: 5 },
      { id: "suggestion", label: "Suggestions", count: 3 }
    ]
  end

  def get_severity_icon(severity)
    case severity
    when "critical"
      "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833-.192 2.5 1.732 2.5z"
    when "warning"
      "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833-.192 2.5 1.732 2.5z"
    when "info"
      "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    when "suggestion"
      "M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
    else
      "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    end
  end

  def format_timestamp(time)
    time_ago_in_words(time) + " ago"
  end

  def collapse_button_class
    [
      "collapse-btn",
      "w-6",
      "h-6",
      "flex",
      "items-center",
      "justify-center",
      "text-creative-neutral-500",
      "dark:text-creative-neutral-400",
      "hover:text-creative-neutral-700",
      "dark:hover:text-creative-neutral-300",
      "transition-colors",
      "duration-200",
      "cursor-pointer",
      "rounded",
      "hover:bg-creative-neutral-100",
      "dark:hover:bg-creative-neutral-700"
    ].join(" ")
  end
end