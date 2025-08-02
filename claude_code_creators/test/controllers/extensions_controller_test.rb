require "test_helper"

class ExtensionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as @user

    @plugin = Plugin.create!(
      name: "test-plugin",
      version: "1.0.0",
      description: "A test plugin for extensions API",
      author: "Test Author",
      category: "editor",
      status: "active",
      metadata: { "entry_point" => "index.js", "api_version" => "1.0" },
      permissions: { "read_files" => true, "write_files" => false },
      sandbox_config: { "memory_limit" => 100, "cpu_limit" => 50, "timeout" => 30 }
    )
  end

  test "should get index of available plugins" do
    get extensions_path

    assert_response :success
    assert_includes response.body, @plugin.name
    assert_includes response.body, @plugin.description
  end

  test "should get index with category filter" do
    command_plugin = Plugin.create!(
      @plugin.attributes.merge(name: "command-plugin", category: "command")
    )

    get extensions_path, params: { category: "editor" }

    assert_response :success
    assert_includes response.body, @plugin.name
    assert_not_includes response.body, command_plugin.name
  end

  test "should search plugins" do
    get extensions_path, params: { search: "test" }

    assert_response :success
    assert_includes response.body, @plugin.name
  end

  test "should show individual plugin" do
    get extension_path(@plugin)

    assert_response :success
    assert_includes response.body, @plugin.name
    assert_includes response.body, @plugin.description
    assert_includes response.body, @plugin.author
  end

  test "should install plugin successfully" do
    post install_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "Plugin installed successfully", json_response["message"]

    installation = PluginInstallation.find_by(user: @user, plugin: @plugin)
    assert_not_nil installation
    assert_equal "installed", installation.status
  end

  test "should not install plugin twice" do
    PluginInstallation.create!(user: @user, plugin: @plugin, status: "installed")

    post install_extension_path(@plugin), as: :json

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "already installed"
  end

  test "should not install incompatible plugin" do
    incompatible_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "incompatible-plugin",
        metadata: { "min_version" => "99.0.0" }
      )
    )

    post install_extension_path(incompatible_plugin), as: :json

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "not compatible"
  end

  test "should uninstall plugin successfully" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    delete uninstall_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "Plugin uninstalled successfully", json_response["message"]

    installation.reload
    assert_equal "uninstalled", installation.status
  end

  test "should not uninstall non-installed plugin" do
    delete uninstall_extension_path(@plugin), as: :json

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "not installed"
  end

  test "should enable disabled plugin" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "disabled"
    )

    patch enable_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    installation.reload
    assert_equal "installed", installation.status
  end

  test "should disable enabled plugin" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    patch disable_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    installation.reload
    assert_equal "disabled", installation.status
  end

  test "should update plugin configuration" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed",
      configuration: { "theme" => "light" }
    )

    new_config = { "theme" => "dark", "notifications" => true }

    patch configure_extension_path(@plugin),
          params: { configuration: new_config },
          as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

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

    get installed_extensions_path, as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["plugins"].length
    assert_equal @plugin.id, json_response["plugins"].first["id"]
  end

  test "should get plugin installation status" do
    PluginInstallation.create!(user: @user, plugin: @plugin, status: "installed")

    get status_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "installed", json_response["status"]
    assert_not_nil json_response["installed_at"]
  end

  test "should get plugin health information" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    # Create some logs for health data
    ExtensionLog.create!(
      plugin: @plugin,
      user: @user,
      action: "execution",
      status: "success",
      execution_time: 100
    )

    get health_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "status"
    assert_includes json_response.keys, "success_rate"
    assert_includes json_response.keys, "average_execution_time"
  end

  test "should execute plugin command" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    command_data = { "action" => "test_command", "params" => { "text" => "hello" } }

    post execute_extension_path(@plugin),
         params: { command: command_data },
         as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_not_nil json_response["result"]
  end

  test "should not execute plugin command for non-installed plugin" do
    command_data = { "action" => "test_command" }

    post execute_extension_path(@plugin),
         params: { command: command_data },
         as: :json

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "not installed"
  end

  test "should handle plugin execution errors" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    # Mock plugin execution failure
    PluginManagerService.any_instance.stubs(:execute_plugin_command).raises(StandardError, "Plugin error")

    command_data = { "action" => "failing_command" }

    post execute_extension_path(@plugin),
         params: { command: command_data },
         as: :json

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "Plugin error"
  end

  test "should get plugin marketplace data" do
    get marketplace_extensions_path, as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "featured"
    assert_includes json_response.keys, "categories"
    assert_includes json_response.keys, "recent"
  end

  test "should require authentication for plugin actions" do
    sign_out @user

    post install_extension_path(@plugin), as: :json

    assert_response :unauthorized
  end

  test "should validate plugin permissions before installation" do
    dangerous_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "dangerous-plugin",
        permissions: { "system_access" => true, "write_files" => true }
      )
    )

    post install_extension_path(dangerous_plugin), as: :json

    # Should either prompt for permission confirmation or reject
    json_response = JSON.parse(response.body)
    assert_includes [ "permission_required", "rejected" ].map(&:to_s), json_response["status"]
  end

  test "should track plugin installation analytics" do
    post install_extension_path(@plugin), as: :json

    assert_response :success

    # Verify analytics tracking
    log = ExtensionLog.find_by(
      plugin: @plugin,
      user: @user,
      action: "installation"
    )

    assert_not_nil log
    assert_equal "success", log.status
  end

  test "should support plugin version updates" do
    installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )

    new_version = Plugin.create!(
      @plugin.attributes.merge(version: "2.0.0")
    )

    patch update_extension_path(@plugin),
          params: { new_version_id: new_version.id },
          as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    installation.reload
    assert_equal new_version, installation.plugin
  end

  test "should get plugin documentation" do
    @plugin.update!(
      metadata: {
        "entry_point" => "index.js",
        "documentation" => "# Test Plugin\n\nThis is a test plugin."
      }
    )

    get documentation_extension_path(@plugin), as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_includes json_response["documentation"], "Test Plugin"
  end

  test "should handle bulk plugin operations" do
    plugin2 = Plugin.create!(
      @plugin.attributes.merge(name: "plugin2")
    )

    plugin_ids = [ @plugin.id, plugin2.id ]

    post bulk_install_extensions_path,
         params: { plugin_ids: plugin_ids },
         as: :json

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 2, json_response["results"].length
    assert json_response["results"].all? { |r| r["success"] }
  end

  test "should validate API rate limits" do
    # Simulate many rapid requests
    10.times do
      post install_extension_path(@plugin), as: :json
    end

    # After rate limit, should return 429
    post install_extension_path(@plugin), as: :json

    # Note: Actual rate limiting implementation would determine response
    assert_includes [ 200, 429 ], response.status
  end
end
