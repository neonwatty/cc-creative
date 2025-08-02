class CommandExecutionService
  class CommandExecutionError < StandardError; end

  def initialize(document, user)
    @document = document
    @user = user
  end

  def execute(command, parameters, options = {})
    start_time = Time.current

    begin
      # Validate command exists
      unless CommandParserService.registered_commands.include?(command)
        similar_commands = suggest_similar_commands(command)
        return error_result(command, parameters, start_time,
                          "Unknown command: #{command}", suggestions: similar_commands)
      end

      # Validate permissions
      parser = CommandParserService.new(@document, @user)
      permission_result = parser.validate_permissions(command)
      unless permission_result[:allowed]
        return error_result(command, parameters, start_time, permission_result[:error])
      end

      # Validate document access
      access_result = parser.validate_document_access(@document)
      unless access_result[:allowed]
        return error_result(command, parameters, start_time, access_result[:error])
      end

      # Validate command parameters
      validation_result = parser.validate_command_and_params(command, parameters)
      unless validation_result[:valid]
        return error_result(command, parameters, start_time, validation_result[:error])
      end

      # Execute the specific command
      result = case command
      when "save"
                 execute_save_command(parameters, options)
      when "load"
                 execute_load_command(parameters, options)
      when "compact"
                 execute_compact_command(parameters, options)
      when "clear"
                 execute_clear_command(parameters, options)
      when "include"
                 execute_include_command(parameters, options)
      when "snippet"
                 execute_snippet_command(parameters, options)
      when "review"
                 execute_review_command(parameters, options)
      when "suggest"
                 execute_suggest_command(parameters, options)
      when "critique"
                 execute_critique_command(parameters, options)
      else
                 raise CommandExecutionError, "Command handler not implemented: #{command}"
      end

      # Check if the command returned an error
      if result[:error]
        execution_time = Time.current - start_time
        return error_result(command, parameters, start_time, result[:error], result.except(:error))
      end

      # Add timing and success info
      execution_time = Time.current - start_time
      result.merge!(
        success: true,
        execution_time: execution_time,
        timestamp: Time.current
      )

      # Log the command execution
      log_command_execution(command, parameters, execution_time, "success", result)

      result

    rescue StandardError => e
      execution_time = Time.current - start_time
      error_result(command, parameters, start_time, e.message, error_type: e.class.name)
    end
  end

  private

  # Save Command Implementation
  def execute_save_command(parameters, options)
    context_name = parameters.first || generate_context_name

    # Get current document content and Claude context
    document_content = @document.content.to_plain_text
    claude_context = build_current_claude_context

    # Check if context already exists
    existing_item = @document.context_items
                             .saved_contexts
                             .find_by(title: context_name, user: @user)

    if existing_item
      # Update existing context
      existing_item.update!(
        content: build_save_content(document_content, claude_context),
        updated_at: Time.current
      )

      # Update document timestamp
      @document.touch

      {
        context_name: context_name,
        context_item_id: existing_item.id,
        overwritten: true
      }
    else
      # Create new context item
      context_item = @document.context_items.create!(
        title: context_name,
        content: build_save_content(document_content, claude_context),
        item_type: "saved_context",
        user: @user
      )

      # Update document timestamp
      @document.touch

      {
        context_name: context_name,
        context_item_id: context_item.id,
        overwritten: false
      }
    end
  end

  # Load Command Implementation
  def execute_load_command(parameters, options)
    context_name = parameters.first
    return { error: "required parameter missing for load command" } if context_name.blank?

    # Find exact match first
    context_item = @document.context_items
                            .saved_contexts
                            .find_by(title: context_name, user: @user)

    # If no exact match, try partial matches
    if context_item.nil?
      partial_matches = @document.context_items
                                 .saved_contexts
                                 .where(user: @user)
                                 .where("title LIKE ?", "%#{context_name}%")

      if partial_matches.count == 1
        context_item = partial_matches.first
      elsif partial_matches.count > 1
        return {
          error: "Ambiguous context name: #{context_name}",
          matches: partial_matches.pluck(:title)
        }
      else
        similar_names = suggest_similar_context_names(context_name)
        return {
          error: "Context '#{context_name}' not found",
          suggestions: similar_names
        }
      end
    end

    # Load the context
    update_claude_context_with_loaded_content(context_item.content)

    {
      context_name: context_item.title,
      loaded_content: context_item.content,
      claude_context_updated: true
    }
  end

  # Compact Command Implementation
  def execute_compact_command(parameters, options)
    mode = parameters.first || "normal"
    aggressive = mode == "aggressive"

    # Get current Claude context
    claude_context = @document.claude_contexts
                              .where(user: @user)
                              .order(created_at: :desc)
                              .first

    # If no context exists, return error as expected by tests
    if claude_context.nil?
      return { error: "No context to compact" }
    end

    context_data = parse_context_data(claude_context.context_data)
    messages = context_data["messages"] || []

    # Return error for empty messages as expected by tests
    if messages.empty?
      return { error: "No context to compact" }
    end

    original_count = messages.length

    # Use Claude service to compact the context
    begin
      compact_result = ClaudeService.new.compact_context(messages, aggressive: aggressive)

      # Update the context with compacted messages
      claude_context.update!(
        context_data: { "messages" => compact_result[:compacted_messages] }.to_json,
        updated_at: Time.current
      )

      {
        original_message_count: original_count,
        compacted_message_count: compact_result[:compacted_messages].length,
        compression_ratio: compact_result[:compression_ratio],
        compacted_messages: compact_result[:compacted_messages]
      }
    rescue ClaudeService::APIError => e
      { error: "Claude API error: #{e.message}" }
    rescue Timeout::Error
      { error: "Compact operation timeout" }
    end
  end

  # Clear Command Implementation
  def execute_clear_command(parameters, options)
    target = parameters.first || "context"

    case target
    when "context"
      cleared_count = clear_claude_contexts
      {
        cleared_type: "context",
        cleared_items: cleared_count
      }
    when "document"
      clear_document_content
      {
        cleared_type: "document",
        cleared_items: 1
      }
    else
      { error: "Unknown clear target: #{target}. Use 'context' or 'document'" }
    end
  end

  # Include Command Implementation
  def execute_include_command(parameters, options)
    filename = parameters.first
    format = parameters.second

    return { error: "required parameter missing for include command" } if filename.blank?

    # Find the file context item
    file_item = @document.context_items
                         .files
                         .find_by(title: filename, user: @user)

    return { error: "File '#{filename}' not found" } if file_item.nil?

    # Format content if format specified
    content = file_item.content
    if format.present?
      content = format_content(content, format)
    end

    # Add to Claude context
    add_to_claude_context("file_include", {
      filename: filename,
      content: content,
      format: format
    })

    {
      included_file: filename,
      included_content: content,
      format: format,
      formatted_content: content,
      claude_context_updated: true
    }
  end

  # Snippet Command Implementation
  def execute_snippet_command(parameters, options)
    selected_content = options[:selected_content]

    return { error: "No content selected for snippet" } if selected_content.blank?

    snippet_name = parameters.first || generate_snippet_name

    # Create snippet context item
    snippet = @document.context_items.create!(
      title: snippet_name,
      content: selected_content,
      item_type: "snippet",
      user: @user
    )

    {
      snippet_name: snippet_name,
      snippet_id: snippet.id
    }
  end

  # AI Review Commands Implementation
  def execute_review_command(parameters, options)
    selected_content = options[:selected_content]
    mode = parameters.first || "thorough"
    focus = parameters.second

    content_to_review = selected_content.presence || @document.content.to_plain_text

    return { error: "No content available for review" } if content_to_review.blank?

    begin
      claude_service = ClaudeService.new
      review_result = claude_service.analyze_code_for_review(content_to_review, mode: mode, focus: focus)

      # Add review to Claude context
      add_to_claude_context("code_review", {
        content: content_to_review,
        mode: mode,
        focus: focus,
        review: review_result,
        reviewed_at: Time.current.iso8601
      })

      {
        review_mode: mode,
        focus_area: focus,
        analysis: review_result[:analysis],
        suggestions: review_result[:suggestions],
        issues: review_result[:issues],
        score: review_result[:score],
        claude_context_updated: true
      }
    rescue ClaudeService::APIError => e
      { error: "Claude API error: #{e.message}" }
    rescue Timeout::Error
      { error: "Review operation timeout" }
    end
  end

  def execute_suggest_command(parameters, options)
    selected_content = options[:selected_content]
    suggestion_type = parameters.first || "enhance"
    context = parameters.second

    content_to_analyze = selected_content.presence || @document.content.to_plain_text

    return { error: "No content available for suggestions" } if content_to_analyze.blank?

    begin
      claude_service = ClaudeService.new
      suggestion_result = claude_service.generate_code_suggestions(
        content_to_analyze,
        type: suggestion_type,
        context: context
      )

      # Add suggestions to Claude context
      add_to_claude_context("code_suggestions", {
        content: content_to_analyze,
        type: suggestion_type,
        context: context,
        suggestions: suggestion_result,
        generated_at: Time.current.iso8601
      })

      {
        suggestion_type: suggestion_type,
        context_provided: context,
        suggestions: suggestion_result[:suggestions],
        improvements: suggestion_result[:improvements],
        examples: suggestion_result[:examples],
        priority: suggestion_result[:priority],
        claude_context_updated: true
      }
    rescue ClaudeService::APIError => e
      { error: "Claude API error: #{e.message}" }
    rescue Timeout::Error
      { error: "Suggestion generation timeout" }
    end
  end

  def execute_critique_command(parameters, options)
    selected_content = options[:selected_content]
    aspect = parameters.first || "architecture"
    level = parameters.second || "intermediate"

    content_to_critique = selected_content.presence || @document.content.to_plain_text

    return { error: "No content available for critique" } if content_to_critique.blank?

    begin
      claude_service = ClaudeService.new
      critique_result = claude_service.provide_code_critique(
        content_to_critique,
        aspect: aspect,
        level: level
      )

      # Add critique to Claude context
      add_to_claude_context("code_critique", {
        content: content_to_critique,
        aspect: aspect,
        level: level,
        critique: critique_result,
        critiqued_at: Time.current.iso8601
      })

      {
        critique_aspect: aspect,
        analysis_level: level,
        strengths: critique_result[:strengths],
        weaknesses: critique_result[:weaknesses],
        recommendations: critique_result[:recommendations],
        design_patterns: critique_result[:design_patterns],
        best_practices: critique_result[:best_practices],
        claude_context_updated: true
      }
    rescue ClaudeService::APIError => e
      { error: "Claude API error: #{e.message}" }
    rescue Timeout::Error
      { error: "Critique operation timeout" }
    end
  end

  # Helper methods
  def generate_context_name
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    "context_#{timestamp}"
  end

  def generate_snippet_name
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    "snippet_#{timestamp}"
  end

  def build_save_content(document_content, claude_context)
    {
      document_content: document_content,
      claude_context: claude_context,
      saved_at: Time.current.iso8601,
      document_title: @document.title,
      word_count: document_content.split(/\s+/).size
    }.to_json
  end

  def build_current_claude_context
    claude_context = @document.claude_contexts
                              .where(user: @user)
                              .order(created_at: :desc)
                              .first

    return {} unless claude_context

    parse_context_data(claude_context.context_data)
  end

  def parse_context_data(context_data)
    return {} if context_data.blank?

    # Handle both Hash and JSON string formats
    case context_data
    when Hash
      context_data
    when String
      JSON.parse(context_data)
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end

  def update_claude_context_with_loaded_content(content)
    begin
      loaded_data = JSON.parse(content)
      claude_context = loaded_data["claude_context"] || {}

      # Create or update Claude context
      context = @document.claude_contexts.find_or_initialize_by(user: @user)
      context.context_data = claude_context.to_json
      context.context_type = "document"
      context.session_id = "load_#{SecureRandom.hex(8)}"
      context.save!
    rescue JSON::ParserError
      # If content is not JSON, treat as plain text
      add_to_claude_context("loaded_content", { content: content })
    end
  end

  def clear_claude_contexts
    contexts = @document.claude_contexts.where(user: @user)
    count = contexts.count
    contexts.destroy_all
    count
  end

  def clear_document_content
    @document.update!(content: "")
  end

  def format_content(content, format)
    case format.downcase
    when "markdown", "md"
      "```markdown\n#{content}\n```"
    when "ruby", "rb"
      "```ruby\n#{content}\n```"
    when "javascript", "js"
      "```javascript\n#{content}\n```"
    when "html"
      "```html\n#{content}\n```"
    when "css"
      "```css\n#{content}\n```"
    else
      "```#{format}\n#{content}\n```"
    end
  end

  def add_to_claude_context(context_type, data)
    context = @document.claude_contexts.find_or_initialize_by(
      user: @user,
      context_type: context_type
    )

    existing_content = parse_context_data(context.context_data)
    updated_content = existing_content.merge(data)

    context.context_data = updated_content.to_json
    context.session_id ||= "ctx_#{SecureRandom.hex(8)}"
    context.save!
  end

  def suggest_similar_context_names(name)
    # Try partial matches first
    suggestions = @document.context_items
                           .saved_contexts
                           .where(user: @user)
                           .where("title LIKE ?", "%#{name[0..2]}%")
                           .limit(5)
                           .pluck(:title)

    # If no partial matches, return all available context names
    if suggestions.empty?
      suggestions = @document.context_items
                             .saved_contexts
                             .where(user: @user)
                             .limit(5)
                             .pluck(:title)
    end

    # If still empty, provide generic suggestion
    if suggestions.empty?
      suggestions = [ "Try using /save <name> to create a context first" ]
    end

    suggestions
  end

  def suggest_similar_commands(command)
    # Try prefix matching first
    suggestions = CommandParserService.registered_commands.select do |cmd|
      cmd.start_with?(command[0..1]) || command.start_with?(cmd[0..1])
    end

    # If no prefix matches, return all commands as suggestions
    if suggestions.empty?
      suggestions = CommandParserService.registered_commands
    end

    suggestions.first(3)
  end

  def error_result(command, parameters, start_time, error_message, options = {})
    execution_time = Time.current - start_time

    result = {
      success: false,
      error: error_message,
      execution_time: execution_time,
      timestamp: Time.current
    }.merge(options)

    # Log the failed command execution
    log_command_execution(command, parameters, execution_time, "error", result, error_message)

    result
  end

  def log_command_execution(command, parameters, execution_time, status, result, error_message = nil)
    # Log to command history
    CommandHistory.create!(
      command: command,
      parameters: parameters,
      user: @user,
      document: @document,
      executed_at: Time.current,
      execution_time: execution_time,
      status: status,
      result_data: result.except(:success, :error, :execution_time, :timestamp),
      error_message: error_message
    )

    # Log to audit trail
    CommandAuditLog.create!(
      command: command,
      parameters: parameters,
      user: @user,
      document: @document,
      executed_at: Time.current,
      execution_time: execution_time,
      status: status,
      error_message: error_message,
      metadata: {
        result_keys: result.keys,
        document_title: @document.title
      }
    )
  end
end
