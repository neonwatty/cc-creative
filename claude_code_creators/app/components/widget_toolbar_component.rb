# frozen_string_literal: true

class WidgetToolbarComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(document_id:, user_id:, options: {})
    @document_id = document_id
    @user_id = user_id
    @options = options
    @position = options.fetch(:position, "top") # top, bottom, left, right, floating
    @size = options.fetch(:size, "medium") # small, medium, large
    @style = options.fetch(:style, "modern") # modern, minimal, compact
    @show_labels = options.fetch(:show_labels, true)
    @show_shortcuts = options.fetch(:show_shortcuts, false)
    @enable_grouping = options.fetch(:enable_grouping, true)
    @auto_hide = options.fetch(:auto_hide, false)
    @collapsible = options.fetch(:collapsible, true)
  end

  private

  attr_reader :document_id, :user_id, :options, :position, :size, :style,
              :show_labels, :show_shortcuts, :enable_grouping, :auto_hide, :collapsible

  def toolbar_class
    base_classes = [
      "widget-toolbar",
      "flex",
      "items-center",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "shadow-creative-lg",
      "transition-all",
      "duration-300",
      "ease-creative-in-out",
      "z-50",
      "backdrop-blur-sm"
    ]

    # Position variants
    case position
    when "top"
      base_classes += [
        "fixed",
        "top-4",
        "left-1/2",
        "transform",
        "-translate-x-1/2",
        "rounded-full"
      ]
    when "bottom"
      base_classes += [
        "fixed",
        "bottom-4",
        "left-1/2",
        "transform",
        "-translate-x-1/2",
        "rounded-full"
      ]
    when "left"
      base_classes += [
        "fixed",
        "left-4",
        "top-1/2",
        "transform",
        "-translate-y-1/2",
        "flex-col",
        "rounded-2xl"
      ]
    when "right"
      base_classes += [
        "fixed",
        "right-4",
        "top-1/2",
        "transform",
        "-translate-y-1/2",
        "flex-col",
        "rounded-2xl"
      ]
    when "floating"
      base_classes += [
        "absolute",
        "rounded-2xl",
        "cursor-move"
      ]
    else
      base_classes += ["relative", "rounded-lg"]
    end

    # Size variants
    case size
    when "small"
      base_classes += ["p-2"]
    when "large"
      base_classes += ["p-4"]
    else
      base_classes += ["p-3"]
    end

    # Style variants
    case style
    when "minimal"
      base_classes += [
        "bg-white/90",
        "dark:bg-creative-neutral-800/90",
        "backdrop-blur-md",
        "border-creative-neutral-200/60",
        "dark:border-creative-neutral-700/60",
        "shadow-creative-md"
      ]
    when "compact"
      base_classes += [
        "bg-creative-neutral-900",
        "dark:bg-creative-neutral-100",
        "border-creative-neutral-700",
        "dark:border-creative-neutral-300",
        "shadow-creative-dark-md"
      ]
    end

    # Auto-hide behavior
    if auto_hide
      base_classes += [
        "opacity-30",
        "hover:opacity-100",
        "focus-within:opacity-100"
      ]
    end

    base_classes.join(" ")
  end

  def toolbar_section_class
    base_classes = [
      "toolbar-section",
      "flex",
      "items-center"
    ]

    if position == "left" || position == "right"
      base_classes += ["flex-col", "space-y-2"]
    else
      base_classes += ["space-x-2"]
    end

    if enable_grouping
      base_classes += [
        "border-r",
        "border-gray-200",
        "dark:border-gray-700",
        "pr-3",
        "mr-3",
        "last:border-r-0",
        "last:pr-0",
        "last:mr-0"
      ]
    end

    base_classes.join(" ")
  end

  def button_class(variant = "default", active = false)
    base_classes = [
      "toolbar-btn",
      "relative",
      "flex",
      "items-center",
      "justify-center",
      "transition-all",
      "duration-200",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-blue-500",
      "focus:ring-offset-2",
      "dark:focus:ring-offset-gray-800"
    ]

    # Size variants
    case size
    when "small"
      base_classes += ["w-8", "h-8", "text-sm"]
    when "large"
      base_classes += ["w-12", "h-12", "text-base"]
    else
      base_classes += ["w-10", "h-10", "text-sm"]
    end

    # Label padding
    if show_labels && (position == "top" || position == "bottom")
      base_classes += ["px-3", "space-x-2", "w-auto"]
    else
      base_classes += ["rounded-lg"]
    end

    # Style variants
    case style
    when "minimal"
      if active
        base_classes += [
          "bg-blue-100",
          "dark:bg-blue-900/50",
          "text-blue-600",
          "dark:text-blue-400"
        ]
      else
        base_classes += [
          "text-gray-600",
          "dark:text-gray-400",
          "hover:bg-gray-100",
          "dark:hover:bg-gray-700"
        ]
      end
    when "compact"
      if active
        base_classes += [
          "bg-white",
          "dark:bg-gray-800",
          "text-gray-900",
          "dark:text-gray-100"
        ]
      else
        base_classes += [
          "text-white",
          "dark:text-gray-800",
          "hover:bg-white/20",
          "dark:hover:bg-gray-800/20"
        ]
      end
    else # modern
      if active
        base_classes += [
          "bg-blue-600",
          "text-white",
          "shadow-lg",
          "scale-105"
        ]
      else
        base_classes += [
          "text-gray-700",
          "dark:text-gray-300",
          "hover:bg-gray-100",
          "dark:hover:bg-gray-700",
          "hover:scale-105"
        ]
      end
    end

    # Variant-specific styles
    case variant
    when "primary"
      base_classes += [
        "bg-blue-600",
        "text-white",
        "hover:bg-blue-700",
        "shadow-lg"
      ]
    when "success"
      base_classes += [
        "bg-green-600",
        "text-white",
        "hover:bg-green-700"
      ]
    when "warning"
      base_classes += [
        "bg-yellow-600",
        "text-white",
        "hover:bg-yellow-700"
      ]
    when "danger"
      base_classes += [
        "bg-red-600",
        "text-white",
        "hover:bg-red-700"
      ]
    end

    base_classes.join(" ")
  end

  def dropdown_class
    [
      "dropdown-menu",
      "absolute",
      "mt-2",
      "py-2",
      "w-48",
      "bg-white",
      "dark:bg-gray-800",
      "border",
      "border-gray-200",
      "dark:border-gray-700",
      "rounded-lg",
      "shadow-xl",
      "z-50",
      "opacity-0",
      "invisible",
      "transform",
      "scale-95",
      "transition-all",
      "duration-200",
      "origin-top"
    ].join(" ")
  end

  def dropdown_visible_class
    [
      "opacity-100",
      "visible",
      "scale-100"
    ].join(" ")
  end

  def dropdown_item_class
    [
      "dropdown-item",
      "flex",
      "items-center",
      "space-x-3",
      "px-4",
      "py-2",
      "text-sm",
      "text-gray-700",
      "dark:text-gray-300",
      "hover:bg-gray-100",
      "dark:hover:bg-gray-700",
      "transition-colors",
      "duration-150",
      "cursor-pointer"
    ].join(" ")
  end

  def separator_class
    [
      "toolbar-separator",
      "w-px",
      "h-6",
      "bg-gray-300",
      "dark:bg-gray-600",
      "mx-2"
    ].join(" ")
  end

  def badge_class
    [
      "badge",
      "absolute",
      "-top-1",
      "-right-1",
      "w-5",
      "h-5",
      "bg-red-500",
      "text-white",
      "text-xs",
      "font-bold",
      "rounded-full",
      "flex",
      "items-center",
      "justify-center",
      "animate-pulse"
    ].join(" ")
  end

  def tooltip_class
    [
      "tooltip",
      "absolute",
      "px-2",
      "py-1",
      "text-xs",
      "font-medium",
      "text-white",
      "bg-gray-900",
      "dark:bg-gray-700",
      "rounded",
      "shadow-lg",
      "opacity-0",
      "invisible",
      "transition-all",
      "duration-200",
      "pointer-events-none",
      "whitespace-nowrap",
      "z-50"
    ].join(" ")
  end

  def tooltip_position_class
    case position
    when "top"
      "bottom-full mb-2 left-1/2 transform -translate-x-1/2"
    when "bottom"
      "top-full mt-2 left-1/2 transform -translate-x-1/2"
    when "left"
      "right-full mr-2 top-1/2 transform -translate-y-1/2"
    when "right"
      "left-full ml-2 top-1/2 transform -translate-y-1/2"
    else
      "bottom-full mb-2 left-1/2 transform -translate-x-1/2"
    end
  end

  def collapse_button_class
    base_classes = [
      "collapse-btn",
      "w-6",
      "h-6",
      "flex",
      "items-center",
      "justify-center",
      "text-gray-500",
      "dark:text-gray-400",
      "hover:text-gray-700",
      "dark:hover:text-gray-300",
      "transition-colors",
      "duration-200",
      "cursor-pointer"
    ]

    if position == "left" || position == "right"
      base_classes += ["mt-2"]
    else
      base_classes += ["ml-2"]
    end

    base_classes.join(" ")
  end

  def toolbar_data_attributes
    {
      controller: "widget-toolbar",
      "widget_toolbar_document_id_value": document_id,
      "widget_toolbar_user_id_value": user_id,
      "widget_toolbar_position_value": position,
      "widget_toolbar_size_value": size,
      "widget_toolbar_style_value": style,
      "widget_toolbar_show_labels_value": show_labels,
      "widget_toolbar_show_shortcuts_value": show_shortcuts,
      "widget_toolbar_auto_hide_value": auto_hide,
      "widget_toolbar_collapsible_value": collapsible,
      action: [
        "mouseleave->widget-toolbar#handleMouseLeave",
        "keydown->widget-toolbar#handleKeydown"
      ].join(" ")
    }
  end

  def main_actions
    [
      {
        id: "add",
        icon: "plus",
        label: "Add Widget",
        tooltip: "Create a new widget",
        shortcut: "⌘N",
        action: "click->widget-toolbar#showAddWidget",
        variant: "primary"
      },
      {
        id: "marketplace",
        icon: "store",
        label: "Marketplace",
        tooltip: "Browse plugin marketplace",
        shortcut: "⌘M",
        action: "click->widget-toolbar#openMarketplace"
      },
      {
        id: "layout",
        icon: "layout",
        label: "Layout",
        tooltip: "Change layout mode",
        action: "click->widget-toolbar#toggleLayout",
        dropdown: layout_options
      }
    ]
  end

  def widget_actions
    [
      {
        id: "select-all",
        icon: "select-all",
        label: "Select All",
        tooltip: "Select all widgets",
        shortcut: "⌘A",
        action: "click->widget-toolbar#selectAllWidgets"
      },
      {
        id: "duplicate",
        icon: "copy",
        label: "Duplicate",
        tooltip: "Duplicate selected widgets",
        shortcut: "⌘D",
        action: "click->widget-toolbar#duplicateSelected",
        disabled_when_empty: true
      },
      {
        id: "delete",
        icon: "trash",
        label: "Delete",
        tooltip: "Delete selected widgets",
        shortcut: "Del",
        action: "click->widget-toolbar#deleteSelected",
        variant: "danger",
        disabled_when_empty: true
      }
    ]
  end

  def view_actions
    [
      {
        id: "zoom-in",
        icon: "zoom-in",
        label: "Zoom In",
        tooltip: "Zoom in",
        shortcut: "⌘+",
        action: "click->widget-toolbar#zoomIn"
      },
      {
        id: "zoom-out",
        icon: "zoom-out",
        label: "Zoom Out",
        tooltip: "Zoom out",
        shortcut: "⌘-",
        action: "click->widget-toolbar#zoomOut"
      },
      {
        id: "fit-to-screen",
        icon: "maximize",
        label: "Fit to Screen",
        tooltip: "Fit all widgets to screen",
        action: "click->widget-toolbar#fitToScreen"
      }
    ]
  end

  def settings_actions
    [
      {
        id: "preferences",
        icon: "settings",
        label: "Preferences",
        tooltip: "Widget preferences",
        action: "click->widget-toolbar#showPreferences"
      },
      {
        id: "save",
        icon: "save",
        label: "Save",
        tooltip: "Save current layout",
        shortcut: "⌘S",
        action: "click->widget-toolbar#saveLayout"
      },
      {
        id: "reset",
        icon: "refresh",
        label: "Reset",
        tooltip: "Reset to default layout",
        action: "click->widget-toolbar#resetLayout",
        variant: "warning"
      }
    ]
  end

  def layout_options
    [
      {
        id: "grid",
        label: "Grid Layout",
        icon: "grid",
        action: "click->widget-toolbar#setLayoutMode",
        data: { mode: "grid" }
      },
      {
        id: "column",
        label: "Column Layout", 
        icon: "columns",
        action: "click->widget-toolbar#setLayoutMode",
        data: { mode: "column" }
      },
      {
        id: "row",
        label: "Row Layout",
        icon: "rows",
        action: "click->widget-toolbar#setLayoutMode",
        data: { mode: "row" }
      }
    ]
  end

  def get_icon_svg(icon_name)
    case icon_name
    when "plus"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>'
    when "store"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>'
    when "layout"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>'
    when "select-all"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>'
    when "copy"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>'
    when "trash"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>'
    when "zoom-in"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>'
    when "zoom-out"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10H7"/>'
    when "maximize"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>'
    when "settings"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/> <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>'
    when "save"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"/>'
    when "refresh"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>'
    when "grid"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>'
    when "columns"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 4v16M15 4v16M4 6h16M4 10h16M4 14h16M4 18h16"/>'
    when "rows"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>'
    when "chevron-down"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>'
    when "chevron-up"
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>'
    else
      '<circle cx="12" cy="12" r="3"/>'
    end
  end

  def action_groups
    groups = []
    
    groups << { name: "Main", actions: main_actions }
    groups << { name: "Widget", actions: widget_actions }
    groups << { name: "View", actions: view_actions }
    groups << { name: "Settings", actions: settings_actions }
    
    groups
  end

  def collapsed_class
    [
      "transform",
      "transition-transform",
      "duration-300",
      position == "left" || position == "right" ? "scale-y-0" : "scale-x-0"
    ].join(" ")
  end
end