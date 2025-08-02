# frozen_string_literal: true

class PluginMarketplaceComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(user:, options: {})
    @user = user
    @options = options
    @show_featured = options.fetch(:show_featured, true)
    @show_categories = options.fetch(:show_categories, true)
    @enable_search = options.fetch(:enable_search, true)
    @enable_filters = options.fetch(:enable_filters, true)
    @max_featured = options.fetch(:max_featured, 6)
    @items_per_page = options.fetch(:items_per_page, 12)
    @default_view = options.fetch(:default_view, "marketplace") # marketplace, installed, my_widgets
  end

  private

  attr_reader :user, :options, :show_featured, :show_categories, :enable_search,
              :enable_filters, :max_featured, :items_per_page, :default_view

  def marketplace_class
    [
      "plugin-marketplace",
      "fixed",
      "inset-0",
      "z-60",
      "bg-black/60",
      "backdrop-blur-sm",
      "flex",
      "items-center",
      "justify-center",
      "p-4",
      "opacity-0",
      "invisible",
      "transition-all",
      "duration-400",
      "ease-creative-in-out"
    ].join(" ")
  end

  def marketplace_visible_class
    [
      "opacity-100",
      "visible"
    ].join(" ")
  end

  def content_class
    [
      "marketplace-content",
      "bg-white",
      "dark:bg-creative-neutral-900",
      "rounded-2xl",
      "shadow-creative-2xl",
      "w-full",
      "max-w-7xl",
      "max-h-[90vh]",
      "flex",
      "flex-col",
      "overflow-hidden",
      "transform",
      "scale-95",
      "transition-all",
      "duration-400",
      "ease-creative-out",
      "border",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700"
    ].join(" ")
  end

  def content_visible_class
    "scale-100"
  end

  def header_class
    [
      "marketplace-header",
      "flex",
      "items-center",
      "justify-between",
      "p-6",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-gradient-to-r",
      "from-creative-primary-50",
      "via-white",
      "to-creative-secondary-50",
      "dark:from-creative-neutral-800",
      "dark:via-creative-neutral-800",
      "dark:to-creative-neutral-700"
    ].join(" ")
  end

  def nav_class
    [
      "marketplace-nav",
      "flex",
      "border-b",
      "border-gray-200",
      "dark:border-gray-700",
      "bg-gray-50",
      "dark:bg-gray-800"
    ].join(" ")
  end

  def nav_button_class(view, current_view)
    base_classes = [
      "nav-btn",
      "flex",
      "items-center",
      "space-x-2",
      "px-6",
      "py-4",
      "text-sm",
      "font-medium",
      "transition-all",
      "duration-200",
      "border-b-2",
      "hover:bg-white",
      "dark:hover:bg-gray-700"
    ]

    if view == current_view
      base_classes += [
        "text-blue-600",
        "dark:text-blue-400",
        "border-blue-600",
        "dark:border-blue-400",
        "bg-white",
        "dark:bg-gray-700"
      ]
    else
      base_classes += [
        "text-gray-600",
        "dark:text-gray-400",
        "border-transparent",
        "hover:text-gray-900",
        "dark:hover:text-gray-200"
      ]
    end

    base_classes.join(" ")
  end

  def toolbar_class
    [
      "marketplace-toolbar",
      "flex",
      "items-center",
      "justify-between",
      "p-4",
      "bg-white",
      "dark:bg-gray-900",
      "border-b",
      "border-gray-200",
      "dark:border-gray-700",
      "gap-4"
    ].join(" ")
  end

  def search_section_class
    [
      "search-section",
      "flex",
      "items-center",
      "flex-1",
      "max-w-md"
    ].join(" ")
  end

  def search_input_class
    [
      "search-input",
      "w-full",
      "px-4",
      "py-2",
      "pl-10",
      "text-sm",
      "border",
      "border-gray-300",
      "dark:border-gray-600",
      "rounded-lg",
      "bg-white",
      "dark:bg-gray-800",
      "text-gray-900",
      "dark:text-gray-100",
      "placeholder-gray-500",
      "dark:placeholder-gray-400",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-blue-500",
      "focus:border-transparent"
    ].join(" ")
  end

  def filter_section_class
    [
      "filter-section",
      "flex",
      "items-center",
      "space-x-3"
    ].join(" ")
  end

  def select_class
    [
      "px-3",
      "py-2",
      "text-sm",
      "border",
      "border-gray-300",
      "dark:border-gray-600",
      "rounded-lg",
      "bg-white",
      "dark:bg-gray-800",
      "text-gray-900",
      "dark:text-gray-100",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-blue-500",
      "focus:border-transparent"
    ].join(" ")
  end

  def body_class
    [
      "marketplace-body",
      "flex-1",
      "overflow-hidden",
      "bg-gray-50",
      "dark:bg-gray-900"
    ].join(" ")
  end

  def view_class
    [
      "marketplace-view",
      "h-full",
      "overflow-y-auto",
      "scrollbar-thin",
      "scrollbar-thumb-gray-300",
      "dark:scrollbar-thumb-gray-600",
      "scrollbar-track-transparent"
    ].join(" ")
  end

  def featured_section_class
    [
      "featured-section",
      "p-6",
      "bg-gradient-to-br",
      "from-blue-50",
      "via-white",
      "to-purple-50",
      "dark:from-gray-800",
      "dark:via-gray-900",
      "dark:to-purple-900/20"
    ].join(" ")
  end

  def section_title_class
    [
      "text-xl",
      "font-bold",
      "text-gray-900",
      "dark:text-gray-100",
      "mb-4",
      "flex",
      "items-center",
      "space-x-2"
    ].join(" ")
  end

  def plugin_grid_class
    [
      "plugin-grid",
      "grid",
      "grid-cols-1",
      "sm:grid-cols-2",
      "lg:grid-cols-3",
      "gap-6"
    ].join(" ")
  end

  def featured_grid_class
    [
      "featured-grid",
      "grid",
      "grid-cols-1",
      "sm:grid-cols-2",
      "lg:grid-cols-3",
      "xl:grid-cols-4",
      "gap-4"
    ].join(" ")
  end

  def plugin_card_class(featured = false)
    base_classes = [
      "plugin-card",
      "bg-white",
      "dark:bg-gray-800",
      "rounded-xl",
      "shadow-md",
      "hover:shadow-xl",
      "transition-all",
      "duration-300",
      "border",
      "border-gray-200",
      "dark:border-gray-700",
      "hover:border-blue-300",
      "dark:hover:border-blue-600",
      "overflow-hidden",
      "group",
      "cursor-pointer"
    ]

    if featured
      base_classes += [
        "ring-2",
        "ring-blue-500/20",
        "dark:ring-blue-400/20"
      ]
    end

    base_classes.join(" ")
  end

  def card_header_class
    [
      "plugin-header",
      "p-4",
      "border-b",
      "border-gray-100",
      "dark:border-gray-700"
    ].join(" ")
  end

  def card_body_class
    [
      "plugin-body",
      "p-4",
      "flex-1"
    ].join(" ")
  end

  def card_footer_class
    [
      "plugin-footer",
      "p-4",
      "bg-gray-50",
      "dark:bg-gray-700/50",
      "border-t",
      "border-gray-100",
      "dark:border-gray-700",
      "flex",
      "items-center",
      "justify-between"
    ].join(" ")
  end

  def plugin_icon_class
    [
      "plugin-icon",
      "w-12",
      "h-12",
      "rounded-lg",
      "bg-gradient-to-br",
      "from-blue-500",
      "to-purple-600",
      "flex",
      "items-center",
      "justify-center",
      "text-white",
      "text-xl",
      "font-bold",
      "shadow-lg",
      "group-hover:scale-110",
      "transition-transform",
      "duration-200"
    ].join(" ")
  end

  def plugin_info_class
    [
      "plugin-info",
      "flex-1",
      "ml-4"
    ].join(" ")
  end

  def plugin_name_class
    [
      "plugin-name",
      "text-lg",
      "font-semibold",
      "text-gray-900",
      "dark:text-gray-100",
      "group-hover:text-blue-600",
      "dark:group-hover:text-blue-400",
      "transition-colors",
      "duration-200"
    ].join(" ")
  end

  def plugin_meta_class
    [
      "plugin-meta",
      "flex",
      "items-center",
      "space-x-2",
      "text-sm",
      "text-gray-500",
      "dark:text-gray-400",
      "mt-1"
    ].join(" ")
  end

  def plugin_description_class
    [
      "plugin-description",
      "text-gray-600",
      "dark:text-gray-300",
      "text-sm",
      "line-clamp-2",
      "mb-3"
    ].join(" ")
  end

  def plugin_tags_class
    [
      "plugin-tags",
      "flex",
      "flex-wrap",
      "gap-2",
      "mb-3"
    ].join(" ")
  end

  def tag_class(type = "default")
    base_classes = [
      "tag",
      "px-2",
      "py-1",
      "text-xs",
      "font-medium",
      "rounded-full"
    ]

    case type
    when "category"
      base_classes += [
        "bg-blue-100",
        "text-blue-800",
        "dark:bg-blue-900/30",
        "dark:text-blue-300"
      ]
    when "featured"
      base_classes += [
        "bg-yellow-100",
        "text-yellow-800",
        "dark:bg-yellow-900/30",
        "dark:text-yellow-300"
      ]
    else
      base_classes += [
        "bg-gray-100",
        "text-gray-800",
        "dark:bg-gray-700",
        "dark:text-gray-300"
      ]
    end

    base_classes.join(" ")
  end

  def status_badge_class(status)
    base_classes = [
      "status-badge",
      "px-2",
      "py-1",
      "text-xs",
      "font-medium",
      "rounded-full"
    ]

    case status
    when "installed"
      base_classes += [
        "bg-green-100",
        "text-green-800",
        "dark:bg-green-900/30",
        "dark:text-green-300"
      ]
    when "active"
      base_classes += [
        "bg-blue-100",
        "text-blue-800",
        "dark:bg-blue-900/30",
        "dark:text-blue-300"
      ]
    when "disabled"
      base_classes += [
        "bg-gray-100",
        "text-gray-800",
        "dark:bg-gray-700",
        "dark:text-gray-300"
      ]
    when "error"
      base_classes += [
        "bg-red-100",
        "text-red-800",
        "dark:bg-red-900/30",
        "dark:text-red-300"
      ]
    else
      base_classes += [
        "bg-gray-100",
        "text-gray-800",
        "dark:bg-gray-700",
        "dark:text-gray-300"
      ]
    end

    base_classes.join(" ")
  end

  def action_button_class(variant = "primary")
    base_classes = [
      "btn",
      "btn-sm",
      "px-3",
      "py-1.5",
      "text-xs",
      "font-medium",
      "rounded-lg",
      "transition-all",
      "duration-200",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-offset-2"
    ]

    case variant
    when "primary"
      base_classes += [
        "bg-blue-600",
        "text-white",
        "hover:bg-blue-700",
        "focus:ring-blue-500"
      ]
    when "secondary"
      base_classes += [
        "bg-gray-100",
        "text-gray-700",
        "dark:bg-gray-700",
        "dark:text-gray-300",
        "hover:bg-gray-200",
        "dark:hover:bg-gray-600",
        "focus:ring-gray-500"
      ]
    when "success"
      base_classes += [
        "bg-green-600",
        "text-white",
        "hover:bg-green-700",
        "focus:ring-green-500"
      ]
    when "warning"
      base_classes += [
        "bg-yellow-600",
        "text-white",
        "hover:bg-yellow-700",
        "focus:ring-yellow-500"
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

  def empty_state_class
    [
      "empty-state",
      "flex",
      "flex-col",
      "items-center",
      "justify-center",
      "py-16",
      "text-center"
    ].join(" ")
  end

  def loading_state_class
    [
      "loading-state",
      "flex",
      "items-center",
      "justify-center",
      "py-16"
    ].join(" ")
  end

  def spinner_class
    [
      "animate-spin",
      "rounded-full",
      "h-8",
      "w-8",
      "border-b-2",
      "border-blue-600",
      "dark:border-blue-400"
    ].join(" ")
  end

  def pagination_class
    [
      "pagination",
      "flex",
      "items-center",
      "justify-between",
      "px-6",
      "py-4",
      "bg-white",
      "dark:bg-gray-800",
      "border-t",
      "border-gray-200",
      "dark:border-gray-700"
    ].join(" ")
  end

  def marketplace_data_attributes
    {
      controller: "plugin-marketplace",
      "plugin_marketplace_user_id_value": user.id,
      "plugin_marketplace_default_view_value": default_view,
      "plugin_marketplace_enable_search_value": enable_search,
      "plugin_marketplace_enable_filters_value": enable_filters,
      "plugin_marketplace_items_per_page_value": items_per_page,
      action: [
        "click->plugin-marketplace#handleBackdropClick",
        "keydown->plugin-marketplace#handleKeydown"
      ].join(" ")
    }
  end

  def sample_categories
    [
      "Development Tools",
      "AI & Machine Learning",
      "Productivity",
      "Documentation",
      "Testing",
      "Deployment",
      "Design",
      "Analytics",
      "Security",
      "Integration"
    ]
  end

  def sample_featured_plugins
    [
      {
        id: 1,
        name: "AI Code Assistant",
        author: "DevTools Inc",
        version: "2.1.0",
        description: "Intelligent code completion and refactoring suggestions powered by advanced AI models.",
        category: "AI & Machine Learning",
        icon: "🤖",
        rating: 4.8,
        downloads: "50k+",
        status: "not_installed",
        featured: true,
        keywords: [ "ai", "completion", "refactoring" ]
      },
      {
        id: 2,
        name: "Database Explorer",
        author: "DataViz Pro",
        version: "1.5.2",
        description: "Visual database schema explorer with query builder and performance analytics.",
        category: "Development Tools",
        icon: "🗄️",
        rating: 4.6,
        downloads: "25k+",
        status: "installed",
        featured: true,
        keywords: [ "database", "sql", "analytics" ]
      },
      {
        id: 3,
        name: "Deployment Manager",
        author: "CloudOps",
        version: "3.0.1",
        description: "One-click deployment to multiple cloud providers with rollback capabilities.",
        category: "Deployment",
        icon: "🚀",
        rating: 4.9,
        downloads: "75k+",
        status: "active",
        featured: true,
        keywords: [ "deployment", "cloud", "devops" ]
      }
    ]
  end

  def get_status_text(status)
    case status
    when "not_installed"
      "Not Installed"
    when "installed"
      "Installed"
    when "active"
      "Active"
    when "disabled"
      "Disabled"
    when "error"
      "Error"
    when "updating"
      "Updating..."
    else
      status.humanize
    end
  end

  def get_action_buttons(plugin)
    status = plugin[:status]

    case status
    when "not_installed"
      [
        { text: "Install", action: "install-plugin", variant: "primary" },
        { text: "Details", action: "view-details", variant: "secondary" }
      ]
    when "installed", "active"
      [
        { text: "Create Widget", action: "create-widget", variant: "primary" },
        { text: "Configure", action: "configure", variant: "secondary" }
      ]
    when "disabled"
      [
        { text: "Enable", action: "enable-plugin", variant: "success" },
        { text: "Remove", action: "uninstall", variant: "danger" }
      ]
    else
      [
        { text: "Details", action: "view-details", variant: "secondary" }
      ]
    end
  end
end
