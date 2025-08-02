# frozen_string_literal: true

class WidgetContainerComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(document_id:, user_id:, options: {})
    @document_id = document_id
    @user_id = user_id
    @options = options
    @layout_mode = options.fetch(:layout_mode, "grid") # grid, column, row
    @enable_docking = options.fetch(:enable_docking, true)
    @show_guidelines = options.fetch(:show_guidelines, true)
    @auto_save = options.fetch(:auto_save, true)
    @max_widgets = options.fetch(:max_widgets, 20)
    @enable_resize = options.fetch(:enable_resize, true)
    @enable_snap = options.fetch(:enable_snap, true)
    @snap_grid = options.fetch(:snap_grid, 20)
  end

  private

  attr_reader :document_id, :user_id, :options, :layout_mode, :enable_docking, 
              :show_guidelines, :auto_save, :max_widgets, :enable_resize, 
              :enable_snap, :snap_grid

  def container_class
    base_classes = [
      "widget-container",
      "relative",
      "w-full",
      "h-full",
      "overflow-hidden",
      "bg-white",
      "dark:bg-gray-900",
      "transition-colors",
      "duration-200"
    ]

    # Layout mode variants
    case layout_mode
    when "column"
      base_classes += ["flex", "flex-col", "space-y-4", "p-4"]
    when "row"
      base_classes += ["flex", "flex-row", "space-x-4", "p-4", "overflow-x-auto"]
    else # grid
      base_classes += ["relative"]
    end

    base_classes.join(" ")
  end

  def widget_area_class
    base_classes = [
      "widget-area",
      "relative",
      "w-full",
      "h-full",
      "transition-all",
      "duration-300",
      "ease-in-out"
    ]

    if layout_mode == "grid"
      base_classes += [
        "absolute",
        "inset-0",
        "overflow-hidden"
      ]
    else
      base_classes += [
        "flex-1",
        "min-h-0"
      ]
    end

    base_classes.join(" ")
  end

  def docking_zone_class(zone)
    base_classes = [
      "docking-zone",
      "absolute",
      "transition-all",
      "duration-300",
      "ease-in-out",
      "border-2",
      "border-dashed",
      "border-transparent",
      "bg-creative-primary-50/0",
      "dark:bg-creative-primary-900/0",
      "rounded-xl",
      "opacity-0",
      "invisible",
      "backdrop-blur-sm",
      "z-40",
      "flex",
      "items-center",
      "justify-center"
    ]

    # Zone-specific positioning with enhanced visual feedback
    case zone
    when "left"
      base_classes += ["left-2", "top-1/4", "bottom-1/4", "w-20"]
    when "right"
      base_classes += ["right-2", "top-1/4", "bottom-1/4", "w-20"]
    when "top"
      base_classes += ["top-2", "left-1/4", "right-1/4", "h-20"]
    when "bottom"
      base_classes += ["bottom-2", "left-1/4", "right-1/4", "h-20"]
    when "center"
      base_classes += ["top-1/2", "left-1/2", "transform", "-translate-x-1/2", "-translate-y-1/2", "w-40", "h-40"]
    end

    base_classes.join(" ")
  end

  def docking_zone_active_class
    [
      "opacity-100",
      "visible",
      "border-creative-primary-400",
      "dark:border-creative-primary-500",
      "bg-creative-primary-50/90",
      "dark:bg-creative-primary-900/60",
      "shadow-creative-lg",
      "scale-105",
      "animate-pulse-gentle"
    ].join(" ")
  end

  def snap_grid_class
    return "" unless show_guidelines && enable_snap

    [
      "snap-grid",
      "absolute",
      "inset-0",
      "pointer-events-none",
      "opacity-0",
      "transition-opacity",
      "duration-200"
    ].join(" ")
  end

  def snap_grid_visible_class
    "opacity-30"
  end

  def guidelines_class
    return "" unless show_guidelines

    [
      "widget-guidelines",
      "absolute",
      "inset-0",
      "pointer-events-none",
      "opacity-0",
      "transition-opacity",
      "duration-200"
    ].join(" ")
  end

  def guidelines_visible_class
    "opacity-100"
  end

  def status_bar_class
    [
      "widget-status-bar",
      "absolute",
      "bottom-0",
      "left-0",
      "right-0",
      "h-8",
      "bg-gray-100",
      "dark:bg-gray-800",
      "border-t",
      "border-gray-200",
      "dark:border-gray-700",
      "flex",
      "items-center",
      "justify-between",
      "px-4",
      "text-sm",
      "text-gray-600",
      "dark:text-gray-400",
      "transition-all",
      "duration-200",
      "transform",
      "translate-y-full",
      "opacity-0"
    ].join(" ")
  end

  def status_bar_visible_class
    [
      "translate-y-0",
      "opacity-100"
    ].join(" ")
  end

  def container_data_attributes
    {
      controller: "widget-container",
      "widget_container_document_id_value": document_id,
      "widget_container_user_id_value": user_id,
      "widget_container_layout_mode_value": layout_mode,
      "widget_container_enable_docking_value": enable_docking,
      "widget_container_show_guidelines_value": show_guidelines,
      "widget_container_auto_save_value": auto_save,
      "widget_container_max_widgets_value": max_widgets,
      "widget_container_enable_resize_value": enable_resize,
      "widget_container_enable_snap_value": enable_snap,
      "widget_container_snap_grid_value": snap_grid,
      action: [
        "widget-container:widget-created->widget-container#handleWidgetCreated",
        "widget-container:widget-moved->widget-container#handleWidgetMoved",
        "widget-container:widget-resized->widget-container#handleWidgetResized",
        "widget-container:layout-changed->widget-container#handleLayoutChanged",
        "dragover->widget-container#handleDragOver",
        "drop->widget-container#handleDrop"
      ].join(" ")
    }
  end

  def widget_area_data_attributes
    {
      "widget_container_target": "widgetArea",
      action: [
        "mousedown->widget-container#handleMouseDown",
        "mousemove->widget-container#handleMouseMove",
        "mouseup->widget-container#handleMouseUp",
        "contextmenu->widget-container#handleContextMenu"
      ].join(" ")
    }
  end

  def docking_zones
    return [] unless enable_docking
    %w[left right top bottom center]
  end

  def snap_grid_lines
    return { vertical: [], horizontal: [] } unless show_guidelines && enable_snap

    # Generate grid lines based on snap_grid size
    # This would be rendered as SVG lines in the template
    {
      vertical: (0..20).map { |i| i * snap_grid },
      horizontal: (0..15).map { |i| i * snap_grid }
    }
  end

  def widget_templates
    [
      {
        type: "text",
        name: "Text Widget",
        icon: "📄",
        description: "Simple text display widget"
      },
      {
        type: "notes",
        name: "Notes",
        icon: "📝", 
        description: "Editable notes widget"
      },
      {
        type: "todo",
        name: "Todo List",
        icon: "✅",
        description: "Task management widget"
      },
      {
        type: "timer",
        name: "Timer",
        icon: "⏰",
        description: "Countdown timer widget"
      },
      {
        type: "ai-review",
        name: "AI Review",
        icon: "🤖",
        description: "AI-powered code review"
      },
      {
        type: "console",
        name: "Console",
        icon: "💻",
        description: "Command execution console"
      }
    ]
  end

  def empty_state_class
    [
      "empty-state",
      "absolute",
      "inset-0",
      "flex",
      "flex-col",
      "items-center",
      "justify-center",
      "text-center",
      "space-y-6",
      "p-8",
      "transition-all",
      "duration-300",
      "ease-in-out"
    ].join(" ")
  end

  def empty_state_hidden_class
    [
      "opacity-0",
      "invisible",
      "pointer-events-none"
    ].join(" ")
  end

  def quick_add_button_class
    [
      "quick-add-button",
      "absolute",
      "bottom-6",
      "right-6",
      "w-14",
      "h-14",
      "bg-blue-600",
      "dark:bg-blue-500",
      "text-white",
      "rounded-full",
      "shadow-lg",
      "hover:shadow-xl",
      "hover:scale-105",
      "focus:outline-none",
      "focus:ring-4",
      "focus:ring-blue-300",
      "dark:focus:ring-blue-700",
      "transition-all",
      "duration-200",
      "flex",
      "items-center",
      "justify-center",
      "z-50"
    ].join(" ")
  end

  def layout_switcher_class
    [
      "layout-switcher",
      "absolute",
      "top-4",
      "right-4",
      "bg-white",
      "dark:bg-gray-800",
      "rounded-lg",
      "shadow-lg",
      "border",
      "border-gray-200",
      "dark:border-gray-700",
      "p-2",
      "flex",
      "space-x-1",
      "z-40",
      "transition-all",
      "duration-200"
    ].join(" ")
  end

  def layout_button_class(mode, current_mode)
    base_classes = [
      "layout-button",
      "p-2",
      "rounded",
      "transition-all",
      "duration-200",
      "hover:bg-gray-100",
      "dark:hover:bg-gray-700",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-blue-500"
    ]

    if mode == current_mode
      base_classes += [
        "bg-blue-100",
        "dark:bg-blue-900",
        "text-blue-600",
        "dark:text-blue-400"
      ]
    else
      base_classes += [
        "text-gray-600",
        "dark:text-gray-400"
      ]
    end

    base_classes.join(" ")
  end

  def performance_monitor_class
    [
      "performance-monitor",
      "absolute",
      "top-4",
      "left-4",
      "bg-white",
      "dark:bg-gray-800",
      "rounded-lg",
      "shadow-lg",
      "border",
      "border-gray-200",
      "dark:border-gray-700",
      "p-3",
      "text-xs",
      "space-y-1",
      "opacity-0",
      "transition-opacity",
      "duration-200",
      "z-30"
    ].join(" ")
  end

  def performance_monitor_visible_class
    "opacity-100"
  end
end