require "test_helper"

class PluginInstallationTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @plugin = Plugin.create!(
      name: "test-plugin",
      version: "1.0.0",
      description: "A test plugin",
      author: "Test Author",
      category: "editor",
      status: "active",
      metadata: { "entry_point" => "index.js" },
      permissions: { "read_files" => true },
      sandbox_config: { "memory_limit" => 100 }
    )
    @installation = PluginInstallation.new(
      user: @user,
      plugin: @plugin,
      configuration: { "theme" => "dark", "enabled" => true },
      status: "installed"
    )
  end

  test "should be valid with valid attributes" do
    assert @installation.valid?
  end

  test "should require user" do
    @installation.user = nil
    assert_not @installation.valid?
    assert_includes @installation.errors[:user], "must exist"
  end

  test "should require plugin" do
    @installation.plugin = nil
    assert_not @installation.valid?
    assert_includes @installation.errors[:plugin], "must exist"
  end

  test "should validate status inclusion" do
    valid_statuses = %w[installed uninstalled disabled error updating]
    valid_statuses.each do |status|
      @installation.status = status
      assert @installation.valid?, "#{status} should be a valid status"
    end

    @installation.status = "invalid"
    assert_not @installation.valid?
    assert_includes @installation.errors[:status], "is not included in the list"
  end

  test "should validate uniqueness of user and plugin combination" do
    @installation.save!
    duplicate = PluginInstallation.new(
      user: @user,
      plugin: @plugin,
      status: "installed"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:plugin_id], "has already been taken"
  end

  test "should allow same plugin for different users" do
    @installation.save!
    other_user = users(:two)
    other_installation = PluginInstallation.new(
      user: other_user,
      plugin: @plugin,
      status: "installed"
    )
    assert other_installation.valid?
  end

  test "should validate configuration structure" do
    @installation.configuration = { "theme" => "dark" }
    assert @installation.valid?

    @installation.configuration = "invalid"
    assert_not @installation.valid?
  end

  test "should set installed_at timestamp on installation" do
    @installation.save!
    assert_not_nil @installation.installed_at
    assert @installation.installed_at.is_a?(Time) || @installation.installed_at.is_a?(ActiveSupport::TimeWithZone)
  end

  test "should track last_used_at timestamp" do
    @installation.save!
    @installation.touch_last_used!
    assert_not_nil @installation.last_used_at
    assert @installation.last_used_at > @installation.installed_at
  end

  test "should scope installed plugins" do
    installed = PluginInstallation.create!(@installation.attributes)
    uninstalled = PluginInstallation.create!(
      @installation.attributes.merge(
        plugin: Plugin.create!(
          @plugin.attributes.except("id", "created_at", "updated_at").merge(
            name: "other-plugin",
            version: "1.0.1"
          )
        ),
        status: "uninstalled"
      )
    )

    assert_includes PluginInstallation.installed, installed
    assert_not_includes PluginInstallation.installed, uninstalled
  end

  test "should scope active installations" do
    active = PluginInstallation.create!(@installation.attributes)
    disabled = PluginInstallation.create!(
      @installation.attributes.merge(
        plugin: Plugin.create!(
          @plugin.attributes.except("id", "created_at", "updated_at").merge(
            name: "disabled-plugin",
            version: "1.0.2"
          )
        ),
        status: "disabled"
      )
    )

    assert_includes PluginInstallation.active, active
    assert_not_includes PluginInstallation.active, disabled
  end

  test "should scope by user" do
    user_installation = PluginInstallation.create!(@installation.attributes)
    other_user = users(:two)
    other_installation = PluginInstallation.create!(
      @installation.attributes.merge(
        user: other_user,
        plugin: Plugin.create!(
          @plugin.attributes.except("id", "created_at", "updated_at").merge(
            name: "other-plugin",
            version: "1.0.3"
          )
        )
      )
    )

    assert_includes PluginInstallation.for_user(@user), user_installation
    assert_not_includes PluginInstallation.for_user(@user), other_installation
  end

  test "should check if installation is active" do
    @installation.status = "installed"
    assert @installation.active?

    @installation.status = "disabled"
    assert_not @installation.active?

    @installation.status = "uninstalled"
    assert_not @installation.active?
  end

  test "should get configuration value" do
    @installation.configuration = { "theme" => "dark", "notifications" => true }
    @installation.save!

    assert_equal "dark", @installation.config_value("theme")
    assert_equal true, @installation.config_value("notifications")
    assert_nil @installation.config_value("nonexistent")
    assert_equal "default", @installation.config_value("nonexistent", "default")
  end

  test "should set configuration value" do
    @installation.save!
    @installation.set_config_value("new_setting", "value")

    assert_equal "value", @installation.configuration["new_setting"]
  end

  test "should track installation metrics" do
    @installation.save!
    metrics = @installation.usage_metrics

    assert_includes metrics.keys, :installed_at
    assert_includes metrics.keys, :last_used_at
    assert_includes metrics.keys, :days_since_install
    assert_includes metrics.keys, :status
  end

  test "should validate plugin compatibility on save" do
    incompatible_plugin = Plugin.create!(
      @plugin.attributes.except("id", "created_at", "updated_at").merge(
        name: "incompatible-plugin",
        version: "1.0.4",
        metadata: { "min_version" => "99.0.0", "entry_point" => "index.js" }
      )
    )
    @installation.plugin = incompatible_plugin

    assert_not @installation.valid?
    assert_includes @installation.errors[:plugin], "is not compatible with current platform"
  end

  test "should handle plugin installation workflow" do
    @installation.status = "installing"
    @installation.save!

    @installation.mark_installed!
    assert_equal "installed", @installation.status
    assert_not_nil @installation.installed_at

    @installation.mark_disabled!
    assert_equal "disabled", @installation.status

    @installation.mark_uninstalled!
    assert_equal "uninstalled", @installation.status
  end

  test "should handle installation errors" do
    @installation.mark_error!("Installation failed: permission denied")
    assert_equal "error", @installation.status
    assert_includes @installation.configuration["error_message"], "permission denied"
  end
end
