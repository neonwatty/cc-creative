# Configure Anthropic SDK for Claude AI integration
require 'anthropic'

# Initialize Anthropic client configuration
Rails.application.config.after_initialize do
  # Use environment-specific credentials if available, otherwise use default
  anthropic_config = if Rails.application.credentials.dig(Rails.env.to_sym, :anthropic)
                      Rails.application.credentials.dig(Rails.env.to_sym, :anthropic)
                    else
                      Rails.application.credentials.anthropic
                    end

  if anthropic_config.nil? || anthropic_config[:api_key].blank?
    Rails.logger.warn "Anthropic API key not configured. Please add it to Rails credentials."
    Rails.logger.warn "Run: EDITOR=vim rails credentials:edit"
    Rails.logger.warn "See config/credentials.yml.example for the required structure"
  else
    # Configure default settings
    Rails.application.config.anthropic = {
      api_key: anthropic_config[:api_key],
      model: anthropic_config[:model] || 'claude-3-5-sonnet-20241022',
      max_tokens: anthropic_config[:max_tokens] || 4096,
      temperature: anthropic_config[:temperature] || 0.7
    }
  end
end