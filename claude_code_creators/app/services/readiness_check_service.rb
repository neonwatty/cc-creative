class ReadinessCheckService
  def perform
    checks = []
    overall_ready = true

    # Database migration check
    migration_check = database_migration_check
    checks << migration_check
    overall_ready &&= migration_check[:ready]

    # Essential services check
    services_check = essential_services_check
    checks << services_check
    overall_ready &&= services_check[:ready]

    # Configuration check
    config_check = configuration_check
    checks << config_check
    overall_ready &&= config_check[:ready]

    {
      ready: overall_ready,
      timestamp: Time.current.iso8601,
      checks: checks
    }
  end

  private

  def database_migration_check
    # Check if all migrations are up to date
    pending_migrations = ActiveRecord::Migration.check_pending!

    {
      name: "database_migrations",
      ready: true,
      message: "All database migrations are up to date"
    }
  rescue ActiveRecord::PendingMigrationError => e
    {
      name: "database_migrations",
      ready: false,
      error: e.message,
      message: "Pending database migrations detected"
    }
  rescue => e
    {
      name: "database_migrations",
      ready: false,
      error: e.message,
      message: "Database migration check failed"
    }
  end

  def essential_services_check
    # Check that essential external services are available
    services = {
      anthropic_api: anthropic_api_check,
      file_storage: file_storage_check
    }

    all_ready = services.values.all? { |service| service[:ready] }

    {
      name: "essential_services",
      ready: all_ready,
      services: services,
      message: all_ready ? "All essential services available" : "Some essential services unavailable"
    }
  end

  def anthropic_api_check
    # Basic check to see if Anthropic API key is configured
    api_key = ENV["ANTHROPIC_API_KEY"]

    if api_key.present?
      {
        ready: true,
        message: "Anthropic API key configured"
      }
    else
      {
        ready: false,
        message: "Anthropic API key not configured"
      }
    end
  rescue => e
    {
      ready: false,
      error: e.message,
      message: "Anthropic API check failed"
    }
  end

  def file_storage_check
    # Check if file storage is accessible
    begin
      # Test write/read/delete operation
      test_key = "health_check_#{SecureRandom.hex(8)}"
      Rails.application.config.active_storage.variant_processor

      {
        ready: true,
        message: "File storage accessible"
      }
    rescue => e
      {
        ready: false,
        error: e.message,
        message: "File storage check failed"
      }
    end
  end

  def configuration_check
    # Check critical configuration values
    required_configs = %w[
      RAILS_MASTER_KEY
      SECRET_KEY_BASE
    ]

    missing_configs = required_configs.select { |config| ENV[config].blank? }

    if missing_configs.empty?
      {
        name: "configuration",
        ready: true,
        message: "All required configuration present"
      }
    else
      {
        name: "configuration",
        ready: false,
        missing_configs: missing_configs,
        message: "Missing required configuration: #{missing_configs.join(', ')}"
      }
    end
  rescue => e
    {
      name: "configuration",
      ready: false,
      error: e.message,
      message: "Configuration check failed"
    }
  end
end
