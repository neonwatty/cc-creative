# frozen_string_literal: true

class ConflictResolutionModalComponent < ViewComponent::Base
  def initialize(document:, current_user:, options: {})
    @document = document
    @current_user = current_user
    @modal_size = options.fetch(:modal_size, :large) # :small, :medium, :large, :full
    @conflict_type = options.fetch(:conflict_type, :content) # :content, :format, :simultaneous
    @auto_resolve = options.fetch(:auto_resolve, false)
    @show_diff = options.fetch(:show_diff, true)
    @enable_merge = options.fetch(:enable_merge, true)
    @resolution_timeout = options.fetch(:resolution_timeout, 30000) # 30 seconds
  end

  private

  attr_reader :document, :current_user, :modal_size, :conflict_type, :auto_resolve, 
              :show_diff, :enable_merge, :resolution_timeout

  def modal_backdrop_class
    [
      "fixed",
      "inset-0",
      "z-50",
      "flex",
      "items-center",
      "justify-center",
      "bg-black",
      "bg-opacity-50",
      "backdrop-blur-sm",
      "transition-all",
      "duration-300",
      "ease-in-out"
    ].join(" ")
  end

  def modal_container_class
    base_classes = [
      "relative",
      "bg-white",
      "dark:bg-creative-neutral-900",
      "rounded-xl",
      "shadow-creative-2xl",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "max-h-[90vh]",
      "flex",
      "flex-col",
      "overflow-hidden",
      "transform",
      "transition-all",
      "duration-300",
      "ease-out"
    ]

    case modal_size
    when :small
      base_classes.concat(["w-full", "max-w-md", "mx-4"])
    when :medium
      base_classes.concat(["w-full", "max-w-2xl", "mx-4"])
    when :full
      base_classes.concat(["w-full", "max-w-7xl", "mx-4", "h-[90vh]"])
    else # large
      base_classes.concat(["w-full", "max-w-4xl", "mx-4"])
    end

    base_classes.join(" ")
  end

  def modal_header_class
    [
      "flex",
      "items-center",
      "justify-between",
      "px-6",
      "py-4",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800"
    ].join(" ")
  end

  def modal_body_class
    [
      "flex-1",
      "overflow-y-auto",
      "px-6",
      "py-4"
    ].join(" ")
  end

  def modal_footer_class
    [
      "flex",
      "items-center",
      "justify-between",
      "px-6",
      "py-4",
      "border-t",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800"
    ].join(" ")
  end

  def conflict_icon_class
    base_classes = [
      "flex-shrink-0",
      "w-6",
      "h-6",
      "mr-3"
    ]

    case conflict_type
    when :format
      base_classes << "text-creative-accent-amber"
    when :simultaneous
      base_classes << "text-creative-accent-rose"
    else # content
      base_classes << "text-creative-accent-orange"
    end

    base_classes.join(" ")
  end

  def conflict_title
    case conflict_type
    when :format
      "Formatting Conflict Detected"
    when :simultaneous
      "Simultaneous Edit Conflict"
    else # content
      "Content Conflict Detected"
    end
  end

  def conflict_description
    case conflict_type
    when :format
      "Different users have applied conflicting formatting to the same text."
    when :simultaneous
      "Multiple users are editing the same section simultaneously."
    else # content
      "Conflicting changes have been made to the same content."
    end
  end

  def diff_container_class
    [
      "grid",
      "grid-cols-1",
      "lg:grid-cols-2",
      "gap-4",
      "mt-6",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "rounded-lg",
      "overflow-hidden"
    ].join(" ")
  end

  def diff_panel_class(side)
    base_classes = [
      "relative",
      "overflow-hidden"
    ]

    case side
    when :local
      base_classes.concat([
        "bg-creative-accent-rose",
        "bg-opacity-5",
        "border-creative-accent-rose",
        "border-opacity-20"
      ])
    when :remote
      base_classes.concat([
        "bg-creative-accent-teal",
        "bg-opacity-5", 
        "border-creative-accent-teal",
        "border-opacity-20"
      ])
    end

    base_classes.join(" ")
  end

  def diff_header_class(side)
    base_classes = [
      "px-4",
      "py-2",
      "text-sm",
      "font-medium",
      "border-b",
      "border-current",
      "border-opacity-20"
    ]

    case side
    when :local
      base_classes.concat([
        "bg-creative-accent-rose",
        "bg-opacity-10",
        "text-creative-accent-rose"
      ])
    when :remote
      base_classes.concat([
        "bg-creative-accent-teal",
        "bg-opacity-10",
        "text-creative-accent-teal"
      ])
    end

    base_classes.join(" ")
  end

  def diff_content_class
    [
      "p-4",
      "text-sm",
      "font-mono",
      "leading-relaxed",
      "max-h-64",
      "overflow-y-auto",
      "whitespace-pre-wrap"
    ].join(" ")
  end

  def action_button_class(variant)
    base_classes = [
      "inline-flex",
      "items-center",
      "justify-center",
      "px-4",
      "py-2",
      "border",
      "rounded-lg",
      "text-sm",
      "font-medium",
      "transition-all",
      "duration-200",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-offset-2"
    ]

    case variant
    when :accept_local
      base_classes.concat([
        "border-creative-accent-rose",
        "bg-creative-accent-rose",
        "text-white",
        "hover:bg-creative-accent-rose",
        "hover:bg-opacity-90",
        "focus:ring-creative-accent-rose"
      ])
    when :accept_remote
      base_classes.concat([
        "border-creative-accent-teal",
        "bg-creative-accent-teal",
        "text-white",
        "hover:bg-creative-accent-teal",
        "hover:bg-opacity-90",
        "focus:ring-creative-accent-teal"
      ])
    when :merge
      base_classes.concat([
        "border-creative-primary-500",
        "bg-creative-primary-500",
        "text-white",
        "hover:bg-creative-primary-600",
        "focus:ring-creative-primary-500"
      ])
    when :cancel
      base_classes.concat([
        "border-creative-neutral-300",
        "dark:border-creative-neutral-600",
        "bg-white",
        "dark:bg-creative-neutral-800",
        "text-creative-neutral-700",
        "dark:text-creative-neutral-300",
        "hover:bg-creative-neutral-50",
        "dark:hover:bg-creative-neutral-700",
        "focus:ring-creative-neutral-500"
      ])
    end

    base_classes.join(" ")
  end

  def timer_container_class
    [
      "flex",
      "items-center",
      "space-x-2",
      "text-sm",
      "text-creative-neutral-500",
      "dark:text-creative-neutral-400"
    ].join(" ")
  end

  def timer_bar_class
    [
      "w-32",
      "h-2",
      "bg-creative-neutral-200",
      "dark:bg-creative-neutral-700",
      "rounded-full",
      "overflow-hidden"
    ].join(" ")
  end

  def timer_fill_class
    [
      "h-full",
      "bg-creative-accent-amber",
      "rounded-full",
      "transition-all",
      "duration-1000",
      "ease-linear"
    ].join(" ")
  end

  def conflict_icon_svg
    case conflict_type
    when :format
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"/>
      SVG
    when :simultaneous
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
      SVG
    else # content
      <<~SVG
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
      SVG
    end
  end

  def merge_tools_enabled?
    enable_merge && conflict_type == :content
  end

  def auto_resolution_enabled?
    auto_resolve
  end

  def accessibility_attributes
    {
      role: "dialog",
      "aria-modal": "true",
      "aria-labelledby": "conflict-modal-title",
      "aria-describedby": "conflict-modal-description"
    }
  end

  def configuration_data
    {
      'conflict-resolution-document-id': document.id,
      'conflict-resolution-current-user-id': current_user.id,
      'conflict-resolution-conflict-type': conflict_type,
      'conflict-resolution-auto-resolve': auto_resolve,
      'conflict-resolution-show-diff': show_diff,
      'conflict-resolution-enable-merge': enable_merge,
      'conflict-resolution-resolution-timeout': resolution_timeout
    }
  end
end