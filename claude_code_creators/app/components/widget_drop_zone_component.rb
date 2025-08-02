# frozen_string_literal: true

class WidgetDropZoneComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(target_element:, accepted_types: [], options: {})
    @target_element = target_element
    @accepted_types = accepted_types.presence || %w[context_item widget snippet]
    @options = options
    @show_instructions = options.fetch(:show_instructions, true)
    @allow_multiple = options.fetch(:allow_multiple, true)
    @position = options.fetch(:position, :center) # :top, :center, :bottom
    @size = options.fetch(:size, :medium) # :small, :medium, :large
  end

  private

  attr_reader :target_element, :accepted_types, :options, :show_instructions, :allow_multiple, :position, :size

  def drop_zone_class
    base_classes = [
      "widget-drop-zone",
      "relative",
      "transition-all",
      "duration-300",
      "ease-creative",
      "border-2",
      "border-dashed",
      "border-transparent",
      "rounded-xl"
    ]

    # Size variants
    case size
    when :small
      base_classes += [ "p-4", "min-h-[100px]" ]
    when :large
      base_classes += [ "p-8", "min-h-[300px]" ]
    else
      base_classes += [ "p-6", "min-h-[200px]" ]
    end

    # Position variants
    case position
    when :top
      base_classes += [ "items-start", "justify-center" ]
    when :bottom
      base_classes += [ "items-end", "justify-center" ]
    else
      base_classes += [ "items-center", "justify-center" ]
    end

    base_classes += [
      "flex",
      "flex-col",
      "text-center",
      # Default state
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-900",
      "hover:bg-creative-neutral-100",
      "dark:hover:bg-creative-neutral-800"
    ]

    base_classes.join(" ")
  end

  def drop_zone_active_class
    [
      "border-creative-primary-300",
      "dark:border-creative-primary-600",
      "bg-creative-primary-50",
      "dark:bg-creative-primary-900/20",
      "shadow-creative-lg",
      "dark:shadow-creative-dark-lg",
      "scale-102"
    ].join(" ")
  end

  def drop_zone_hover_class
    [
      "border-creative-primary-500",
      "dark:border-creative-primary-400",
      "bg-creative-primary-100",
      "dark:bg-creative-primary-800/30",
      "shadow-creative-xl",
      "dark:shadow-creative-dark-xl",
      "scale-105"
    ].join(" ")
  end

  def instructions_class
    base_classes = [
      "transition-opacity",
      "duration-200",
      "space-y-3"
    ]

    case size
    when :small
      base_classes += [ "text-sm" ]
    when :large
      base_classes += [ "text-lg" ]
    else
      base_classes += [ "text-base" ]
    end

    base_classes.join(" ")
  end

  def icon_class
    base_classes = [
      "mx-auto",
      "text-creative-neutral-400",
      "dark:text-creative-neutral-500",
      "transition-colors",
      "duration-200"
    ]

    case size
    when :small
      base_classes += [ "w-8", "h-8" ]
    when :large
      base_classes += [ "w-16", "h-16" ]
    else
      base_classes += [ "w-12", "h-12" ]
    end

    base_classes.join(" ")
  end

  def title_class
    base_classes = [
      "font-semibold",
      "text-creative-neutral-700",
      "dark:text-creative-neutral-300",
      "transition-colors",
      "duration-200"
    ]

    case size
    when :small
      base_classes += [ "text-sm" ]
    when :large
      base_classes += [ "text-xl" ]
    else
      base_classes += [ "text-lg" ]
    end

    base_classes.join(" ")
  end

  def description_class
    base_classes = [
      "text-creative-neutral-500",
      "dark:text-creative-neutral-400",
      "transition-colors",
      "duration-200"
    ]

    case size
    when :small
      base_classes += [ "text-xs" ]
    when :large
      base_classes += [ "text-base" ]
    else
      base_classes += [ "text-sm" ]
    end

    base_classes.join(" ")
  end

  def accepted_types_list
    accepted_types.map do |type|
      case type
      when "context_item"
        "Context Items"
      when "widget"
        "Widgets"
      when "snippet"
        "Code Snippets"
      when "image"
        "Images"
      when "file"
        "Files"
      else
        type.humanize
      end
    end.join(", ")
  end

  def drop_zone_data_attributes
    {
      controller: "widget-drop-zone",
      "widget_drop_zone_target_value": target_element,
      "widget_drop_zone_accepted_types_value": accepted_types.to_json,
      "widget_drop_zone_allow_multiple_value": allow_multiple,
      "widget_drop_zone_position_value": position,
      action: [
        "dragover->widget-drop-zone#handleDragOver",
        "dragenter->widget-drop-zone#handleDragEnter",
        "dragleave->widget-drop-zone#handleDragLeave",
        "drop->widget-drop-zone#handleDrop"
      ].join(" ")
    }
  end

  def overlay_class
    [
      "absolute",
      "inset-0",
      "bg-creative-primary-500/10",
      "dark:bg-creative-primary-400/10",
      "backdrop-blur-sm",
      "rounded-xl",
      "opacity-0",
      "invisible",
      "transition-all",
      "duration-300",
      "flex",
      "items-center",
      "justify-center"
    ].join(" ")
  end

  def pulse_animation_class
    [
      "absolute",
      "inset-0",
      "border-2",
      "border-creative-primary-400",
      "dark:border-creative-primary-500",
      "rounded-xl",
      "animate-ping",
      "opacity-75"
    ].join(" ")
  end
end
