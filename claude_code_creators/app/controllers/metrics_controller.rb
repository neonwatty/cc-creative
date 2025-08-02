class MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_metrics_request

  def show
    metrics = MetricsCollectionService.new.collect_all
    render json: metrics, status: :ok
  rescue => e
    render json: {
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :internal_server_error
  end

  def prometheus
    # Prometheus-compatible metrics endpoint
    metrics = PrometheusMetricsService.new.format_metrics
    render plain: metrics, content_type: "text/plain"
  rescue => e
    render plain: "# Error collecting metrics: #{e.message}",
           content_type: "text/plain",
           status: :internal_server_error
  end

  private

  def authenticate_metrics_request
    # Simple token-based authentication for metrics
    token = request.headers["Authorization"]&.sub(/^Bearer /, "")
    expected_token = ENV["METRICS_TOKEN"]

    unless expected_token.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected_token)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
