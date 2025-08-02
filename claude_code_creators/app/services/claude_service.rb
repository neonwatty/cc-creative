# Service class for interacting with Claude AI via Anthropic SDK
class ClaudeService
  class ApiError < StandardError; end
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
      raise ApiError, "Claude API error: #{e.message}"
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
