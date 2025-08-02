# frozen_string_literal: true

class TypingIndicatorsComponent < ViewComponent::Base
  def initialize(document:, current_user:, options: {})
    @document = document
    @current_user = current_user
    @position = options.fetch(:position, :bottom) # :top, :bottom, :inline
    @style = options.fetch(:style, :compact) # :compact, :detailed, :minimal
    @max_visible = options.fetch(:max_visible, 3)
    @show_avatars = options.fetch(:show_avatars, true)
    @animation_style = options.fetch(:animation_style, :pulse) # :pulse, :dots, :wave
  end

  private

  attr_reader :document, :current_user, :position, :style, :max_visible, :show_avatars, :animation_style

  def container_class
    base_classes = [
      "typing-indicators",
      "transition-all",
      "duration-300",
      "ease-in-out"
    ]

    case position
    when :top
      base_classes.concat([
        "fixed",
        "top-20",
        "left-1/2",
        "transform",
        "-translate-x-1/2",
        "z-40"
      ])
    when :inline
      base_classes.concat([
        "relative",
        "my-2"
      ])
    else # bottom
      base_classes.concat([
        "fixed",
        "bottom-6",
        "left-1/2",
        "transform",
        "-translate-x-1/2",
        "z-40"
      ])
    end

    base_classes.join(" ")
  end

  def indicator_card_class
    base_classes = [
      "bg-white",
      "dark:bg-creative-neutral-800",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "rounded-lg",
      "shadow-creative-md",
      "px-4",
      "py-2",
      "flex",
      "items-center",
      "space-x-3",
      "backdrop-blur-sm",
      "backdrop-saturate-150"
    ]

    case style
    when :minimal
      base_classes.concat([
        "px-3",
        "py-1",
        "text-sm",
        "shadow-creative-sm"
      ])
    when :detailed
      base_classes.concat([
        "px-5",
        "py-3",
        "shadow-creative-lg"
      ])
    else # compact
      base_classes.concat([
        "px-4",
        "py-2"
      ])
    end

    base_classes.join(" ")
  end

  def animation_container_class
    base_classes = [
      "flex",
      "items-center",
      "space-x-1"
    ]

    case animation_style
    when :wave
      base_classes << "typing-animation-wave"
    when :dots
      base_classes << "typing-animation-dots"
    else # pulse
      base_classes << "typing-animation-pulse"
    end

    base_classes.join(" ")
  end

  def typing_dot_class(index = 0)
    base_classes = [
      "w-2",
      "h-2",
      "bg-creative-primary-500",
      "rounded-full"
    ]

    case animation_style
    when :wave
      base_classes.concat([
        "animate-wave",
        "animation-delay-#{index * 150}ms"
      ])
    when :dots
      base_classes.concat([
        "animate-bounce",
        "animation-delay-#{index * 200}ms"
      ])
    else # pulse
      base_classes.concat([
        "animate-pulse-gentle",
        "animation-delay-#{index * 100}ms"
      ])
    end

    base_classes.join(" ")
  end

  def avatar_container_class
    return "" unless show_avatars

    [
      "flex",
      "-space-x-2",
      "mr-3"
    ].join(" ")
  end

  def typing_avatar_class
    [
      "w-6",
      "h-6",
      "rounded-full",
      "border-2",
      "border-white",
      "dark:border-creative-neutral-800",
      "flex",
      "items-center",
      "justify-center",
      "text-xs",
      "font-medium",
      "shadow-creative-sm"
    ].join(" ")
  end

  def typing_text_class
    base_classes = [
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400",
      "font-medium"
    ]

    case style
    when :minimal
      base_classes << "text-xs"
    when :detailed
      base_classes << "text-base"
    else # compact
      base_classes << "text-sm"
    end

    base_classes.join(" ")
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

  def user_avatar_color(user_id)
    color_index = user_id.hash.abs % avatar_colors.length
    avatar_colors[color_index]
  end

  def user_initials(name, email)
    display_name = name.presence || email
    display_name.split.map(&:first).join.upcase.first(2)
  end

  def typing_message_for_users(count)
    case count
    when 1
      "is typing"
    when 2
      "are typing"
    else
      "are typing"
    end
  end

  def overflow_message_class
    [
      "text-creative-neutral-500",
      "dark:text-creative-neutral-500",
      "text-xs",
      "font-normal",
      "ml-1"
    ].join(" ")
  end

  # Animation keyframes will be added via CSS
  def animation_styles
    case animation_style
    when :wave
      <<~CSS
        @keyframes wave {
          0%, 40%, 100% { transform: translateY(0); }
          20% { transform: translateY(-4px); }
        }
        .animate-wave { animation: wave 1.2s infinite ease-in-out; }
        .animation-delay-0ms { animation-delay: 0ms; }
        .animation-delay-150ms { animation-delay: 150ms; }
        .animation-delay-300ms { animation-delay: 300ms; }
      CSS
    when :dots
      <<~CSS
        .animation-delay-0ms { animation-delay: 0ms; }
        .animation-delay-200ms { animation-delay: 200ms; }
        .animation-delay-400ms { animation-delay: 400ms; }
      CSS
    else # pulse
      <<~CSS
        @keyframes pulse-gentle {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
        .animate-pulse-gentle { animation: pulse-gentle 1.5s infinite; }
        .animation-delay-0ms { animation-delay: 0ms; }
        .animation-delay-100ms { animation-delay: 100ms; }
        .animation-delay-200ms { animation-delay: 200ms; }
      CSS
    end
  end
end
