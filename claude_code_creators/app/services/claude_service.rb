# Service class for interacting with Claude AI via Anthropic SDK
class ClaudeService
  class APIError < StandardError; end
  class ApiError < StandardError; end  # Maintain backwards compatibility
  class ConfigurationError < StandardError; end

  MAX_CONTEXT_TOKENS = 100_000 # Claude's context window limit

  def initialize(session_id: nil, sub_agent_name: nil)
    @session_id = session_id || SecureRandom.uuid
    @sub_agent_name = sub_agent_name
    @client = create_client
    @context_manager = ContextManager.new(@session_id)
  end

  # Send a message to Claude with optional context
  def send_message(content, context: {}, system_prompt: nil)
    raise ConfigurationError, "Anthropic client not configured" unless @client

    messages = build_messages(content, context)

    begin
      response = @client.messages(
        model: Rails.application.config.anthropic[:model],
        max_tokens: Rails.application.config.anthropic[:max_tokens],
        temperature: Rails.application.config.anthropic[:temperature],
        system: system_prompt || default_system_prompt,
        messages: messages
      )

      # Store the interaction
      store_interaction(content, response.content.first.text, context)

      # Return structured response
      {
        response: response.content.first.text,
        usage: response.usage,
        session_id: @session_id,
        sub_agent: @sub_agent_name
      }
    rescue Anthropic::Error => e
      raise APIError, "Claude API error: #{e.message}"
    end
  end

  # Create a sub-agent for isolated context
  def create_sub_agent(name, initial_context: {})
    sub_agent_id = "#{@session_id}:#{name}"

    # Initialize sub-agent with its own context
    sub_agent = self.class.new(
      session_id: sub_agent_id,
      sub_agent_name: name
    )

    # Set initial context if provided
    if initial_context.any?
      sub_agent.set_context(initial_context)
    end

    sub_agent
  end

  # Set or update context for the session
  def set_context(context)
    @context_manager.set_context(context)
  end

  # Get current context
  def get_context
    @context_manager.get_context
  end

  # Clear context for the session
  def clear_context
    @context_manager.clear_context
  end

  # Get conversation history
  def conversation_history(limit: 10)
    ClaudeMessage.where(session_id: @session_id)
                 .order(created_at: :desc)
                 .limit(limit)
  end

  # Stream a response (returns an enumerator)
  def stream_message(content, context: {}, system_prompt: nil)
    raise ConfigurationError, "Anthropic client not configured" unless @client

    messages = build_messages(content, context)

    Enumerator.new do |yielder|
      @client.messages(
        model: Rails.application.config.anthropic[:model],
        max_tokens: Rails.application.config.anthropic[:max_tokens],
        temperature: Rails.application.config.anthropic[:temperature],
        system: system_prompt || default_system_prompt,
        messages: messages,
        stream: proc do |chunk|
          yielder << chunk
        end
      )
    end
  end

  # Compact context using Claude AI summarization
  def compact_context(messages, aggressive: false)
    raise ConfigurationError, "Anthropic client not configured" unless @client
    return { compacted_messages: messages, compression_ratio: 1.0 } if messages.empty?

    # Determine compression strategy
    target_message_count = aggressive ? [ messages.length / 4, 2 ].max : [ messages.length / 2, 5 ].max

    # Don't compact if already at target size
    return { compacted_messages: messages, compression_ratio: 1.0 } if messages.length <= target_message_count

    begin
      # Create summarization prompt
      conversation_text = messages.map { |msg| "#{msg[:role]}: #{msg[:content]}" }.join("\n\n")

      prompt = if aggressive
        "Please provide a very concise summary of this conversation, preserving only the most essential information and key decisions:\n\n#{conversation_text}"
      else
        "Please summarize this conversation, preserving important details, context, and key decisions:\n\n#{conversation_text}"
      end

      response = @client.messages(
        model: Rails.application.config.anthropic[:model],
        max_tokens: [ Rails.application.config.anthropic[:max_tokens] / 2, 1000 ].min,
        temperature: 0.3, # Lower temperature for consistent summarization
        system: "You are an expert at summarizing conversations while preserving important context and details.",
        messages: [ { role: "user", content: prompt } ]
      )

      summary = response.content.first.text

      # Create compacted message structure
      compacted_messages = [
        { role: "system", content: "Previous conversation summary: #{summary}" }
      ]

      # Keep the last few messages for immediate context
      recent_messages = messages.last([ target_message_count - 1, 2 ].max)
      compacted_messages.concat(recent_messages)

      compression_ratio = compacted_messages.length.to_f / messages.length

      {
        compacted_messages: compacted_messages,
        compression_ratio: compression_ratio,
        original_count: messages.length,
        compacted_count: compacted_messages.length
      }
    rescue Anthropic::Error => e
      raise APIError, "Failed to compact context: #{e.message}"
    rescue Timeout::Error
      raise APIError, "Context compaction timed out"
    end
  end

  private

  def create_client
    api_key = Rails.application.config.anthropic&.dig(:api_key)
    return nil if api_key.blank?

    Anthropic::Client.new(access_token: api_key)
  end

  def default_system_prompt
    "You are Claude, an AI assistant created by Anthropic to be helpful, harmless, and honest. " \
    "You are part of Claude Code for Creators, a creative writing platform."
  end

  def build_messages(content, context)
    messages = []

    # Add context messages if available
    if context[:previous_messages]
      messages.concat(context[:previous_messages])
    end

    # Add the current message
    messages << { role: "user", content: content }

    messages
  end

  def store_interaction(user_content, assistant_response, context)
    ClaudeMessage.create!(
      session_id: @session_id,
      sub_agent_name: @sub_agent_name,
      role: "user",
      content: user_content,
      context: context
    )

    ClaudeMessage.create!(
      session_id: @session_id,
      sub_agent_name: @sub_agent_name,
      role: "assistant",
      content: assistant_response,
      context: {}
    )
  rescue StandardError => e
    Rails.logger.error "Failed to store Claude interaction: #{e.message}"
  end

  # AI Code Review Methods for Plugin System
  def analyze_code_for_review(content, mode: "thorough", focus: nil)
    raise ConfigurationError, "Anthropic client not configured" unless @client

    system_prompt = build_review_system_prompt(mode, focus)
    user_prompt = build_review_user_prompt(content, mode, focus)

    begin
      response = @client.messages(
        model: Rails.application.config.anthropic[:model],
        max_tokens: Rails.application.config.anthropic[:max_tokens],
        temperature: 0.2,
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt } ]
      )

      parse_review_response(response.content.first.text)
    rescue Anthropic::Error => e
      raise APIError, "Claude API error during review: #{e.message}"
    end
  end

  def generate_code_suggestions(content, type: "enhance", context: nil)
    raise ConfigurationError, "Anthropic client not configured" unless @client

    system_prompt = build_suggestion_system_prompt(type, context)
    user_prompt = build_suggestion_user_prompt(content, type, context)

    begin
      response = @client.messages(
        model: Rails.application.config.anthropic[:model],
        max_tokens: Rails.application.config.anthropic[:max_tokens],
        temperature: 0.3,
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt } ]
      )

      parse_suggestion_response(response.content.first.text)
    rescue Anthropic::Error => e
      raise APIError, "Claude API error during suggestion generation: #{e.message}"
    end
  end

  def provide_code_critique(content, aspect: "architecture", level: "intermediate")
    raise ConfigurationError, "Anthropic client not configured" unless @client

    system_prompt = build_critique_system_prompt(aspect, level)
    user_prompt = build_critique_user_prompt(content, aspect, level)

    begin
      response = @client.messages(
        model: Rails.application.config.anthropic[:model],
        max_tokens: Rails.application.config.anthropic[:max_tokens],
        temperature: 0.2,
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt } ]
      )

      parse_critique_response(response.content.first.text)
    rescue Anthropic::Error => e
      raise APIError, "Claude API error during critique: #{e.message}"
    end
  end

  private

  # Review system prompts
  def build_review_system_prompt(mode, focus)
    base_prompt = "You are an expert code reviewer with extensive experience in software development best practices."

    case mode
    when "quick"
      "#{base_prompt} Provide a quick but thorough code review focusing on the most critical issues."
    when "security"
      "#{base_prompt} Focus specifically on security vulnerabilities, potential exploits, and secure coding practices."
    when "performance"
      "#{base_prompt} Focus on performance optimizations, efficiency, and scalability concerns."
    when "style"
      "#{base_prompt} Focus on code style, readability, and maintainability standards."
    else # thorough
      "#{base_prompt} Provide a comprehensive code review covering all aspects of code quality."
    end
  end

  def build_review_user_prompt(content, mode, focus)
    prompt = "Please review the following code:\n\n```\n#{content}\n```\n\n"
    prompt += "Focus areas: #{focus}\n\n" if focus.present?
    prompt += "Please provide your analysis in JSON format with the following structure:\n"
    prompt += '{"analysis": "overall analysis", "suggestions": ["suggestion1", "suggestion2"], "issues": [{"type": "issue_type", "severity": "high|medium|low", "description": "description"}], "score": numeric_score_0_to_100}'
  end

  def build_suggestion_system_prompt(type, context)
    base_prompt = "You are a senior software engineer providing code improvement suggestions."

    case type
    when "refactor"
      "#{base_prompt} Focus on refactoring opportunities to improve code structure and maintainability."
    when "optimize"
      "#{base_prompt} Focus on performance optimizations and efficiency improvements."
    when "enhance"
      "#{base_prompt} Focus on feature enhancements and functionality improvements."
    when "fix"
      "#{base_prompt} Focus on identifying and suggesting fixes for potential bugs and issues."
    when "extend"
      "#{base_prompt} Focus on extensibility and ways to make the code more flexible and reusable."
    else
      "#{base_prompt} Provide general improvement suggestions for the code."
    end
  end

  def build_suggestion_user_prompt(content, type, context)
    prompt = "Please analyze the following code and provide #{type} suggestions:\n\n```\n#{content}\n```\n\n"
    prompt += "Additional context: #{context}\n\n" if context.present?
    prompt += "Please provide your suggestions in JSON format with the following structure:\n"
    prompt += '{"suggestions": ["suggestion1", "suggestion2"], "improvements": [{"change": "description", "benefit": "benefit", "example": "code_example"}], "examples": ["example1"], "priority": "high|medium|low"}'
  end

  def build_critique_system_prompt(aspect, level)
    base_prompt = "You are a software architecture expert providing critical analysis of code design."

    case aspect
    when "architecture"
      "#{base_prompt} Focus on overall architecture, design patterns, and structural decisions."
    when "patterns"
      "#{base_prompt} Focus on design patterns, their usage, and appropriateness for the context."
    when "maintainability"
      "#{base_prompt} Focus on code maintainability, readability, and long-term sustainability."
    when "scalability"
      "#{base_prompt} Focus on scalability concerns and how the code will handle growth."
    when "testability"
      "#{base_prompt} Focus on testability, testing strategies, and code structure for testing."
    else
      "#{base_prompt} Provide a comprehensive critique of the code design and architecture."
    end
  end

  def build_critique_user_prompt(content, aspect, level)
    prompt = "Please provide a critical analysis of the following code focusing on #{aspect}:\n\n```\n#{content}\n```\n\n"
    prompt += "Analysis level: #{level}\n\n"
    prompt += "Please provide your critique in JSON format with the following structure:\n"
    prompt += '{"strengths": ["strength1"], "weaknesses": ["weakness1"], "recommendations": ["recommendation1"], "design_patterns": ["pattern1"], "best_practices": ["practice1"]}'
  end

  # Response parsers
  def parse_review_response(response_text)
    json_match = response_text.match(/\{.*\}/m)
    if json_match
      JSON.parse(json_match[0]).symbolize_keys
    else
      {
        analysis: response_text,
        suggestions: [],
        issues: [],
        score: 75
      }
    end
  rescue JSON::ParserError
    {
      analysis: response_text,
      suggestions: [],
      issues: [],
      score: 75
    }
  end

  def parse_suggestion_response(response_text)
    json_match = response_text.match(/\{.*\}/m)
    if json_match
      JSON.parse(json_match[0]).symbolize_keys
    else
      {
        suggestions: [ response_text ],
        improvements: [],
        examples: [],
        priority: "medium"
      }
    end
  rescue JSON::ParserError
    {
      suggestions: [ response_text ],
      improvements: [],
      examples: [],
      priority: "medium"
    }
  end

  def parse_critique_response(response_text)
    json_match = response_text.match(/\{.*\}/m)
    if json_match
      JSON.parse(json_match[0]).symbolize_keys
    else
      {
        strengths: [],
        weaknesses: [],
        recommendations: [ response_text ],
        design_patterns: [],
        best_practices: []
      }
    end
  rescue JSON::ParserError
    {
      strengths: [],
      weaknesses: [],
      recommendations: [ response_text ],
      design_patterns: [],
      best_practices: []
    }
  end

  # Internal context manager
  class ContextManager
    def initialize(session_id)
      @session_id = session_id
    end

    def set_context(context)
      session = ClaudeSession.find_or_create_by(session_id: @session_id)
      session.update!(context: session.context.merge(context))
    end

    def get_context
      session = ClaudeSession.find_by(session_id: @session_id)
      session&.context || {}
    end

    def clear_context
      session = ClaudeSession.find_by(session_id: @session_id)
      session&.update!(context: {})
    end
  end
end
