# frozen_string_literal: true

class SidebarNavigationComponent < ViewComponent::Base
  def initialize(current_user:, current_document: nil, options: {})
    @current_user = current_user
    @current_document = current_document
    @options = options
    @collapsed = options.fetch(:collapsed, false)
    @show_recent_documents = options.fetch(:show_recent_documents, true)
    @show_context_items = options.fetch(:show_context_items, true)
    @show_sub_agents = options.fetch(:show_sub_agents, true)
    @show_presence = options.fetch(:show_presence, false)
  end

  private

  attr_reader :current_user, :current_document, :options

  def sidebar_class
    base_classes = [
      "sidebar-navigation",
      "h-full",
      "bg-white",
      "dark:bg-creative-neutral-900",
      "border-r",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "transition-all",
      "duration-300",
      "ease-creative",
      "flex",
      "flex-col"
    ]

    width_classes = @collapsed ? ["w-16"] : ["w-80"]
    
    (base_classes + width_classes).join(" ")
  end

  def header_class
    [
      "flex",
      "items-center",
      "justify-between",
      "p-4",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800"
    ].join(" ")
  end

  def content_class
    [
      "flex-1",
      "overflow-y-auto",
      "scrollbar-thin",
      "scrollbar-track-creative-neutral-100",
      "scrollbar-thumb-creative-neutral-300",
      "dark:scrollbar-track-creative-neutral-800",
      "dark:scrollbar-thumb-creative-neutral-600"
    ].join(" ")
  end

  def section_class
    [
      "px-4",
      "py-3",
      "border-b",
      "border-creative-neutral-100",
      "dark:border-creative-neutral-800"
    ].join(" ")
  end

  def section_header_class
    [
      "flex",
      "items-center",
      "justify-between",
      "mb-3",
      "text-xs",
      "font-semibold",
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400",
      "uppercase",
      "tracking-wider"
    ].join(" ")
  end

  def nav_item_class(active: false)
    base_classes = [
      "flex",
      "items-center",
      "w-full",
      "px-3",
      "py-2",
      "mb-1",
      "text-sm",
      "font-medium",
      "rounded-lg",
      "transition-all",
      "duration-200",
      "group"
    ]

    if active
      base_classes += [
        "bg-creative-primary-100",
        "dark:bg-creative-primary-900/30",
        "text-creative-primary-800",
        "dark:text-creative-primary-200",
        "shadow-creative-sm"
      ]
    else
      base_classes += [
        "text-creative-neutral-700",
        "dark:text-creative-neutral-300",
        "hover:bg-creative-neutral-100",
        "dark:hover:bg-creative-neutral-800",
        "hover:text-creative-neutral-900",
        "dark:hover:text-creative-neutral-100"
      ]
    end

    base_classes.join(" ")
  end

  def icon_class
    size_class = @collapsed ? "w-5 h-5" : "w-4 h-4"
    margin_class = @collapsed ? "" : "mr-3"
    
    [
      size_class,
      margin_class,
      "flex-shrink-0",
      "transition-colors",
      "duration-200"
    ].join(" ")
  end

  def badge_class
    [
      "ml-auto",
      "px-2",
      "py-0.5",
      "text-xs",
      "font-medium",
      "rounded-full",
      "bg-creative-primary-100",
      "dark:bg-creative-primary-900/30",
      "text-creative-primary-700",
      "dark:text-creative-primary-300"
    ].join(" ")
  end

  def recent_documents
    @recent_documents ||= current_user.documents
                                      .order(updated_at: :desc)
                                      .limit(10)
                                      .includes(:user)
  end

  def recent_context_items
    return [] unless current_document

    @recent_context_items ||= current_document.context_items
                                              .order(updated_at: :desc)
                                              .limit(8)
  end

  def active_sub_agents
    return [] unless current_document

    @active_sub_agents ||= current_document.sub_agents
                                           .where.not(status: 'completed')
                                           .order(updated_at: :desc)
  end

  def navigation_items
    items = [
      {
        label: "Dashboard",
        path: root_path,
        icon: "home",
        active: current_page?(root_path)
      },
      {
        label: "Documents",
        path: documents_path,
        icon: "document-text",
        active: controller_name == "documents",
        badge: recent_documents.count > 0 ? recent_documents.count : nil
      }
    ]

    if current_document
      items += [
        {
          label: "Context Items",
          path: document_context_items_path(current_document),
          icon: "collection",
          active: controller_name == "context_items",
          badge: recent_context_items.count
        },
        {
          label: "Sub-Agents",
          path: document_sub_agents_path(current_document),
          icon: "users",
          active: controller_name == "sub_agents",
          badge: active_sub_agents.count > 0 ? active_sub_agents.count : nil
        }
      ]
    end

    items
  end

  def sidebar_footer_class
    [
      "p-4",
      "border-t",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800"
    ].join(" ")
  end

  def user_menu_class
    [
      "flex",
      "items-center",
      "w-full",
      "p-2",
      "rounded-lg",
      "hover:bg-creative-neutral-100",
      "dark:hover:bg-creative-neutral-700",
      "transition-colors",
      "duration-200",
      "group"
    ].join(" ")
  end

  def toggle_button_class
    [
      "p-2",
      "rounded-lg",
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400",
      "hover:bg-creative-neutral-100",
      "dark:hover:bg-creative-neutral-700",
      "hover:text-creative-neutral-900",
      "dark:hover:text-creative-neutral-100",
      "transition-all",
      "duration-200"
    ].join(" ")
  end

  def document_item_class(document)
    active = current_document&.id == document.id
    
    base_classes = [
      "flex",
      "items-center",
      "w-full",
      "px-3",
      "py-1.5",
      "mb-1",
      "text-sm",
      "rounded-md",
      "transition-all",
      "duration-200",
      "group"
    ]

    if active
      base_classes += [
        "bg-creative-primary-50",
        "dark:bg-creative-primary-900/20",
        "text-creative-primary-700",
        "dark:text-creative-primary-300"
      ]
    else
      base_classes += [
        "text-creative-neutral-600",
        "dark:text-creative-neutral-400",
        "hover:bg-creative-neutral-50",
        "dark:hover:bg-creative-neutral-800",
        "hover:text-creative-neutral-900",
        "dark:hover:text-creative-neutral-100"
      ]
    end

    base_classes.join(" ")
  end

  def collapsed?
    @collapsed
  end

  def show_labels?
    !collapsed?
  end
end