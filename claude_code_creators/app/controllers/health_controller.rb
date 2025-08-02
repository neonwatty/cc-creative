class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    health_status = HealthCheckService.new.perform

    if health_status[:healthy]
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  rescue => e
    render json: {
      healthy: false,
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end

  def liveness
    # Basic liveness check - just return 200 if app is running
    render json: {
      status: "alive",
      timestamp: Time.current.iso8601
    }, status: :ok
  end

  def readiness
    # Readiness check - verify app can serve requests
    readiness_status = ReadinessCheckService.new.perform

    if readiness_status[:ready]
      render json: readiness_status, status: :ok
    else
      render json: readiness_status, status: :service_unavailable
    end
  rescue => e
    render json: {
      ready: false,
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end
