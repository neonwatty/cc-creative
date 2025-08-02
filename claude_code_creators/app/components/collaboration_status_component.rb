# frozen_string_literal: true

class CollaborationStatusComponent < ViewComponent::Base
  def initialize(document:, current_user:, options: {})
    @document = document
    @current_user = current_user
    @position = options.fetch(:position, :top_right) # :top_left, :top_right, :bottom_left, :bottom_right, :inline
    @style = options.fetch(:style, :compact) # :minimal, :compact, :detailed
    @show_connection_quality = options.fetch(:show_connection_quality, true)
    @show_sync_status = options.fetch(:show_sync_status, true)
    @show_last_save = options.fetch(:show_last_save, true)
    @auto_hide = options.fetch(:auto_hide, false)
    @hide_delay = options.fetch(:hide_delay, 5000) # 5 seconds
  end

  private

  attr_reader :document, :current_user, :position, :style, :show_connection_quality,
              :show_sync_status, :show_last_save, :auto_hide, :hide_delay

  def container_class
    base_classes = [
      "collaboration-status",
      "flex",
      "items-center",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "rounded-lg",
      "shadow-creative-md",
      "backdrop-blur-sm",
      "transition-all",
      "duration-300",
      "ease-in-out",
      "z-40"
    ]

    case position
    when :top_left
      base_classes.concat([
        "fixed",
        "top-4",
        "left-4"
      ])
    when :top_right
      base_classes.concat([
        "fixed",
        "top-4",
        "right-4"
      ])
    when :bottom_left
      base_classes.concat([
        "fixed",
        "bottom-4",
        "left-4"
      ])
    when :bottom_right
      base_classes.concat([
        "fixed",
        "bottom-4",
        "right-4"
      ])
    else # inline
      base_classes.concat([
        "relative",
        "my-2"
      ])
    end

    case style
    when :minimal
      base_classes.concat([
        "px-3",
        "py-2",
        "space-x-2"
      ])
    when :detailed
      base_classes.concat([
        "px-5",
        "py-3",
        "space-x-4"
      ])
    else # compact
      base_classes.concat([
        "px-4",
        "py-2",
        "space-x-3"
      ])
    end

    base_classes.join(" ")
  end

  def status_indicator_class(status)
    base_classes = [
      "flex-shrink-0",
      "w-3",
      "h-3",
      "rounded-full",
      "transition-all",
      "duration-200"
    ]

    case status
    when :connected
      base_classes.concat([
        "bg-creative-accent-teal",
        "shadow-creative-accent-teal",
        "shadow-sm",
        "animate-pulse-gentle"
      ])
    when :connecting
      base_classes.concat([
        "bg-creative-accent-amber",
        "animate-bounce"
      ])
    when :disconnected
      base_classes.concat([
        "bg-creative-accent-rose",
        "animate-pulse"
      ])
    when :syncing
      base_classes.concat([
        "bg-creative-primary-500",
        "animate-spin"
      ])
    else # unknown
      base_classes.concat([
        "bg-creative-neutral-400",
        "animate-pulse"
      ])
    end

    base_classes.join(" ")
  end

  def status_text_class
    base_classes = [
      "font-medium",
      "text-creative-neutral-700",
      "dark:text-creative-neutral-300"
    ]

    case style
    when :minimal
      base_classes << "text-xs"
    when :detailed
      base_classes << "text-sm"
    else # compact
      base_classes << "text-xs"
    end

    base_classes.join(" ")
  end

  def connection_quality_class(quality)
    base_classes = [
      "flex",
      "items-center",
      "space-x-1"
    ]

    case quality
    when :excellent
      base_classes << "text-creative-accent-teal"
    when :good
      base_classes << "text-creative-accent-teal"
    when :fair
      base_classes << "text-creative-accent-amber"
    when :poor
      base_classes << "text-creative-accent-rose"
    else
      base_classes << "text-creative-neutral-500"
    end

    base_classes.join(" ")
  end

  def signal_bar_class(level, quality)
    base_classes = [
      "w-1",
      "rounded-full",
      "transition-all",
      "duration-200"
    ]

    # Height based on signal level
    case level
    when 1
      base_classes << "h-2"
    when 2
      base_classes << "h-3"
    when 3
      base_classes << "h-4"
    when 4
      base_classes << "h-5"
    end

    # Color based on quality
    case quality
    when :excellent, :good
      base_classes << "bg-creative-accent-teal"
    when :fair
      base_classes << "bg-creative-accent-amber"
    when :poor
      base_classes << "bg-creative-accent-rose"
    else
      base_classes << "bg-creative-neutral-300"
    end

    base_classes.join(" ")
  end

  def sync_status_class
    base_classes = [
      "flex",
      "items-center",
      "space-x-1",
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400"
    ]

    case style
    when :minimal
      base_classes << "text-xs"
    when :detailed
      base_classes << "text-sm"
    else # compact
      base_classes << "text-xs"
    end

    base_classes.join(" ")
  end

  def last_save_class
    base_classes = [
      "text-creative-neutral-500",
      "dark:text-creative-neutral-500"
    ]

    case style
    when :minimal
      base_classes << "text-xs"
    when :detailed
      base_classes << "text-sm"
    else # compact
      base_classes << "text-xs"
    end

    base_classes.join(" ")
  end

  def divider_class
    [
      "w-px",
      "h-4",
      "bg-creative-neutral-200",
      "dark:bg-creative-neutral-600"
    ].join(" ")
  end

  def icon_class
    base_classes = [
      "flex-shrink-0"
    ]

    case style
    when :minimal
      base_classes.concat(["w-3", "h-3"])
    when :detailed
      base_classes.concat(["w-4", "h-4"])
    else # compact
      base_classes.concat(["w-3", "h-3"])
    end

    base_classes.join(" ")
  end

  def status_message(status)
    case status
    when :connected
      "Connected"
    when :connecting
      "Connecting..."
    when :disconnected
      "Disconnected"
    when :syncing
      "Syncing..."
    when :saved
      "All changes saved"
    when :saving
      "Saving..."
    when :error
      "Connection error"
    else
      "Unknown status"
    end
  end

  def connection_quality_text(quality)
    case quality
    when :excellent
      "Excellent"
    when :good
      "Good"
    when :fair
      "Fair"
    when :poor
      "Poor"
    else
      "Unknown"
    end
  end

  def sync_icon_svg(status)
    case status
    when :syncing, :saving
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
      SVG
    when :saved
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
      SVG
    when :error
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
      SVG
    else
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
      SVG
    end
  end

  def wifi_icon_svg
    <<~SVG
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
            d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0"/>
    SVG
  end

  def signal_bars_for_quality(quality)
    case quality
    when :excellent
      4
    when :good
      3
    when :fair
      2
    when :poor
      1
    else
      0
    end
  end

  def should_show_divider?(current_element, elements)
    current_index = elements.index(current_element)
    current_index && current_index > 0 && current_index < elements.length
  end

  def accessibility_attributes
    {
      role: "status",
      "aria-live": "polite",
      "aria-label": "Collaboration status"
    }
  end

  def configuration_data
    {
      'collaboration-status-document-id': document.id,
      'collaboration-status-current-user-id': current_user.id,
      'collaboration-status-position': position,
      'collaboration-status-style': style,
      'collaboration-status-show-connection-quality': show_connection_quality,
      'collaboration-status-show-sync-status': show_sync_status,
      'collaboration-status-show-last-save': show_last_save,
      'collaboration-status-auto-hide': auto_hide,
      'collaboration-status-hide-delay': hide_delay
    }
  end
end