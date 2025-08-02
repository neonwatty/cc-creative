require "test_helper"

class PluginManagerServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @plugin = Plugin.create!(
      name: "test-plugin",
      version: "1.0.0",
      description: "A test plugin for extensibility",
      author: "Test Author",
      category: "editor",
      status: "active",
      metadata: {
        "entry_point" => "index.js",
        "dependencies" => [ "lodash@4.17.21" ],
        "min_version" => "1.0.0",
        "max_version" => "2.0.0"
      },
      permissions: { "read_files" => true, "write_files" => false },
      sandbox_config: { "memory_limit" => 100, "cpu_limit" => 50, "timeout" => 30 }
    )
    @service = PluginManagerService.new(@user)
  end

  test "should initialize with user" do
    assert_equal @user, @service.user
    assert_instance_of PluginManagerService, @service
  end

  test "should discover available plugins" do
    plugins = @service.discover_plugins
    assert_includes plugins, @plugin
    assert plugins.all? { |p| p.status == "active" }
  end

  test "should filter plugins by category" do
    command_plugin = Plugin.create!(
      @plugin.attributes.merge(name: "command-plugin", category: "command")
    )

    editor_plugins = @service.discover_plugins(category: "editor")
    command_plugins = @service.discover_plugins(category: "command")

    assert_includes editor_plugins, @plugin
    assert_not_includes editor_plugins, command_plugin
    assert_includes command_plugins, command_plugin
    assert_not_includes command_plugins, @plugin
  end

  test "should search plugins by name and description" do
    searching_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "search-helper",
        description: "Advanced search functionality"
      )
    )

    results = @service.search_plugins("search")
    assert_includes results, searching_plugin
    assert_not_includes results, @plugin

    results = @service.search_plugins("test")
    assert_includes results, @plugin
  end

  test "should install plugin successfully" do
    result = @service.install_plugin(@plugin.id)

    assert result[:success]
    assert_equal "Plugin installed successfully", result[:message]

    installation = PluginInstallation.find_by(user: @user, plugin: @plugin)
    assert_not_nil installation
    assert_equal "installed", installation.status
    assert_not_nil installation.installed_at
  end

  test "should not install already installed plugin" do
    PluginInstallation.create!(user: @user, plugin: @plugin, status: "installed")

    result = @service.install_plugin(@plugin.id)

    assert_not result[:success]
    assert_includes result[:error], "already installed"
  end

  test "should not install incompatible plugin" do
    incompatible_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "incompatible-plugin",
        metadata: { "min_version" => "99.0.0" }
      )
    )

    result = @service.install_plugin(incompatible_plugin.id)

    assert_not result[:success]
    assert_includes result[:error], "not compatible"
  end

  test "should handle missing dependencies during installation" do
    plugin_with_deps = Plugin.create!(
      @plugin.attributes.merge(
        name: "deps-plugin",
        metadata: { "dependencies" => [ "nonexistent-package@1.0.0" ] }
      )
    )

    # Mock dependency resolution failure
    @service.stubs(:resolve_dependencies).returns(false)

    result = @service.install_plugin(plugin_with_deps.id)

    assert_not result[:success]
    assert_includes result[:error], "dependencies"
  end

  test "should uninstall plugin successfully" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    result = @service.uninstall_plugin(@plugin.id)

    assert result[:success]
    assert_equal "Plugin uninstalled successfully", result[:message]

    installation.reload
    assert_equal "uninstalled", installation.status
  end

  test "should not uninstall non-installed plugin" do
    result = @service.uninstall_plugin(@plugin.id)

    assert_not result[:success]
    assert_includes result[:error], "not installed"
  end

  test "should enable disabled plugin" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "disabled"
    )

    result = @service.enable_plugin(@plugin.id)

    assert result[:success]
    installation.reload
    assert_equal "installed", installation.status
  end

  test "should disable enabled plugin" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    result = @service.disable_plugin(@plugin.id)

    assert result[:success]
    installation.reload
    assert_equal "disabled", installation.status
  end

  test "should configure plugin settings" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed",
      configuration: { "theme" => "light" }
    )

    new_config = { "theme" => "dark", "notifications" => true }
    result = @service.configure_plugin(@plugin.id, new_config)

    assert result[:success]
    installation.reload
    assert_equal "dark", installation.configuration["theme"]
    assert_equal true, installation.configuration["notifications"]
  end

  test "should get user installed plugins" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    installed_plugins = @service.installed_plugins

    assert_includes installed_plugins, installation
    assert installed_plugins.all? { |i| i.user == @user }
  end

  test "should get plugin installation status" do
    assert_equal "not_installed", @service.installation_status(@plugin.id)

    PluginInstallation.create!(user: @user, plugin: @plugin, status: "installed")
    assert_equal "installed", @service.installation_status(@plugin.id)

    PluginInstallation.last.update!(status: "disabled")
    assert_equal "disabled", @service.installation_status(@plugin.id)
  end

  test "should check plugin compatibility" do
    compatible_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "compatible-plugin",
        metadata: { "min_version" => "1.0.0", "max_version" => "2.0.0" }
      )
    )

    incompatible_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "incompatible-plugin",
        metadata: { "min_version" => "99.0.0" }
      )
    )

    assert @service.compatible_plugin?(compatible_plugin)
    assert_not @service.compatible_plugin?(incompatible_plugin)
  end

  test "should resolve plugin dependencies" do
    plugin_with_deps = Plugin.create!(
      @plugin.attributes.merge(
        name: "deps-plugin",
        metadata: { "dependencies" => [ "lodash@4.17.21", "axios@0.24.0" ] }
      )
    )

    # Mock successful dependency resolution
    @service.stubs(:dependency_available?).returns(true)

    assert @service.resolve_dependencies(plugin_with_deps)
  end

  test "should validate plugin sandbox configuration" do
    valid_config = { "memory_limit" => 100, "cpu_limit" => 50, "timeout" => 30 }
    invalid_config = { "memory_limit" => "unlimited" }

    assert @service.valid_sandbox_config?(valid_config)
    assert_not @service.valid_sandbox_config?(invalid_config)
  end

  test "should update plugin to new version" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    new_version = Plugin.create!(
      @plugin.attributes.merge(name: "test-plugin", version: "2.0.0")
    )

    result = @service.update_plugin(@plugin.id, new_version.id)

    assert result[:success]
    installation.reload
    assert_equal new_version, installation.plugin
  end

  test "should handle plugin execution errors gracefully" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    # Simulate plugin execution error
    result = @service.handle_plugin_error(@plugin.id, "Runtime error: undefined method")

    assert result[:logged]

    log = ExtensionLog.find_by(plugin: @plugin, user: @user)
    assert_not_nil log
    assert_equal "error", log.status
    assert_includes log.error_message, "Runtime error"
  end

  test "should track plugin usage metrics" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    @service.track_plugin_usage(@plugin.id, { action: "command_executed" })

    installation.reload
    assert_not_nil installation.last_used_at

    log = ExtensionLog.find_by(plugin: @plugin, user: @user, action: "command_executed")
    assert_not_nil log
  end

  test "should get plugin health status" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    # Create some logs to test health
    ExtensionLog.create!(
      plugin: @plugin,
      user: @user,
      action: "execution",
      status: "success",
      execution_time: 100
    )

    health = @service.plugin_health(@plugin.id)

    assert_includes health.keys, :status
    assert_includes health.keys, :success_rate
    assert_includes health.keys, :average_execution_time
    assert_includes health.keys, :recent_errors
  end

  test "should cleanup orphaned installations" do
    # Create installation for deleted plugin
    deleted_plugin_id = 99999
    installation = PluginInstallation.create!(
      user: @user,
      plugin_id: deleted_plugin_id,
      status: "installed"
    )

    @service.cleanup_orphaned_installations

    assert_not PluginInstallation.exists?(installation.id)
  end

  test "should validate plugin permissions" do
    valid_permissions = { "read_files" => true, "write_files" => false, "network_access" => true }
    invalid_permissions = { "invalid_permission" => true }

    assert @service.valid_permissions?(valid_permissions)
    assert_not @service.valid_permissions?(invalid_permissions)
  end
end
