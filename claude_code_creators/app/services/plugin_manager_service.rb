class PluginManagerService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Plugin Discovery
  def discover_plugins(category: nil, search: nil)
    plugins = Plugin.active
    plugins = plugins.by_category(category) if category.present?
    plugins = plugins.search(search) if search.present?
    plugins
  end

  def search_plugins(query)
    Plugin.active.search(query)
  end

  # Plugin Installation
  def install_plugin(plugin_id)
    plugin = Plugin.find(plugin_id)

    return error_result("Plugin not found") unless plugin
    return error_result("Plugin is not active") unless plugin.status == "active"
    return error_result("Plugin already installed") if plugin.installed_for?(user)
    return error_result("Plugin is not compatible with current platform") unless compatible_plugin?(plugin)

    unless resolve_dependencies(plugin)
      return error_result("Failed to resolve plugin dependencies")
    end

    begin
      installation = PluginInstallation.create!(
        user: user,
        plugin: plugin,
        status: "installed",
        configuration: {},
        installed_at: Time.current
      )

      log_plugin_activity(plugin, "installation", "success")
      success_result("Plugin installed successfully", { installation: installation })
    rescue StandardError => e
      log_plugin_activity(plugin, "installation", "error", e.message)
      error_result("Installation failed: #{e.message}")
    end
  end

  def uninstall_plugin(plugin_id)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return error_result("Plugin not found") unless plugin
    return error_result("Plugin is not installed") unless installation

    begin
      installation.mark_uninstalled!
      cleanup_plugin_data(plugin)
      log_plugin_activity(plugin, "uninstallation", "success")
      success_result("Plugin uninstalled successfully")
    rescue StandardError => e
      log_plugin_activity(plugin, "uninstallation", "error", e.message)
      error_result("Uninstallation failed: #{e.message}")
    end
  end

  # Plugin Management
  def enable_plugin(plugin_id)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return error_result("Plugin not found") unless plugin
    return error_result("Plugin is not installed") unless installation

    begin
      installation.mark_installed!
      log_plugin_activity(plugin, "enable", "success")
      success_result("Plugin enabled successfully")
    rescue StandardError => e
      log_plugin_activity(plugin, "enable", "error", e.message)
      error_result("Enable failed: #{e.message}")
    end
  end

  def disable_plugin(plugin_id)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return error_result("Plugin not found") unless plugin
    return error_result("Plugin is not installed") unless installation

    begin
      installation.mark_disabled!
      log_plugin_activity(plugin, "disable", "success")
      success_result("Plugin disabled successfully")
    rescue StandardError => e
      log_plugin_activity(plugin, "disable", "error", e.message)
      error_result("Disable failed: #{e.message}")
    end
  end

  def configure_plugin(plugin_id, configuration)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return error_result("Plugin not found") unless plugin
    return error_result("Plugin is not installed") unless installation
    return error_result("Invalid configuration") unless configuration.is_a?(Hash)

    begin
      installation.configuration = (installation.configuration || {}).merge(configuration)
      installation.save!
      log_plugin_activity(plugin, "configuration", "success")
      success_result("Plugin configured successfully")
    rescue StandardError => e
      log_plugin_activity(plugin, "configuration", "error", e.message)
      error_result("Configuration failed: #{e.message}")
    end
  end

  # Plugin Information
  def installed_plugins
    PluginInstallation.for_user(user).includes(:plugin)
  end

  def installation_status(plugin_id)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return "not_installed" unless installation
    installation.status
  end

  def plugin_health(plugin_id)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return { status: "not_installed" } unless installation

    metrics = ExtensionLog.performance_metrics(plugin_id)
    resource_trends = ExtensionLog.resource_usage_trends(plugin_id)

    {
      status: installation.status,
      success_rate: metrics[:success_rate],
      average_execution_time: metrics[:average_execution_time],
      recent_errors: metrics[:recent_errors],
      resource_usage: resource_trends,
      last_used: installation.last_used_at,
      installation_age: installation.days_since_install
    }
  end

  # Plugin Execution
  def execute_plugin_command(plugin_id, command_data)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return error_result("Plugin not found") unless plugin
    return error_result("Plugin is not installed or disabled") unless installation&.active?

    sandbox_service = SandboxService.new(installation)

    begin
      sandbox = sandbox_service.create_sandbox
      result = sandbox_service.execute_code(build_plugin_command(plugin, command_data))

      log_plugin_activity(plugin, "execution", "success", nil, result[:execution_time], result[:resource_usage])
      installation.touch_last_used!

      success_result("Command executed successfully", { result: result[:output] })
    rescue StandardError => e
      log_plugin_activity(plugin, "execution", "error", e.message)
      handle_plugin_error(plugin_id, e.message)
      error_result("Execution failed: #{e.message}")
    ensure
      sandbox_service&.cleanup_sandbox(sandbox[:id]) if sandbox
    end
  end

  # Plugin Updates
  def update_plugin(plugin_id, new_version_id)
    current_plugin = Plugin.find(plugin_id)
    new_plugin = Plugin.find(new_version_id)
    installation = current_plugin.installation_for(user)

    return error_result("Current plugin not found") unless current_plugin
    return error_result("New plugin version not found") unless new_plugin
    return error_result("Plugin is not installed") unless installation
    return error_result("New version is not compatible") unless compatible_plugin?(new_plugin)

    begin
      installation.update!(plugin: new_plugin)
      log_plugin_activity(new_plugin, "update", "success")
      success_result("Plugin updated successfully")
    rescue StandardError => e
      log_plugin_activity(current_plugin, "update", "error", e.message)
      error_result("Update failed: #{e.message}")
    end
  end

  # Plugin Error Handling
  def handle_plugin_error(plugin_id, error_message)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    if installation
      installation.mark_error!(error_message)
    end

    log_plugin_activity(plugin, "error_handling", "error", error_message)
    { logged: true, status: "error_recorded" }
  end

  def track_plugin_usage(plugin_id, usage_data)
    plugin = Plugin.find(plugin_id)
    installation = plugin.installation_for(user)

    return unless installation

    installation.touch_last_used!
    log_plugin_activity(plugin, usage_data[:action] || "usage", "success")
  end

  # Utility Methods
  def compatible_plugin?(plugin)
    plugin.compatible_with_platform?
  end

  def resolve_dependencies(plugin)
    return true if plugin.dependencies.empty?

    plugin.dependencies.all? { |dep| dependency_available?(dep) }
  end

  def dependency_available?(dependency)
    # Simplified dependency check - in production this would check npm, gem registries, etc.
    # For now, assume common dependencies are available
    common_deps = %w[lodash axios moment uuid]
    dep_name = dependency.split("@").first
    common_deps.include?(dep_name)
  end

  def valid_sandbox_config?(config)
    return false unless config.is_a?(Hash)

    memory_limit = config["memory_limit"]
    cpu_limit = config["cpu_limit"]
    timeout = config["timeout"]

    return false if memory_limit && (!memory_limit.is_a?(Integer) || memory_limit <= 0 || memory_limit > 1000)
    return false if cpu_limit && (!cpu_limit.is_a?(Integer) || cpu_limit <= 0 || cpu_limit > 100)
    return false if timeout && (!timeout.is_a?(Integer) || timeout <= 0 || timeout > 300)

    true
  end

  def valid_permissions?(permissions)
    return false unless permissions.is_a?(Hash)

    valid_permission_types = %w[
      read_files write_files delete_files
      network_access api_access
      clipboard_access
      system_notifications
      user_data_access
      editor_integration
      command_execution
    ]

    permissions.all? do |permission, value|
      valid_permission_types.include?(permission) && [ true, false ].include?(value)
    end
  end

  def cleanup_orphaned_installations
    PluginInstallation.joins("LEFT JOIN plugins ON plugins.id = plugin_installations.plugin_id")
                     .where("plugins.id IS NULL")
                     .delete_all
  end

  private

  def success_result(message, data = {})
    { success: true, message: message }.merge(data)
  end

  def error_result(message)
    { success: false, error: message }
  end

  def log_plugin_activity(plugin, action, status, error_message = nil, execution_time = nil, resource_usage = nil)
    ExtensionLog.create!(
      plugin: plugin,
      user: user,
      action: action,
      status: status,
      error_message: error_message,
      execution_time: execution_time,
      resource_usage: resource_usage
    )
  end

  def cleanup_plugin_data(plugin)
    # Clean up plugin-specific data, temporary files, etc.
    # This is a placeholder for actual cleanup logic
    Rails.logger.info "Cleaning up data for plugin #{plugin.name}"
  end

  def build_plugin_command(plugin, command_data)
    # Build executable command for the sandbox
    entry_point = plugin.entry_point

    # Simple command structure - in production this would be more sophisticated
    <<~JS
      // Plugin: #{plugin.name} v#{plugin.version}
      // Command: #{command_data['action']}

      const pluginConfig = #{plugin.sandbox_config.to_json};
      const commandData = #{command_data.to_json};

      // Execute plugin command
      function executeCommand() {
        try {
          // This would load the actual plugin code
          console.log('Executing command:', commandData.action);
          console.log('Plugin config:', pluginConfig);
      #{'    '}
          // Placeholder for actual plugin execution
          return { success: true, result: 'Command executed successfully' };
        } catch (error) {
          return { success: false, error: error.message };
        }
      }

      executeCommand();
    JS
  end
end
