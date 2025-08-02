module RateLimiting
  extend ActiveSupport::Concern

  included do
    before_action :check_rate_limits, unless: :skip_rate_limiting?
    after_action :add_rate_limit_headers
  end

  private

  def check_rate_limits
    # Get identifier (user ID or IP address)
    identifier = current_user&.id || request.remote_ip

    # Determine action based on controller and action
    action_key = determine_rate_limit_action

    return unless action_key

    begin
      @rate_limit_result = RateLimitingService.enforce_rate_limit!(
        identifier,
        action_key,
        request.remote_ip
      )
    rescue RateLimitingService::RateLimitExceededError => e
      handle_rate_limit_exceeded(e)
    end
  end

  def add_rate_limit_headers
    return unless @rate_limit_result

    identifier = current_user&.id || request.remote_ip
    action_key = determine_rate_limit_action

    return unless action_key

    headers = RateLimitingService.get_rate_limit_headers(
      identifier,
      action_key,
      request.remote_ip
    )

    headers.each { |key, value| response.headers[key] = value }
  end

  def handle_rate_limit_exceeded(error)
    response.headers["Retry-After"] = error.retry_after.to_s if error.retry_after

    # Log the rate limit violation
    Rails.logger.warn("Rate limit exceeded: #{error.message}")

    respond_to do |format|
      format.json do
        render json: {
          error: "Rate limit exceeded",
          message: error.message,
          retry_after: error.retry_after,
          reset_at: error.reset_at&.iso8601
        }, status: :too_many_requests
      end

      format.html do
        flash[:error] = "Too many requests. Please try again later."
        redirect_back(fallback_location: root_path)
      end

      format.any do
        head :too_many_requests
      end
    end
  end

  def determine_rate_limit_action
    # Map controller/action combinations to rate limit keys
    case "#{controller_name}##{action_name}"
    when "sessions#create", "sessions#omniauth"
      "auth:login"
    when "passwords#create", "passwords#update"
      "auth:password_reset"
    when "users#confirm_email"
      "auth:email_verification"
    when /^commands#/
      "claude:requests"
    when /^documents#create/, /^documents#update/
      "claude:heavy"
    when /^cloud_files#import/, /^cloud_files#export/
      "files:upload"
    when /^cloud_files#show/, /^cloud_files#index/
      "files:download"
    when /^context_items#search/, /^documents#index/
      "search:requests"
    when "metrics#show", "metrics#prometheus"
      nil # No rate limiting for metrics endpoints with proper auth
    when "health#show", "health#liveness", "health#readiness"
      nil # No rate limiting for health checks
    else
      # Default general API rate limiting
      if request.path.start_with?("/api/") || request.xhr?
        "api:general"
      else
        nil # No rate limiting for regular page requests
      end
    end
  end

  def skip_rate_limiting?
    # Skip rate limiting in development/test or for certain IPs
    return true if Rails.env.development? || Rails.env.test?

    # Skip for whitelisted IPs (e.g., monitoring systems)
    whitelisted_ips = ENV["RATE_LIMIT_WHITELIST_IPS"]&.split(",") || []
    return true if whitelisted_ips.include?(request.remote_ip)

    # Skip for specific user agents (monitoring tools)
    user_agent = request.user_agent.to_s.downcase
    monitoring_agents = %w[pingdom datadog newrelic prometheus]
    return true if monitoring_agents.any? { |agent| user_agent.include?(agent) }

    false
  end

  # Helper method for controllers to apply custom rate limiting
  def apply_custom_rate_limit(action_key)
    identifier = current_user&.id || request.remote_ip

    begin
      RateLimitingService.enforce_rate_limit!(identifier, action_key, request.remote_ip)
    rescue RateLimitingService::RateLimitExceededError => e
      handle_rate_limit_exceeded(e)
      return false
    end

    true
  end
end
