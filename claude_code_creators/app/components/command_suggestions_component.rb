# frozen_string_literal: true

class CommandSuggestionsComponent < ViewComponent::Base
  def initialize(document:, user:, position:, filter: "", selected_index: -1, limit: nil, mobile: false)
    @document = document
    @user = user
    @position = position
    @filter = filter.to_s.downcase
    @selected_index = selected_index
    @limit = limit
    @mobile = mobile
  end

  private

  attr_reader :document, :user, :position, :filter, :selected_index, :limit, :mobile

  # Core command definitions that match the JavaScript controller
  def available_commands
    @available_commands ||= [
      {
        command: "save",
        description: "Save document to various formats",
        parameters: [ { name: "name", required: false } ],
        category: "context",
        icon: "save-icon"
      },
      {
        command: "load",
        description: "Load external content",
        parameters: [ { name: "name", required: true } ],
        category: "context",
        icon: "load-icon"
      },
      {
        command: "compact",
        description: "Compact Claude context using AI summarization",
        parameters: [ { name: "mode", required: false } ],
        category: "optimization",
        icon: "compact-icon"
      },
      {
        command: "clear",
        description: "Clear context or document content",
        parameters: [ { name: "target", required: false } ],
        category: "cleanup",
        icon: "clear-icon"
      },
      {
        command: "include",
        description: "Include file content in current context",
        parameters: [
          { name: "file", required: true },
          { name: "format", required: false }
        ],
        category: "content",
        icon: "include-icon"
      },
      {
        command: "snippet",
        description: "Save selected content as reusable snippet",
        parameters: [ { name: "name", required: false } ],
        category: "content",
        icon: "snippet-icon"
      }
    ]
  end

  def filtered_commands
    return [] if document.nil?

    commands = available_commands.select { |cmd| command_allowed?(cmd[:command]) }

    if filter.present?
      commands = commands.select { |cmd| cmd[:command].downcase.include?(filter) }
    end

    commands = commands.first(limit) if limit.present?
    commands
  end

  def command_allowed?(command)
    return true unless user.present?

    # Guest users have restricted access
    if user.role.to_s == "guest"
      return false if %w[clear].include?(command)
    end

    # For now, allow all other commands for testing
    # TODO: Implement proper Pundit policy checks
    true
  end

  def dropdown_style
    styles = []
    styles << "left: #{position[:x]}px" if position[:x]
    styles << "top: #{position[:y]}px" if position[:y]
    styles.join("; ")
  end

  def dropdown_classes
    classes = [ "command-suggestions-dropdown", "fade-in" ]
    classes << "mobile" if mobile
    classes << "position-adjusted" if position_adjusted?
    classes.join(" ")
  end

  def position_adjusted?
    position[:x].to_i > 1000 # Viewport boundary check
  end

  def command_item_classes(index)
    classes = [ "command-item", "interactive" ]
    classes << "mobile-friendly" if mobile
    classes << "selected" if index == selected_index
    classes.join(" ")
  end

  def parameter_classes(parameter)
    classes = [ "parameter" ]
    classes << (parameter[:required] ? "required" : "optional")
    classes.join(" ")
  end

  def category_classes(category)
    [ "command-category", category ].join(" ")
  end

  def context_hints_for_command(command)
    return [] unless document.present?

    case command
    when "load"
      saved_contexts
    when "include"
      available_files
    else
      []
    end
  end

  def saved_contexts
    return [] unless document.context_items.present?

    document.context_items
      .where(item_type: "saved_context")
      .limit(3)
      .pluck(:title)
  end

  def available_files
    return [] unless document.context_items.present?

    document.context_items
      .where(item_type: "file")
      .limit(3)
      .pluck(:title)
  end

  def claude_context_available?
    return false unless document.present?

    document.claude_contexts.exists?
  end

  def command_has_context_status?(command)
    %w[compact clear].include?(command) && claude_context_available?
  end

  def format_parameter_display(parameters)
    return "" if parameters.empty?

    param_strings = parameters.map do |param|
      if param[:required]
        param[:name]
      else
        "[#{param[:name]}]"
      end
    end

    param_strings.join(" ")
  end

  def command_option_id(index)
    "command-option-#{index}"
  end

  def command_description_id(index)
    "command-description-#{index}"
  end

  def error_state?
    document.nil?
  end

  def permission_error?
    return false unless defined?(Pundit)

    begin
      available_commands.each do |cmd|
        Pundit.policy(user, document).update?
      end
      false
    rescue Pundit::NotAuthorizedError
      true
    end
  end

  def show_empty_state?
    !error_state? && !permission_error? && filtered_commands.empty?
  end

  def stimulus_data_attributes
    {
      controller: "command-suggestions",
      "command-suggestions-target": "dropdown",
      "command-suggestions-document-id-value": document&.id,
      role: "listbox",
      "aria-label": "Available slash commands",
      "aria-live": "polite"
    }
  end

  def command_action_attributes(command)
    {
      "data-action": "click->command-suggestions#selectCommand mouseenter->command-suggestions#highlightCommand mouseleave->command-suggestions#unhighlightCommand",
      "data-command": command,
      role: "option",
      tabindex: "-1",
      "aria-selected": "false"
    }
  end
end
