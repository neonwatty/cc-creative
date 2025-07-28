# frozen_string_literal: true

class DocumentLayoutComponent < ViewComponent::Base
  def initialize(current_user:, current_document: nil, options: {})
    @current_user = current_user
    @current_document = current_document
    @options = options
    @layout_type = options.fetch(:layout_type, :default) # :default, :focused, :minimal
    @sidebar_collapsed = options.fetch(:sidebar_collapsed, false)
    @show_toolbar = options.fetch(:show_toolbar, true)
    @enable_collaboration = options.fetch(:enable_collaboration, false)
    @show_onboarding = options.fetch(:show_onboarding, false)
  end

  private

  attr_reader :current_user, :current_document, :options

  def layout_class
    base_classes = [
      "document-layout",
      "min-h-screen",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-900",
      "transition-colors",
      "duration-300"
    ]

    case @layout_type
    when :focused
      base_classes += ["bg-white", "dark:bg-creative-neutral-800"]
    when :minimal
      base_classes += ["bg-creative-neutral-25", "dark:bg-creative-neutral-950"]
    end

    base_classes.join(" ")
  end

  def container_class
    base_classes = [
      "flex",
      "h-screen",
      "overflow-hidden"
    ]

    case @layout_type
    when :focused
      base_classes += ["max-w-none"]
    when :minimal
      base_classes += ["max-w-4xl", "mx-auto"]
    else
      base_classes += ["max-w-none"]
    end

    base_classes.join(" ")
  end

  def main_content_class
    base_classes = [
      "flex-1",
      "flex",
      "flex-col",
      "overflow-hidden",
      "transition-all",
      "duration-300",
      "ease-creative"
    ]

    # Adjust margins based on sidebar state
    if @sidebar_collapsed
      base_classes += ["ml-16"]
    else
      base_classes += ["ml-80"]
    end

    # Layout type adjustments
    case @layout_type
    when :focused
      base_classes += ["ml-0"] # Override sidebar margins for focused mode
    when :minimal
      base_classes += ["mx-8"]
    end

    base_classes.join(" ")
  end

  def toolbar_class
    base_classes = [
      "flex",
      "items-center",
      "justify-between",
      "px-6",
      "py-4",
      "bg-white",
      "dark:bg-creative-neutral-800",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700",
      "shadow-creative-sm",
      "dark:shadow-creative-dark-sm"
    ]

    unless @show_toolbar
      base_classes += ["hidden"]
    end

    base_classes.join(" ")
  end

  def content_area_class
    base_classes = [
      "flex-1",
      "overflow-auto",
      "p-6"
    ]

    case @layout_type
    when :focused
      base_classes += ["p-8", "max-w-4xl", "mx-auto"]
    when :minimal
      base_classes += ["p-4", "max-w-3xl", "mx-auto"]
    end

    base_classes.join(" ")
  end

  def breadcrumb_class
    [
      "flex",
      "items-center",
      "space-x-2",
      "text-sm",
      "text-creative-neutral-600",
      "dark:text-creative-neutral-400"
    ].join(" ")
  end

  def toolbar_actions_class
    [
      "flex",
      "items-center",
      "space-x-3"
    ].join(" ")
  end

  def should_show_sidebar?
    @layout_type != :focused && @layout_type != :minimal
  end

  def should_show_onboarding?
    @show_onboarding && current_user && should_show_onboarding_for_user?
  end

  def should_show_onboarding_for_user?
    # Check if user should see onboarding
    return false if current_user.attributes.key?('onboarding_completed_at') && current_user.onboarding_completed_at.present?
    return true if current_user.created_at > 24.hours.ago
    false
  end

  def breadcrumbs
    crumbs = [
      { label: "Home", path: root_path }
    ]

    if current_document
      crumbs << { label: "Documents", path: documents_path }
      crumbs << { label: current_document.title, path: document_path(current_document), active: true }
    else
      case controller_name
      when "documents"
        crumbs << { label: "Documents", path: documents_path, active: true }
      when "context_items"
        crumbs << { label: "Context Items", path: context_items_path, active: true }
      when "sub_agents"
        crumbs << { label: "Sub-Agents", path: sub_agents_path, active: true }
      end
    end

    crumbs
  end

  def toolbar_title
    if current_document
      current_document.title
    else
      case controller_name
      when "documents"
        case action_name
        when "index"
          "All Documents"
        when "new"
          "New Document"
        when "edit"
          "Edit Document"
        else
          "Documents"
        end
      when "context_items"
        "Context Items"
      when "sub_agents"
        "Sub-Agents"
      else
        "Claude Code Creators"
      end
    end
  end

  def layout_data_attributes
    {
      controller: "document-layout",
      "document-layout-sidebar-collapsed-value" => @sidebar_collapsed,
      "document-layout-layout-type-value" => @layout_type,
      "document-layout-enable-collaboration-value" => @enable_collaboration
    }
  end

  def floating_action_button_class
    base_classes = [
      "fixed",
      "bottom-6",
      "right-6",
      "w-14",
      "h-14",
      "bg-creative-primary-500",
      "hover:bg-creative-primary-600",
      "text-white",
      "rounded-full",
      "shadow-creative-lg",
      "dark:shadow-creative-dark-lg",
      "hover:shadow-creative-xl",
      "dark:hover:shadow-creative-dark-xl",
      "flex",
      "items-center",
      "justify-center",
      "transition-all",
      "duration-200",
      "hover:scale-110",
      "z-40"
    ]

    # Hide on minimal layout
    if @layout_type == :minimal
      base_classes += ["hidden"]
    end

    base_classes.join(" ")
  end

  def mobile_menu_class
    [
      "fixed",
      "inset-0",
      "z-50",
      "lg:hidden",
      "transition-transform",
      "duration-300",
      "transform",
      "translate-x-full"
    ].join(" ")
  end

  def mobile_overlay_class
    [
      "fixed",
      "inset-0",
      "bg-creative-neutral-900/50",
      "backdrop-blur-sm",
      "z-40",
      "lg:hidden",
      "opacity-0",
      "invisible",
      "transition-all",
      "duration-300"
    ].join(" ")
  end

  def status_indicator
    if current_document
      if @enable_collaboration
        {
          color: "creative-secondary-500",
          text: "Collaborative",
          pulse: true
        }
      else
        {
          color: "creative-primary-500", 
          text: "Editing",
          pulse: false
        }
      end
    else
      {
        color: "creative-neutral-400",
        text: "Ready",
        pulse: false
      }
    end
  end

  def is_mobile_layout?
    # This would need to be determined by JavaScript or CSS classes
    # For now, we'll use CSS to handle mobile responsive behavior
    false
  end

  def collaboration_enabled?
    @enable_collaboration
  end
end