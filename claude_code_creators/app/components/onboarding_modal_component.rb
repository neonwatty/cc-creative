# frozen_string_literal: true

class OnboardingModalComponent < ViewComponent::Base
  def initialize(current_user:, options: {})
    @current_user = current_user
    @options = options
    @show_modal = options.fetch(:show_modal, should_show_onboarding?)
    @current_step = options.fetch(:current_step, 1)
    @total_steps = 4
  end

  private

  attr_reader :current_user, :options, :show_modal, :current_step, :total_steps

  def should_show_onboarding?
    # Show onboarding if user is new (less than 24 hours old) or explicitly requested
    return false unless current_user
    return true if options[:force_show]

    # Check if user has seen onboarding
    return false if current_user.attributes.key?("onboarding_completed_at") && current_user.onboarding_completed_at.present?

    # Show for new users
    current_user.created_at > 24.hours.ago
  end

  def modal_class
    base_classes = [
      "fixed",
      "inset-0",
      "z-50",
      "flex",
      "items-center",
      "justify-center",
      "p-4",
      "transition-all",
      "duration-300",
      "ease-creative"
    ]

    if show_modal
      base_classes += [ "opacity-100", "visible" ]
    else
      base_classes += [ "opacity-0", "invisible", "pointer-events-none" ]
    end

    base_classes.join(" ")
  end

  def backdrop_class
    [
      "absolute",
      "inset-0",
      "bg-creative-neutral-900/75",
      "backdrop-blur-sm",
      "transition-opacity",
      "duration-300"
    ].join(" ")
  end

  def content_class
    [
      "relative",
      "w-full",
      "max-w-2xl",
      "max-h-[90vh]",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "rounded-2xl",
      "shadow-creative-2xl",
      "dark:shadow-creative-dark-xl",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "overflow-hidden",
      "transform",
      "transition-all",
      "duration-300",
      "ease-creative"
    ].join(" ")
  end

  def header_class
    [
      "px-8",
      "py-6",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-gradient-to-r",
      "from-creative-primary-50",
      "to-creative-secondary-50",
      "dark:from-creative-primary-900/20",
      "dark:to-creative-secondary-900/20"
    ].join(" ")
  end

  def body_class
    [
      "px-8",
      "py-6",
      "overflow-y-auto",
      "max-h-[60vh]",
      "scrollbar-thin",
      "scrollbar-track-creative-neutral-100",
      "scrollbar-thumb-creative-neutral-300",
      "dark:scrollbar-track-creative-neutral-700",
      "dark:scrollbar-thumb-creative-neutral-500"
    ].join(" ")
  end

  def footer_class
    [
      "px-8",
      "py-6",
      "border-t",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800/50",
      "flex",
      "items-center",
      "justify-between"
    ].join(" ")
  end

  def progress_class
    [
      "flex",
      "items-center",
      "space-x-2",
      "mb-4"
    ].join(" ")
  end

  def progress_step_class(step_number)
    base_classes = [
      "flex",
      "items-center",
      "justify-center",
      "w-8",
      "h-8",
      "rounded-full",
      "text-sm",
      "font-medium",
      "transition-all",
      "duration-200"
    ]

    if step_number < current_step
      base_classes += [
        "bg-creative-secondary-500",
        "text-white"
      ]
    elsif step_number == current_step
      base_classes += [
        "bg-creative-primary-500",
        "text-white",
        "ring-4",
        "ring-creative-primary-200",
        "dark:ring-creative-primary-800"
      ]
    else
      base_classes += [
        "bg-creative-neutral-200",
        "dark:bg-creative-neutral-600",
        "text-creative-neutral-600",
        "dark:text-creative-neutral-400"
      ]
    end

    base_classes.join(" ")
  end

  def progress_line_class(step_number)
    base_classes = [
      "flex-1",
      "h-1",
      "mx-2",
      "rounded-full",
      "transition-colors",
      "duration-200"
    ]

    if step_number < current_step
      base_classes += [ "bg-creative-secondary-500" ]
    else
      base_classes += [ "bg-creative-neutral-200", "dark:bg-creative-neutral-600" ]
    end

    base_classes.join(" ")
  end

  def step_content
    case current_step
    when 1
      {
        title: "Welcome to Claude Code Creators!",
        subtitle: "Your AI-powered creative writing platform",
        content: welcome_step_content,
        icon: "sparkles"
      }
    when 2
      {
        title: "Document Editor",
        subtitle: "Rich text editing with AI assistance",
        content: editor_step_content,
        icon: "document-text"
      }
    when 3
      {
        title: "Context & Sub-Agents",
        subtitle: "Organize your creative process",
        content: context_step_content,
        icon: "collection"
      }
    when 4
      {
        title: "You're All Set!",
        subtitle: "Start creating amazing content",
        content: completion_step_content,
        icon: "check-circle"
      }
    end
  end

  def welcome_step_content
    {
      description: "Claude Code Creators is designed specifically for creative professionals like you. Whether you're writing marketing copy, stories, or any creative content, we're here to help you work faster and more efficiently.",
      features: [
        {
          icon: "lightning-bolt",
          title: "AI-Powered Writing",
          description: "Get intelligent suggestions and assistance while you write"
        },
        {
          icon: "users",
          title: "Sub-Agents",
          description: "Create specialized AI assistants for specific tasks"
        },
        {
          icon: "collection",
          title: "Context Management",
          description: "Keep your research and references organized and accessible"
        }
      ]
    }
  end

  def editor_step_content
    {
      description: "Our document editor is built for creative work. Rich text formatting, real-time collaboration, and AI assistance right where you need it.",
      features: [
        {
          icon: "pencil-alt",
          title: "Rich Text Editor",
          description: "Full formatting options with creative-focused design"
        },
        {
          icon: "save",
          title: "Auto-save",
          description: "Never lose your work with automatic saving"
        },
        {
          icon: "eye",
          title: "Live Preview",
          description: "See your formatting changes in real-time"
        }
      ],
      tip: "💡 Try using keyboard shortcuts like ⌘B for bold and ⌘I for italic!"
    }
  end

  def context_step_content
    {
      description: "Keep your creative process organized with context items and specialized sub-agents that help you focus on different aspects of your work.",
      features: [
        {
          icon: "bookmark",
          title: "Context Items",
          description: "Save snippets, research, and references for easy access"
        },
        {
          icon: "user-group",
          title: "Sub-Agents",
          description: "Create AI assistants for specific tasks like editing or research"
        },
        {
          icon: "arrows-expand",
          title: "Drag & Drop",
          description: "Easily move content between your sidebar and document"
        }
      ],
      tip: "🎯 Pro tip: Use sub-agents for specialized tasks like 'Brand Voice Checker' or 'Research Assistant'"
    }
  end

  def completion_step_content
    {
      description: "You're ready to start creating! Your creative workspace is set up and ready to help you produce amazing content.",
      next_steps: [
        {
          icon: "document-add",
          title: "Create Your First Document",
          description: "Start with a blank document or choose from our templates",
          action: "Create Document",
          url: new_document_path
        },
        {
          icon: "book-open",
          title: "Explore Examples",
          description: "Check out sample documents to see what's possible",
          action: "View Examples",
          url: "#"
        },
        {
          icon: "question-mark-circle",
          title: "Get Help",
          description: "Visit our help center for tips and tutorials",
          action: "Help Center",
          url: "#"
        }
      ]
    }
  end

  def close_button_class
    [
      "absolute",
      "top-4",
      "right-4",
      "p-2",
      "text-creative-neutral-400",
      "hover:text-creative-neutral-600",
      "dark:hover:text-creative-neutral-200",
      "hover:bg-creative-neutral-100",
      "dark:hover:bg-creative-neutral-700",
      "rounded-lg",
      "transition-all",
      "duration-200"
    ].join(" ")
  end

  def feature_card_class
    [
      "flex",
      "items-start",
      "space-x-3",
      "p-4",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-700/50",
      "rounded-xl",
      "border",
      "border-creative-neutral-200/50",
      "dark:border-creative-neutral-600/50"
    ].join(" ")
  end

  def action_card_class
    [
      "group",
      "block",
      "p-6",
      "bg-gradient-to-br",
      "from-creative-primary-50",
      "to-creative-secondary-50",
      "dark:from-creative-primary-900/20",
      "dark:to-creative-secondary-900/20",
      "rounded-xl",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-600",
      "hover:shadow-creative-lg",
      "dark:hover:shadow-creative-dark-lg",
      "transition-all",
      "duration-200",
      "hover:scale-105"
    ].join(" ")
  end

  def is_final_step?
    current_step >= total_steps
  end

  def can_go_next?
    current_step < total_steps
  end

  def can_go_previous?
    current_step > 1
  end
end
