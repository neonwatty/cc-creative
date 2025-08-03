class CommandParserService
  class UnknownCommandError < StandardError; end

  COMMAND_REGISTRY = {
    "save" => {
      description: "Save document to various formats",
      parameters: [ "name" ],
      category: :context,
      required_params: 0,
      max_params: 1,
      permission_level: :user
    },
    "load" => {
      description: "Load saved context into current session",
      parameters: [ "name" ],
      category: :context,
      required_params: 1,
      max_params: 1,
      permission_level: :user
    },
    "compact" => {
      description: "Compact Claude context using AI summarization",
      parameters: [ "mode" ],
      category: :optimization,
      required_params: 0,
      max_params: 1,
      permission_level: :user
    },
    "clear" => {
      description: "Clear context or document content",
      parameters: [ "target" ],
      category: :cleanup,
      required_params: 0,
      max_params: 1,
      permission_level: :user,
      valid_values: [ "context", "document" ]
    },
    "include" => {
      description: "Include file content in current context",
      parameters: [ "file", "format" ],
      category: :content,
      required_params: 1,
      max_params: 2,
      permission_level: :user
    },
    "snippet" => {
      description: "Save selected content as reusable snippet",
      parameters: [ "name" ],
      category: :content,
      required_params: 0,
      max_params: 1,
      permission_level: :user
    },
    "review" => {
      description: "AI-powered code review with comprehensive analysis",
      parameters: [ "mode", "focus" ],
      category: :ai_review,
      required_params: 0,
      max_params: 2,
      permission_level: :user,
      valid_values: [ "quick", "thorough", "security", "performance", "style" ]
    },
    "suggest" => {
      description: "Get AI suggestions for improvements and optimizations",
      parameters: [ "type", "context" ],
      category: :ai_review,
      required_params: 0,
      max_params: 2,
      permission_level: :user,
      valid_values: [ "refactor", "optimize", "enhance", "fix", "extend" ]
    },
    "critique" => {
      description: "Critical analysis of code architecture and design patterns",
      parameters: [ "aspect", "level" ],
      category: :ai_review,
      required_params: 0,
      max_params: 2,
      permission_level: :user,
      valid_values: [ "architecture", "patterns", "maintainability", "scalability", "testability" ]
    }
  }.freeze

  def initialize(document, user)
    @document = document
    @user = user
  end

  # Class methods for command registry
  def self.registered_commands
    COMMAND_REGISTRY.keys
  end

  def self.command_metadata(command)
    raise UnknownCommandError, "Unknown command: #{command}" unless COMMAND_REGISTRY.key?(command)

    COMMAND_REGISTRY[command]
  end

  # Instance methods for parsing
  def parse(input)
    result = {
      command: nil,
      parameters: [],
      raw_input: input,
      timestamp: Time.current,
      error: nil
    }

    # Check if input starts with slash
    unless input.start_with?("/")
      result[:error] = "Input is not a valid slash command"
      return result
    end

    # Handle empty command
    if input == "/"
      result[:error] = "Empty command"
      return result
    end

    # Remove leading slash and parse
    command_string = input[1..]

    begin
      parsed = parse_command_string(command_string)
      result[:command] = parsed[:command]
      result[:parameters] = parsed[:parameters]
    rescue StandardError => e
      result[:error] = "malformed command: #{e.message}"
    end

    # Validate command if parsed successfully
    if result[:command] && result[:error].nil?
      validation_result = validate_command_and_params(result[:command], result[:parameters])
      result[:error] = validation_result[:error] unless validation_result[:valid]
    end

    result
  end

  def valid_command?(command)
    COMMAND_REGISTRY.key?(command)
  end

  def valid_parameters?(command, parameters)
    return false unless valid_command?(command)

    metadata = COMMAND_REGISTRY[command]
    param_count = parameters.length

    # Check parameter count
    return false unless param_count >= metadata[:required_params] && param_count <= metadata[:max_params]

    # Check valid values if specified
    if metadata[:valid_values] && parameters.any?
      return parameters.all? { |param| metadata[:valid_values].include?(param) }
    end

    true
  end

  def suggest_commands(prefix = "", limit: 10)
    if prefix.blank?
      COMMAND_REGISTRY.keys.first(limit)
    else
      COMMAND_REGISTRY.keys
                     .select { |cmd| cmd.start_with?(prefix.downcase) }
                     .first(limit)
    end
  end

  def suggest_commands_with_metadata(prefix = "", limit: 10)
    suggest_commands(prefix, limit: limit).map do |command|
      {
        command: command,
        description: COMMAND_REGISTRY[command][:description],
        parameters: COMMAND_REGISTRY[command][:parameters],
        category: COMMAND_REGISTRY[command][:category]
      }
    end
  end

  def validate_permissions(command)
    return { allowed: false, error: "Unknown command" } unless valid_command?(command)

    metadata = COMMAND_REGISTRY[command]
    required_level = metadata[:permission_level]

    case required_level
    when :admin
      allowed = @user.admin?
      error = allowed ? nil : "Insufficient permissions: admin role required"
    when :editor
      allowed = @user.admin? || @user.editor?
      error = allowed ? nil : "Insufficient permissions: editor or admin role required"
    when :user
      allowed = @user.user? || @user.editor? || @user.admin?
      error = allowed ? nil : "insufficient permissions: user role or higher required"
    else # guest or other
      allowed = true
      error = nil
    end

    { allowed: allowed, error: error }
  end

  def validate_document_access(document)
    if document.user_id == @user.id
      { allowed: true, error: nil }
    else
      { allowed: false, error: "access denied: you don't have permission to access this document" }
    end
  end

  def build_execution_context(command, parameters)
    {
      document: @document,
      user: @user,
      command: command,
      parameters: parameters,
      timestamp: Time.current,
      session_id: generate_session_id,
      claude_context: build_claude_context
    }
  end

  def validate_command_and_params(command, parameters)
    unless valid_command?(command)
      similar_commands = suggest_similar_commands(command)
      suggestion_text = similar_commands.any? ? ". Did you mean: #{similar_commands.join(', ')}?" : ""
      return { valid: false, error: "Unknown command: #{command}#{suggestion_text}" }
    end

    metadata = COMMAND_REGISTRY[command]

    # Check required parameters first
    if parameters.length < metadata[:required_params]
      return { valid: false, error: "Missing required parameter for #{command} command" }
    end

    # Check max parameters
    if parameters.length > metadata[:max_params]
      return { valid: false, error: "Too many parameters for #{command} command" }
    end

    # Check valid values if specified
    if metadata[:valid_values] && parameters.any?
      invalid_params = parameters.reject { |param| metadata[:valid_values].include?(param) }
      if invalid_params.any?
        return { valid: false, error: "Invalid parameter value(s): #{invalid_params.join(', ')}" }
      end
    end

    # Check permissions
    permission_result = validate_permissions(command)
    return { valid: false, error: permission_result[:error] } unless permission_result[:allowed]

    { valid: true, error: nil }
  end

  def get_command_suggestions(filter: "", context: {})
    filtered_commands = if filter.empty?
      COMMAND_REGISTRY.keys
    else
      COMMAND_REGISTRY.keys.select { |cmd| cmd.include?(filter.downcase) }
    end

    suggestions = filtered_commands.map do |command|
      metadata = COMMAND_REGISTRY[command]

      # Check if user has permission for this command
      permission_result = validate_permissions(command)
      next unless permission_result[:allowed]

      base_suggestion = {
        command: command,
        description: metadata[:description],
        examples: metadata[:examples] || [],
        category: metadata[:category] || "general",
        required_params: metadata[:required_params] || 0,
        max_params: metadata[:max_params] || 0,
        valid_values: metadata[:valid_values] || [],
        match_score: calculate_match_score(command, filter)
      }

      # Add context-aware suggestions for certain commands
      base_suggestion = add_context_suggestions(base_suggestion, command)
      
      base_suggestion
    end.compact

    # Sort by match score (higher is better)
    suggestions.sort_by { |s| -s[:match_score] }
  end

  private

  def add_context_suggestions(suggestion, command)
    case command
    when "load"
      # Add saved context items as examples for load command
      context_items = @document.context_items.where(item_type: "saved_context").limit(5)
      if context_items.any?
        suggestion[:examples] = context_items.pluck(:title)
        suggestion[:description] += " (Available: #{context_items.pluck(:title).join(', ')})"
      end
    when "include"
      # Add file context items as examples for include command
      file_items = @document.context_items.where(item_type: "file").limit(5)
      if file_items.any?
        suggestion[:examples] = file_items.pluck(:title)
        suggestion[:description] += " (Available: #{file_items.pluck(:title).join(', ')})"
      end
    end
    
    suggestion
  end

  def parse_command_string(command_string)
    # Use shellwords to properly handle quoted parameters
    require "shellwords"

    parts = Shellwords.shellsplit(command_string)

    {
      command: parts.first&.downcase,
      parameters: parts[1..] || []
    }
  rescue ArgumentError => e
    raise StandardError, e.message
  end

  def suggest_similar_commands(command, threshold: 0.6)
    require "levenshtein"

    COMMAND_REGISTRY.keys.select do |registered_command|
      distance = Levenshtein.distance(command, registered_command)
      similarity = 1.0 - (distance.to_f / [ command.length, registered_command.length ].max)
      similarity >= threshold
    end.first(3)
  rescue LoadError
    # Fallback if levenshtein gem not available
    COMMAND_REGISTRY.keys.select do |registered_command|
      command.include?(registered_command[0..2]) || registered_command.include?(command[0..2])
    end.first(3)
  end

  def generate_session_id
    "cmd_#{SecureRandom.hex(8)}"
  end

  def build_claude_context
    latest_context = @document.claude_contexts
                              .where(user: @user)
                              .order(created_at: :desc)
                              .first

    return {} unless latest_context

    # Try context_data first (new field), then content (existing field)
    context_data = latest_context.context_data.presence || latest_context.content
    return {} if context_data.blank?

    case context_data
    when String
      begin
        JSON.parse(context_data)
      rescue JSON::ParserError
        {}
      end
    when Hash
      context_data
    else
      {}
    end
  end

  def calculate_match_score(command, filter)
    return 1.0 if filter.empty?

    filter_downcase = filter.downcase
    command_downcase = command.downcase

    # Exact match gets highest score
    return 10.0 if command_downcase == filter_downcase

    # Starts with filter gets high score
    return 8.0 if command_downcase.start_with?(filter_downcase)

    # Contains filter gets medium score
    return 5.0 if command_downcase.include?(filter_downcase)

    # Default score for partial matches
    1.0
  end
end
