# frozen_string_literal: true

class PluginInstallationModalComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper

  def initialize(user:, plugin_id: nil, options: {})
    @user = user
    @plugin_id = plugin_id
    @options = options
    @show_permissions = options.fetch(:show_permissions, true)
    @show_preview = options.fetch(:show_preview, true)
    @require_confirmation = options.fetch(:require_confirmation, true)
    @allow_beta = options.fetch(:allow_beta, false)
    @installation_mode = options.fetch(:installation_mode, "full") # full, minimal, custom
  end

  private

  attr_reader :user, :plugin_id, :options, :show_permissions, :show_preview,
              :require_confirmation, :allow_beta, :installation_mode

  def modal_class
    [
      "plugin-installation-modal",
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

  def modal_visible_class
    [
      "opacity-100",
      "visible"
    ].join(" ")
  end

  def content_class
    [
      "modal-content",
      "bg-white",
      "dark:bg-creative-neutral-900",
      "rounded-2xl",
      "shadow-creative-2xl",
      "w-full",
      "max-w-3xl",
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
      "modal-header",
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

  def body_class
    [
      "modal-body",
      "flex-1",
      "overflow-y-auto",
      "scrollbar-thin",
      "scrollbar-thumb-creative-neutral-300",
      "dark:scrollbar-thumb-creative-neutral-600",
      "scrollbar-track-transparent"
    ].join(" ")
  end

  def footer_class
    [
      "modal-footer",
      "flex",
      "items-center",
      "justify-between",
      "p-6",
      "bg-creative-neutral-50",
      "dark:bg-creative-neutral-800",
      "border-t",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700"
    ].join(" ")
  end

  def plugin_info_class
    [
      "plugin-info",
      "p-6",
      "border-b",
      "border-creative-neutral-200",
      "dark:border-creative-neutral-700"
    ].join(" ")
  end

  def plugin_icon_class
    [
      "plugin-icon",
      "w-20",
      "h-20",
      "rounded-2xl",
      "bg-gradient-to-br",
      "from-creative-primary-500",
      "via-creative-primary-600",
      "to-creative-secondary-600",
      "flex",
      "items-center",
      "justify-center",
      "text-white",
      "text-3xl",
      "font-bold",
      "shadow-creative-lg",
      "flex-shrink-0",
      "ring-4",
      "ring-creative-primary-100",
      "dark:ring-creative-primary-900/30"
    ].join(" ")
  end

  def modal_data_attributes
    {
      controller: "plugin-installation-modal",
      "plugin_installation_modal_user_id_value": user.id,
      "plugin_installation_modal_plugin_id_value": plugin_id,
      "plugin_installation_modal_show_permissions_value": show_permissions,
      "plugin_installation_modal_show_preview_value": show_preview,
      "plugin_installation_modal_require_confirmation_value": require_confirmation,
      "plugin_installation_modal_installation_mode_value": installation_mode,
      action: [
        "click->plugin-installation-modal#handleBackdropClick",
        "keydown->plugin-installation-modal#handleKeydown"
      ].join(" ")
    }
  end

  def sample_plugin
    {
      id: plugin_id || 1,
      name: "AI Code Assistant",
      author: "DevTools Inc",
      version: "2.1.0",
      description: "Intelligent code completion and refactoring suggestions powered by advanced AI models.",
      icon: "🤖",
      size: "15.2 MB",
      rating: 4.8,
      downloads: "50k+"
    }
  end
end