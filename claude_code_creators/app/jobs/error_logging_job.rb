# Background job for async error logging
class ErrorLoggingJob < ApplicationJob
  queue_as :low_priority
  
  def perform(error_data)
    ErrorLog.create!(error_data)
  rescue => e
    Rails.logger.error "Failed to log error to database: #{e.message}"
    # Fallback to file logging
    Rails.logger.error "Original error data: #{error_data.to_json}"
  end
end