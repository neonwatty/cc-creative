# frozen_string_literal: true

class CursorTrackingComponent < ViewComponent::Base
  def initialize(document:, current_user:, options: {})
    @document = document
    @current_user = current_user
    @cursor_style = options.fetch(:cursor_style, :default) # :default, :minimal, :detailed
    @show_labels = options.fetch(:show_labels, true)
    @show_trails = options.fetch(:show_trails, false)
    @cursor_timeout = options.fetch(:cursor_timeout, 5000) # ms
    @smooth_movement = options.fetch(:smooth_movement, true)
    @collision_detection = options.fetch(:collision_detection, true)
    @container_selector = options.fetch(:container_selector, '.editor-content')
  end

  private

  attr_reader :document, :current_user, :cursor_style, :show_labels, :show_trails, 
              :cursor_timeout, :smooth_movement, :collision_detection, :container_selector

  def container_class
    [
      "cursor-tracking-overlay",
      "absolute",
      "inset-0",
      "pointer-events-none",
      "z-30",
      "overflow-hidden"
    ].join(" ")
  end

  def cursor_base_class
    base_classes = [
      "absolute",
      "pointer-events-none",
      "z-40",
      "cursor-element"
    ]

    if smooth_movement
      base_classes.concat([
        "transition-all",
        "duration-150",
        "ease-out"
      ])
    end

    base_classes.join(" ")
  end

  def cursor_icon_class
    base_classes = [
      "relative",
      "cursor-icon"
    ]

    case cursor_style
    when :minimal
      base_classes.concat([
        "w-3",
        "h-3"
      ])
    when :detailed
      base_classes.concat([
        "w-5",
        "h-5"
      ])
    else # default
      base_classes.concat([
        "w-4",
        "h-4"
      ])
    end

    base_classes.join(" ")
  end

  def cursor_label_class
    base_classes = [
      "absolute",
      "cursor-label",
      "text-xs",
      "font-medium",
      "text-white",
      "rounded",
      "shadow-creative-md",
      "whitespace-nowrap",
      "z-50"
    ]

    case cursor_style
    when :minimal
      base_classes.concat([
        "px-2",
        "py-1",
        "text-xs",
        "top-4",
        "left-1"
      ])
    when :detailed
      base_classes.concat([
        "px-3",
        "py-2",
        "text-sm",
        "top-6",
        "left-2"
      ])
    else # default
      base_classes.concat([
        "px-2",
        "py-1",
        "text-xs",
        "top-5",
        "left-2"
      ])
    end

    base_classes.join(" ")
  end

  def trail_container_class
    return "" unless show_trails

    [
      "absolute",
      "inset-0",
      "pointer-events-none",
      "z-20",
      "cursor-trails"
    ].join(" ")
  end

  def trail_dot_class
    [
      "absolute",
      "w-1",
      "h-1",
      "rounded-full",
      "pointer-events-none",
      "trail-dot",
      "opacity-60",
      "transition-opacity",
      "duration-1000"
    ].join(" ")
  end

  def collision_overlay_class
    return "" unless collision_detection

    [
      "absolute",
      "inset-0",
      "pointer-events-none",
      "z-25",
      "collision-overlay"
    ].join(" ")
  end

  def collision_zone_class
    [
      "absolute",
      "rounded-full",
      "border-2",
      "border-creative-accent-amber",
      "bg-creative-accent-amber",
      "bg-opacity-20",
      "pointer-events-none",
      "collision-zone",
      "w-8",
      "h-8",
      "transition-all",
      "duration-200"
    ].join(" ")
  end

  def cursor_colors
    [
      "text-creative-primary-500 bg-creative-primary-500",
      "text-creative-secondary-500 bg-creative-secondary-500", 
      "text-creative-accent-purple bg-creative-accent-purple",
      "text-creative-accent-amber bg-creative-accent-amber",
      "text-creative-accent-rose bg-creative-accent-rose",
      "text-creative-accent-teal bg-creative-accent-teal",
      "text-creative-accent-indigo bg-creative-accent-indigo",
      "text-creative-accent-orange bg-creative-accent-orange"
    ]
  end

  def user_cursor_color(user_id)
    color_index = user_id.hash.abs % cursor_colors.length
    cursor_colors[color_index]
  end

  def cursor_svg_path
    case cursor_style
    when :minimal
      "M2 2l14 5-5 2-2 5L2 2z"
    when :detailed
      "M2 2l16 6-6 2-2 6L2 2zm2 3.5l5.5 9L11 10l4-1.5L4 5.5z"
    else # default
      "M2 2l16 6-6 2-2 6L2 2z"
    end
  end

  def cursor_viewbox
    case cursor_style
    when :minimal
      "0 0 16 16"
    when :detailed
      "0 0 20 20"
    else # default
      "0 0 20 20"
    end
  end

  def animation_preferences_class
    [
      "motion-safe:transition-all",
      "motion-safe:duration-150",
      "motion-reduce:transition-none"
    ].join(" ")
  end

  def accessibility_attributes
    {
      role: "application",
      "aria-label": "Collaborative cursor tracking",
      "aria-live": "polite",
      "aria-atomic": "false"
    }
  end

  def configuration_data
    {
      'cursor-tracking-document-id': document.id,
      'cursor-tracking-current-user-id': current_user.id,
      'cursor-tracking-cursor-style': cursor_style,
      'cursor-tracking-show-labels': show_labels,
      'cursor-tracking-show-trails': show_trails,
      'cursor-tracking-cursor-timeout': cursor_timeout,
      'cursor-tracking-smooth-movement': smooth_movement,
      'cursor-tracking-collision-detection': collision_detection,
      'cursor-tracking-container-selector': container_selector
    }
  end
end