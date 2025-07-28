class SubAgentService
  attr_reader :sub_agent, :errors
  
  def initialize(sub_agent)
    @sub_agent = sub_agent
    @errors = []
  end
  
  # Initialize a new sub-agent with necessary setup
  def initialize_agent
    # Basic initialization - can be expanded later
    sub_agent.activate!
    true
  rescue StandardError => e
    @errors << "Failed to initialize agent: #{e.message}"
    false
  end
  
  # Activate the sub-agent
  def activate
    sub_agent.activate!
    true
  rescue StandardError => e
    @errors << "Failed to activate agent: #{e.message}"
    false
  end
  
  # Complete the sub-agent's work
  def complete
    sub_agent.complete!
    true
  rescue StandardError => e
    @errors << "Failed to complete agent: #{e.message}"
    false
  end
  
  # Class method to create a new sub-agent
  def self.create(user, document, params)
    sub_agent = document.sub_agents.build(params)
    sub_agent.user = user
    
    new(sub_agent)
  end
  
  # Send a message to the sub-agent
  def send_message(user, content)
    return nil if content.blank?
    
    # Create user message
    message = sub_agent.messages.create!(
      role: 'user',
      content: content,
      user: user
    )
    
    # Generate assistant response (mock for now)
    generate_assistant_response(user)
    
    message
  rescue StandardError => e
    @errors << "Failed to send message: #{e.message}"
    nil
  end
  
  # Merge content from sub-agent
  def merge_content
    assistant_messages = sub_agent.messages.by_role('assistant')
    return nil if assistant_messages.empty?
    
    # Collect all assistant messages
    content_parts = assistant_messages.map(&:content)
    content_parts.join("\n\n")
  end
  
  # Merge content to document
  def merge_to_document
    content = merge_content
    return false if content.blank?
    
    # Append content to document
    current_content = sub_agent.document.content.to_s
    new_content = "#{current_content}\n\n## Content from #{sub_agent.name}\n\n#{content}"
    
    sub_agent.document.update!(content: new_content)
    true
  rescue StandardError => e
    @errors << "Failed to merge to document: #{e.message}"
    false
  end
  
  # Context management
  def update_context(new_context)
    sub_agent.update_context(new_context)
  end
  
  def merge_context(additional_context)
    sub_agent.merge_context(additional_context)
  end
  
  def clear_context
    sub_agent.clear_context
  end
  
  # Status management
  def activate!
    sub_agent.activate!
  end
  
  def deactivate!
    sub_agent.deactivate!
  end
  
  def complete!
    sub_agent.complete!
  end
  
  # Export and summary
  def export_conversation
    sub_agent.export_conversation
  end
  
  def summary
    sub_agent.summary
  end
  
  private
  
  def generate_assistant_response(user)
    # Mock assistant response for testing
    # In production, this would call the AI API
    response_content = "I understand your message. How can I help you further?"
    
    sub_agent.messages.create!(
      role: 'assistant',
      content: response_content,
      user: user
    )
  rescue StandardError => e
    Rails.logger.error "Failed to generate assistant response: #{e.message}"
  end
  
  # Helper method for conversation history
  def conversation_history
    sub_agent.messages.recent.limit(20).map do |msg|
      { role: msg.role, content: msg.content }
    end
  end
end