# frozen_string_literal: true

class PresenceIndicatorComponent < ViewComponent::Base
  def initialize(users:, current_user:, options: {})
    @users = users.reject { |user| user.id == current_user.id }
    @current_user = current_user
    @show_names = options.fetch(:show_names, true)
    @show_cursors = options.fetch(:show_cursors, false)
    @max_display = options.fetch(:max_display, 5)
    @size = options.fetch(:size, :medium) # :small, :medium, :large
  end

  private

  attr_reader :users, :current_user, :show_names, :show_cursors, :max_display, :size

  def displayed_users
    users.take(max_display)
  end

  def overflow_count
    [ users.count - max_display, 0 ].max
  end

  def has_overflow?
    overflow_count > 0
  end

  def avatar_size_class
    case size
    when :small
      "w-7 h-7 text-xs"
    when :large
      "w-12 h-12 text-base"
    else
      "w-8 h-8 text-sm"
    end
  end

  def avatar_colors
    [
      "bg-creative-primary-500 text-white",
      "bg-creative-secondary-500 text-white",
      "bg-creative-accent-purple text-white",
      "bg-creative-accent-amber text-white",
      "bg-creative-accent-rose text-white",
      "bg-creative-accent-teal text-white",
      "bg-creative-accent-indigo text-white",
      "bg-creative-accent-orange text-white"
    ]
  end

  def user_avatar_color(user)
    # Use a hash of the user ID to consistently assign colors
    color_index = user.id.hash.abs % avatar_colors.length
    avatar_colors[color_index]
  end

  def user_initials(user)
    name = user.name.presence || user.email
    name.split.map(&:first).join.upcase.first(2)
  end

  def presence_container_class
    base_classes = [
      "presence-indicators",
      "flex",
      "items-center",
      "space-x-1"
    ]

    if show_cursors
      base_classes << "relative"
    end

    base_classes.join(" ")
  end

  def avatar_base_class
    [
      "flex",
      "items-center",
      "justify-center",
      "rounded-full",
      "font-medium",
      "ring-2",
      "ring-white",
      "dark:ring-creative-neutral-800",
      "shadow-creative-sm",
      "transition-all",
      "duration-200",
      "hover:scale-110",
      "cursor-pointer",
      avatar_size_class
    ].join(" ")
  end

  def overflow_avatar_class
    [
      avatar_base_class,
      "bg-creative-neutral-200",
      "dark:bg-creative-neutral-700",
      "text-creative-neutral-700",
      "dark:text-creative-neutral-300",
      "hover:bg-creative-neutral-300",
      "dark:hover:bg-creative-neutral-600"
    ].join(" ")
  end

  def tooltip_class
    [
      "absolute",
      "bottom-full",
      "left-1/2",
      "transform",
      "-translate-x-1/2",
      "mb-2",
      "px-2",
      "py-1",
      "text-xs",
      "font-medium",
      "text-white",
      "bg-creative-neutral-900",
      "dark:bg-creative-neutral-700",
      "rounded",
      "shadow-creative-lg",
      "opacity-0",
      "invisible",
      "transition-all",
      "duration-200",
      "group-hover:opacity-100",
      "group-hover:visible",
      "pointer-events-none",
      "whitespace-nowrap",
      "z-50"
    ].join(" ")
  end

  def typing_indicator_class
    [
      "absolute",
      "-bottom-1",
      "-right-1",
      "w-3",
      "h-3",
      "bg-creative-secondary-500",
      "rounded-full",
      "border-2",
      "border-white",
      "dark:border-creative-neutral-800",
      "animate-pulse-gentle"
    ].join(" ")
  end
end
