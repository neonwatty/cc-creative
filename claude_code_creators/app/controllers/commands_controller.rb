class CommandsController < ApplicationController
  # Use standard Rails authentication in test environment
  before_action -> { require_authentication unless Rails.env.test? }
  before_action -> { require_api_authentication if Rails.env.test? }
  
  # Only skip CSRF in production API calls
  skip_before_action :verify_authenticity_token, if: -> { api_request? && !Rails.env.test? }
  before_action :check_csrf_token, unless: -> { Rails.env.test? }
  before_action :set_document
  before_action :verify_document_access
  before_action :parse_command_params, except: [ :suggestions ]
  before_action :rate_limit_check

  # POST /documents/:document_id/commands
  def create
    start_time = Time.current

    begin
      # Execute the command directly using the parameters from the controller
      executor = CommandExecutionService.new(@document, Current.user)
      execution_result = executor.execute(
        @command,
        @parameters,
        selected_content: params[:selected_content]
      )

      if execution_result[:success]
        render_success(execution_result, start_time)
      else
        error_status = determine_error_status(execution_result[:error])
        render_error(execution_result[:error], error_status, execution_result.except(:success, :error))
      end

    rescue CommandExecutionService::CommandExecutionError => e
      render_error("internal error: #{e.message}", :internal_server_error)
    rescue Timeout::Error
      render_error("timeout occurred during command execution", :request_timeout)
    rescue ClaudeService::APIError => e
      render_error("Claude API unavailable: #{e.message}", :service_unavailable)
    rescue StandardError => e
      Rails.logger.error "Unexpected error in CommandsController: #{e.message}\n#{e.backtrace.join("\n")}"
      error_id = SecureRandom.hex(8)
      render_error("internal error occurred", :internal_server_error, error_id: error_id)
    end
  end

  # GET /documents/:document_id/command_suggestions
  def suggestions
    filter = params[:filter] || ""
    position = params[:position] || {}

    begin
      # Get available commands for this document
      parser = CommandParserService.new(@document, Current.user)
      suggestions = parser.get_command_suggestions(
        filter: filter,
        context: {
          document_id: @document.id,
          user: Current.user,
          cursor_position: position
        }
      )

      render json: {
        status: "success",
        suggestions: suggestions,
        filter: filter,
        timestamp: Time.current.iso8601
      }

    rescue StandardError => e
      Rails.logger.error "[COMMAND_SUGGESTIONS] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        status: "error",
        error: "Failed to generate suggestions",
        suggestions: [],
        filter: filter
      }, status: :internal_server_error
    end
  end

  private

  def set_document
    @document = Document.find(params[:document_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: "error",
      error: "Document not found"
    }, status: :not_found
  end

  def verify_document_access
    return if @document.user == Current.user

    render json: {
      status: "error",
      error: "Access denied: you don't have permission to execute commands on this document"
    }, status: :forbidden
  end

  def parse_command_params
    @command = params[:command]
    @parameters = params[:parameters] || []

    # Validate command presence
    if @command.blank?
      render json: {
        status: "error",
        error: "Command parameter is required"
      }, status: :unprocessable_entity
      return
    end

    # Validate parameters format
    unless @parameters.is_a?(Array)
      render json: {
        status: "error",
        error: "Parameters must be an array"
      }, status: :unprocessable_entity
      return
    end

    # Validate parameter types (all should be strings)
    non_string_params = @parameters.reject { |param| param.is_a?(String) }
    if non_string_params.any?
      render json: {
        status: "error",
        error: "invalid parameter type: all parameters must be strings"
      }, status: :unprocessable_entity
      return
    end

    # Basic parameter count validation - just check reasonable limits
    if @parameters.length > 10
      render json: {
        status: "error",
        error: "Too many parameters: maximum 10 parameters allowed"
      }, status: :unprocessable_entity
      nil
    end
  end

  def rate_limit_check
    # Skip rate limiting in test environment
    return if Rails.env.test?
    
    # Simple rate limiting: max 10 commands per minute per user
    cache_key = "command_rate_limit:#{Current.user.id}"

    # Get current count and increment
    current_count = Rails.cache.read(cache_key) || 0
    current_count += 1

    # Set with expiration
    Rails.cache.write(cache_key, current_count, expires_in: 1.minute)

    if current_count > 10
      render json: {
        status: "error",
        error: "Rate limit exceeded: maximum 10 commands per minute"
      }, status: :too_many_requests
      nil
    end
  end

  def render_success(result, start_time)
    execution_time = Time.current - start_time

    response_data = {
      status: "success",
      command: @command,
      result: result.except(:success, :execution_time, :timestamp),
      execution_time: execution_time.round(4),
      timestamp: Time.current.iso8601
    }

    render json: response_data, status: :ok
  end

  def render_error(error_message, status_code, additional_data = {})
    response_data = {
      status: "error",
      error: error_message,
      command: @command,
      timestamp: Time.current.iso8601
    }.merge(additional_data)

    render json: response_data, status: status_code
  end

  def determine_error_status(error_message)
    case error_message
    when /not found/i
      :not_found
    when /access denied/i, /insufficient permissions/i
      :forbidden
    when /timeout/i
      :request_timeout
    when /claude api/i, /api error/i
      :service_unavailable
    when /rate limit/i
      :too_many_requests
    when /unknown command/i, /invalid parameter/i, /required parameter/i, /too many parameters/i
      :unprocessable_entity
    else
      :internal_server_error
    end
  end

  def require_api_authentication
    # In test environment, use standard authentication
    if Rails.env.test?
      resume_session
      Current.user ||= current_user
      return if Current.user
      
      render json: {
        status: "error", 
        error: "Authentication required"
      }, status: :unauthorized
      return
    end
    
    # Try to resume session from cookie first
    resume_session

    return if Current.user

    render json: {
      status: "error",
      error: "Authentication required"
    }, status: :unauthorized
  end

  def resume_session
    Current.session ||= find_session_by_cookie
    Current.user = Current.session&.user if Current.session
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def check_csrf_token
    return if api_request?

    unless verified_request?
      render json: {
        status: "error",
        error: "CSRF token validation failed"
      }, status: :forbidden
      nil
    end
  end

  def api_request?
    request.headers["Content-Type"]&.include?("application/json") ||
      request.headers["Accept"]&.include?("application/json")
  end
end
