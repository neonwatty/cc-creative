# Background job for async Claude AI interactions
class ClaudeInteractionJob < ApplicationJob
  queue_as :default
  
  # Retry configuration for API failures
  retry_on Anthropic::Error, wait: :polynomially_longer, attempts: 3
  retry_on ClaudeService::ApiError, wait: :polynomially_longer, attempts: 3
  
  # Rate limiting
  MAX_REQUESTS_PER_MINUTE = 50
  
  def perform(session_id, action, params = {})
    Rails.logger.info "ClaudeInteractionJob: Processing #{action} for session #{session_id}"
    
    # Rate limiting check
    check_rate_limit!
    
    case action
    when 'send_message'
      process_message(session_id, params)
    when 'create_sub_agent'
      create_sub_agent(session_id, params)
    when 'compress_context'
      compress_context(session_id, params)
    when 'generate_completion'
      generate_completion(session_id, params)
    else
      Rails.logger.error "Unknown action: #{action}"
      raise ArgumentError, "Unknown action: #{action}"
    end
  rescue StandardError => e
    handle_error(session_id, action, e)
    raise
  end
  
  private
  
  def process_message(session_id, params)
    service = ClaudeService.new(session_id: session_id)
    
    result = service.send_message(
      params[:content],
      context: params[:context] || {},
      system_prompt: params[:system_prompt]
    )
    
    # Notify any listeners (e.g., ActionCable channels)
    notify_completion(session_id, 'message_processed', result)
    
    result
  end
  
  def create_sub_agent(session_id, params)
    service = ClaudeService.new(session_id: session_id)
    
    sub_agent = service.create_sub_agent(
      params[:name],
      initial_context: params[:initial_context] || {}
    )
    
    # Store sub-agent info
    session = ClaudeSession.find_or_create_by(session_id: session_id)
    session.metadata['sub_agents'] ||= []
    session.metadata['sub_agents'] << {
      name: params[:name],
      created_at: Time.current,
      session_id: sub_agent.instance_variable_get(:@session_id)
    }
    session.save!
    
    notify_completion(session_id, 'sub_agent_created', { name: params[:name] })
  end
  
  def compress_context(session_id, params)
    max_tokens = params[:max_tokens] || 50_000
    
    # Compress context for the session
    ClaudeContext.compress_context(session_id, max_tokens: max_tokens)
    
    # Get updated token count
    total_tokens = ClaudeContext.total_tokens_for_session(session_id)
    
    notify_completion(session_id, 'context_compressed', { 
      total_tokens: total_tokens,
      max_tokens: max_tokens 
    })
  end
  
  def generate_completion(session_id, params)
    service = ClaudeService.new(session_id: session_id)
    
    # Build context from recent messages
    recent_messages = ClaudeMessage.by_session(session_id)
                                  .recent
                                  .limit(params[:context_size] || 10)
                                  .map { |msg| { role: msg.role, content: msg.content } }
                                  .reverse
    
    result = service.send_message(
      params[:prompt],
      context: { previous_messages: recent_messages },
      system_prompt: params[:system_prompt]
    )
    
    notify_completion(session_id, 'completion_generated', result)
    
    result
  end
  
  def check_rate_limit!
    # Simple rate limiting using Rails cache
    cache_key = "claude_rate_limit:#{Time.current.to_i / 60}"
    count = Rails.cache.increment(cache_key, 1, expires_in: 1.minute)
    
    if count && count > MAX_REQUESTS_PER_MINUTE
      raise StandardError, "Rate limit exceeded. Please try again later."
    end
  end
  
  def notify_completion(session_id, event, data)
    # This would integrate with ActionCable or other notification system
    # For now, just log the completion
    Rails.logger.info "ClaudeInteractionJob completed: #{event} for session #{session_id}"
    
    # Example ActionCable broadcast (uncomment when ActionCable is set up):
    # ActionCable.server.broadcast(
    #   "claude_session_#{session_id}",
    #   { event: event, data: data }
    # )
  end
  
  def handle_error(session_id, action, error)
    Rails.logger.error "ClaudeInteractionJob error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Store error in session metadata
    session = ClaudeSession.find_by(session_id: session_id)
    if session
      session.metadata['last_error'] = {
        action: action,
        error: error.message,
        occurred_at: Time.current
      }
      session.save
    end
    
    # Notify about the error
    notify_completion(session_id, 'error_occurred', { 
      action: action,
      error: error.message 
    })
  end
end