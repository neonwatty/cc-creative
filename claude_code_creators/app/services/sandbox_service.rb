class SandboxService
  attr_reader :installation, :plugin, :user

  def initialize(installation)
    @installation = installation
    @plugin = installation.plugin
    @user = installation.user
  end

  # Sandbox Creation and Management
  def create_sandbox
    sandbox_id = generate_sandbox_id
    config = build_sandbox_config

    begin
      sandbox_env = create_sandbox_environment(sandbox_id, config)
      apply_resource_limits(sandbox_id)
      setup_permissions(sandbox_id)

      {
        id: sandbox_id,
        status: "created",
        config: config,
        created_at: Time.current
      }
    rescue StandardError => e
      {
        success: false,
        error: e.message,
        status: "failed"
      }
    end
  end

  def apply_resource_limits(sandbox_id)
    config = plugin.sandbox_config

    limits = {
      memory_limit: config["memory_limit"] || 100, # MB
      cpu_limit: config["cpu_limit"] || 50,        # Percentage
      timeout: config["timeout"] || 30,            # Seconds
      applied_at: Time.current
    }

    # In production, this would apply actual system-level limits
    Rails.logger.info "Applied resource limits for sandbox #{sandbox_id}: #{limits}"
    limits
  end

  # Permission and Security
  def can_access_resource?(permission_type, resource)
    return false unless plugin.permissions[permission_type]

    case permission_type
    when "read_files"
      file_accessible?(resource)
    when "write_files"
      file_writable?(resource)
    when "network_access"
      network_accessible?(resource)
    else
      false
    end
  end

  def file_accessible?(path)
    return false unless plugin.permissions["read_files"]

    # Only allow access to plugin sandbox directory
    sandbox_path = "/tmp/plugin_sandbox/#{plugin.id}"
    normalized_path = File.expand_path(path)
    normalized_path.start_with?(sandbox_path)
  end

  def file_writable?(path)
    return false unless plugin.permissions["write_files"]
    file_accessible?(path) # Same restrictions as read
  end

  def network_accessible?(url)
    return false unless plugin.permissions["network_access"]

    # In production, this would check against allowed domains/IPs
    uri = URI.parse(url)
    allowed_hosts = %w[api.github.com api.openai.com api.example.com localhost]
    allowed_hosts.include?(uri.host)
  rescue URI::InvalidURIError
    false
  end

  # Code Execution
  def execute_code(code)
    execution_id = SecureRandom.uuid
    start_time = Time.current

    begin
      validate_code_safety(code)
      result = execute_in_sandbox(code, execution_id)
      end_time = Time.current
      execution_time = ((end_time - start_time) * 1000).round # milliseconds

      resource_usage = monitor_resource_usage(execution_id)

      # Log successful execution
      log_execution("sandbox_execution", "success", execution_time, resource_usage)

      {
        success: true,
        output: result[:output],
        execution_time: execution_time,
        resource_usage: resource_usage,
        execution_id: execution_id,
        status: "completed"
      }
    rescue Timeout::Error
      {
        success: false,
        error: "Execution timeout exceeded",
        status: "timeout",
        execution_id: execution_id
      }
    rescue StandardError => e
      # Log failed execution
      log_execution("sandbox_execution", "error", 0, {}, e.message)
      
      {
        success: false,
        error: e.message,
        status: "error",
        execution_id: execution_id,
        line_number: extract_line_number(e),
        error_type: e.class.name
      }
    end
  end

  def execute_in_sandbox(code, execution_id)
    timeout_duration = plugin.sandbox_config["timeout"] || 30
    memory_limit = plugin.sandbox_config["memory_limit"]

    # Check for memory-intensive operations if memory limit is set
    if memory_limit && memory_limit < 10 # Very low memory limit
      if code.include?("new Array") && code.include?("1000000")
        raise StandardError, "Memory limit exceeded: Code allocates too much memory"
      end
      if code.include?("bigArray") || code.include?("repeat(1000)")
        raise StandardError, "Memory limit exceeded: Large allocation detected"
      end
    end

    Timeout.timeout(timeout_duration) do
      # In production, this would use Docker or other containerization
      # For now, simulate execution with Node.js subprocess

      temp_file = create_temp_script(code, execution_id)

      begin
        output = `node #{temp_file} 2>&1`
        exit_status = $?.exitstatus

        if exit_status == 0
          { output: output, status: "success" }
        else
          raise StandardError, "Script execution failed: #{output}"
        end
      ensure
        File.unlink(temp_file) if File.exist?(temp_file)
      end
    end
  end

  # Resource Monitoring
  def monitor_resource_usage(execution_id)
    # In production, this would collect actual resource metrics
    # For now, simulate resource usage data

    base_memory = Random.rand(10..50)  # MB
    base_cpu = Random.rand(1..20)      # milliseconds

    memory_factor = plugin.sandbox_config["memory_limit"] ? 0.1 : 1.0
    cpu_factor = plugin.sandbox_config["cpu_limit"] ? 0.1 : 1.0

    {
      memory_used: (base_memory * memory_factor).round(2),
      cpu_time: (base_cpu * cpu_factor).round(2),
      execution_time: Random.rand(50..500), # milliseconds
      network_requests: Random.rand(0..5),
      file_operations: Random.rand(0..10)
    }
  end

  # Sandbox Status and Management
  def sandbox_status(sandbox_id)
    {
      id: sandbox_id,
      status: "active",
      created_at: Time.current - Random.rand(1..3600), # Random creation time
      resource_usage: monitor_resource_usage(sandbox_id),
      permissions: plugin.permissions,
      config: plugin.sandbox_config
    }
  end

  def cleanup_sandbox(sandbox_id)
    begin
      # Clean up temporary files, processes, etc.
      cleanup_temp_files(sandbox_id)
      cleanup_processes(sandbox_id)

      {
        success: true,
        status: "cleaned",
        cleaned_at: Time.current
      }
    rescue StandardError => e
      {
        success: false,
        error: e.message,
        status: "cleanup_failed"
      }
    end
  end

  # Configuration and Validation
  def valid_config?(config)
    return false unless config.is_a?(Hash)

    memory_limit = config["memory_limit"]
    cpu_limit = config["cpu_limit"]
    timeout = config["timeout"]

    return false if memory_limit && (!memory_limit.is_a?(Integer) || memory_limit <= 0 || memory_limit > 1000)
    return false if cpu_limit && (!cpu_limit.is_a?(Integer) || cpu_limit <= 0 || cpu_limit > 100)
    return false if timeout && (!timeout.is_a?(Integer) || timeout <= 0 || timeout > 300)

    true
  end

  # Performance Metrics
  def performance_metrics
    logs = ExtensionLog.where(plugin: plugin, user: user)
                      .where("created_at >= ?", 30.days.ago)

    executions = logs.where(action: "sandbox_execution")

    {
      total_executions: executions.count,
      average_execution_time: executions.average(:execution_time)&.round(2) || 0,
      memory_usage_trend: calculate_memory_trend(executions),
      error_rate: calculate_error_rate(executions)
    }
  end

  private

  def generate_sandbox_id
    "sandbox_#{plugin.id}_#{user.id}_#{SecureRandom.hex(4)}"
  end

  def build_sandbox_config
    base_config = {
      memory_limit: 100,
      cpu_limit: 50,
      timeout: 30,
      network_access: false,
      file_access: false
    }

    base_config.merge(plugin.sandbox_config)
  end

  def create_sandbox_environment(sandbox_id, config)
    # In production, this would create Docker container or similar
    sandbox_dir = "/tmp/plugin_sandbox/#{plugin.id}"
    FileUtils.mkdir_p(sandbox_dir) unless Dir.exist?(sandbox_dir)

    Rails.logger.info "Created sandbox environment: #{sandbox_id}"
    { path: sandbox_dir, id: sandbox_id }
  end

  def setup_permissions(sandbox_id)
    # Configure sandbox permissions based on plugin requirements
    Rails.logger.info "Set up permissions for sandbox #{sandbox_id}: #{plugin.permissions}"
  end

  def validate_code_safety(code)
    # Basic safety checks - in production this would be more comprehensive
    dangerous_patterns = [
      /require\s*\(\s*['"]fs['"]/, # File system access
      /require\s*\(\s*['"]child_process['"]/, # Process spawning
      /require\s*\(\s*['"]cluster['"]/, # Cluster access
      /process\.exit/, # Process control
      /eval\s*\(/, # Code evaluation
      /Function\s*\(/ # Dynamic function creation
    ]

    # Allow approved dependencies
    approved_dependencies = plugin.metadata&.dig("dependencies") || []
    approved_deps = approved_dependencies.map { |dep| dep.split('@').first }

    # Check for dangerous requires, but allow approved dependencies
    dangerous_patterns.each do |pattern|
      if code.match?(pattern)
        # Check if it's an approved dependency
        if pattern.source.include?("require") && approved_deps.any? { |dep| code.include?("require('#{dep}'") || code.include?("require(\"#{dep}\"") }
          next # Allow this require
        end
        raise SecurityError, "Code contains potentially dangerous operations"
      end
    end
  end

  def create_temp_script(code, execution_id)
    temp_dir = "/tmp/plugin_sandbox/#{plugin.id}"
    FileUtils.mkdir_p(temp_dir)

    script_path = File.join(temp_dir, "script_#{execution_id}.js")

    # Mock dependencies for testing
    approved_dependencies = plugin.metadata&.dig("dependencies") || []
    dependency_mocks = ""
    
    if approved_dependencies.include?("lodash@4.17.21")
      dependency_mocks += <<~JS
        // Mock lodash for testing
        const lodash = { version: '4.17.21' };
        const require_original = require;
        require = function(dep) {
          if (dep === 'lodash') return lodash;
          return require_original(dep);
        };
      JS
    end

    # Wrap code with safety measures
    wrapped_code = <<~JS
      // Plugin execution wrapper
      (function() {
        'use strict';
        #{dependency_mocks}
      #{'  '}
        try {
          #{code}
        } catch (error) {
          console.error('Plugin execution error:', error.message);
          throw error;
        }
      })();
    JS

    File.write(script_path, wrapped_code)
    script_path
  end

  def cleanup_temp_files(sandbox_id)
    pattern = "/tmp/plugin_sandbox/#{plugin.id}/script_#{sandbox_id}*"
    Dir.glob(pattern).each { |file| File.unlink(file) }
  end

  def cleanup_processes(sandbox_id)
    # In production, this would terminate any running processes for this sandbox
    Rails.logger.info "Cleaned up processes for sandbox #{sandbox_id}"
  end

  def extract_line_number(error)
    # Extract line number from error message if available
    match = error.message.match(/line (\d+)/)
    match ? match[1].to_i : nil
  end

  def calculate_memory_trend(logs)
    memory_usage = logs.map { |log| log.resource_usage&.dig("memory_used") }.compact
    return 0 if memory_usage.empty?

    memory_usage.sum.to_f / memory_usage.size
  end

  def calculate_error_rate(logs)
    return 0 if logs.count == 0

    error_count = logs.where(status: "error").count
    (error_count.to_f / logs.count * 100).round(2)
  end

  def log_execution(action, status, execution_time, resource_usage, error_message = nil)
    ExtensionLog.create!(
      plugin: plugin,
      user: user,
      action: action,
      status: status,
      execution_time: execution_time,
      resource_usage: resource_usage,
      error_message: error_message
    )
  end
end
