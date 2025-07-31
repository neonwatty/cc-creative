# frozen_string_literal: true

class ThemeToggleComponent < ViewComponent::Base
  include ActionView::Helpers::TagHelper
  
  def initialize(variant: :default, size: :md, position: :inline, classes: nil)
    @variant = variant
    @size = size
    @position = position
    @classes = classes
  end

  private

  attr_reader :variant, :size, :position, :classes

  def wrapper_classes
    base_classes = ["theme-toggle-wrapper"]
    
    case position
    when :fixed_top_right
      base_classes << "fixed top-4 right-4 z-50"
    when :fixed_bottom_right
      base_classes << "fixed bottom-4 right-4 z-50"
    when :inline
      base_classes << "inline-flex"
    end

    base_classes.join(" ")
  end

  def toggle_classes
    base_classes = [
      "relative inline-flex items-center justify-center",
      "transition-all duration-300 ease-creative",
      "rounded-full border-2 border-transparent",
      "focus:outline-none focus:ring-2 focus:ring-offset-2",
      "focus:ring-creative-primary-500"
    ]

    # Size variations
    case size
    when :sm
      base_classes << "w-8 h-8 p-1.5"
    when :md
      base_classes << "w-10 h-10 p-2"
    when :lg
      base_classes << "w-12 h-12 p-2.5"
    end

    # Variant styles
    case variant
    when :default
      base_classes << [
        "bg-creative-neutral-200 text-creative-neutral-600",
        "hover:bg-creative-neutral-300 hover:text-creative-neutral-800",
        "dark:bg-creative-neutral-700 dark:text-creative-neutral-300",
        "dark:hover:bg-creative-neutral-600 dark:hover:text-creative-neutral-100"
      ]
    when :primary
      base_classes << [
        "bg-creative-primary-100 text-creative-primary-600",
        "hover:bg-creative-primary-200 hover:text-creative-primary-700",
        "dark:bg-creative-primary-900/30 dark:text-creative-primary-300",
        "dark:hover:bg-creative-primary-800/30 dark:hover:text-creative-primary-200"
      ]
    when :outline
      base_classes << [
        "border-creative-neutral-300 text-creative-neutral-600",
        "hover:border-creative-neutral-400 hover:bg-creative-neutral-50",
        "dark:border-creative-neutral-600 dark:text-creative-neutral-400",
        "dark:hover:border-creative-neutral-500 dark:hover:bg-creative-neutral-800"
      ]
    when :ghost
      base_classes << [
        "text-creative-neutral-600 hover:bg-creative-neutral-100",
        "dark:text-creative-neutral-400 dark:hover:bg-creative-neutral-800"
      ]
    end

    # Add custom classes
    base_classes << classes if classes

    base_classes.flatten.join(" ")
  end

  def controller_data
    {
      controller: "theme",
      theme_storage_key_value: "creative-theme"
    }
  end
end