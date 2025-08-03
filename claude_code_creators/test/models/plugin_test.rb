require "test_helper"

class PluginTest < ActiveSupport::TestCase
  def setup
    @plugin = Plugin.new(
      name: "test-plugin",
      version: "1.0.0",
      description: "A test plugin for extensibility platform",
      author: "Test Author",
      category: "editor",
      status: "active",
      metadata: { "entry_point" => "index.js", "dependencies" => [] },
      permissions: { "read_files" => true, "write_files" => false },
      sandbox_config: { "memory_limit" => 100, "cpu_limit" => 50 }
    )
  end

  test "should be valid with valid attributes" do
    assert @plugin.valid?
  end

  test "should require name" do
    @plugin.name = nil
    assert_not @plugin.valid?
    assert_includes @plugin.errors[:name], "can't be blank"
  end

  test "should require version" do
    @plugin.version = nil
    assert_not @plugin.valid?
    assert_includes @plugin.errors[:version], "can't be blank"
  end

  test "should require description" do
    @plugin.description = nil
    assert_not @plugin.valid?
    assert_includes @plugin.errors[:description], "can't be blank"
  end

  test "should require author" do
    @plugin.author = nil
    assert_not @plugin.valid?
    assert_includes @plugin.errors[:author], "can't be blank"
  end

  test "should validate category inclusion" do
    valid_categories = %w[editor command integration theme workflow]
    valid_categories.each do |category|
      @plugin.category = category
      assert @plugin.valid?, "#{category} should be a valid category"
    end

    @plugin.category = "invalid"
    assert_not @plugin.valid?
    assert_includes @plugin.errors[:category], "is not included in the list"
  end

  test "should validate status inclusion" do
    valid_statuses = %w[active inactive deprecated pending]
    valid_statuses.each do |status|
      @plugin.status = status
      assert @plugin.valid?, "#{status} should be a valid status"
    end

    @plugin.status = "invalid"
    assert_not @plugin.valid?
    assert_includes @plugin.errors[:status], "is not included in the list"
  end

  test "should validate version format" do
    valid_versions = [ "1.0.0", "2.1.3", "0.1.0-beta" ]
    valid_versions.each do |version|
      @plugin.version = version
      assert @plugin.valid?, "#{version} should be a valid version"
    end

    invalid_versions = [ "1.0", "v1.0.0", "1.0.0.0", "invalid" ]
    invalid_versions.each do |version|
      @plugin.version = version
      assert_not @plugin.valid?, "#{version} should be invalid"
    end
  end

  test "should validate name uniqueness within version" do
    @plugin.save!
    duplicate = Plugin.new(@plugin.attributes.except("id"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name with different versions" do
    @plugin.save!
    new_version = Plugin.new(@plugin.attributes.except("id"))
    new_version.version = "2.0.0"
    assert new_version.valid?
  end

  test "should validate metadata structure" do
    @plugin.metadata = { "entry_point" => "index.js" }
    assert @plugin.valid?

    @plugin.metadata = "invalid"
    assert_not @plugin.valid?
  end

  test "should validate permissions structure" do
    @plugin.permissions = { "read_files" => true, "write_files" => false }
    assert @plugin.valid?

    @plugin.permissions = "invalid"
    assert_not @plugin.valid?
  end

  test "should validate sandbox_config structure" do
    @plugin.sandbox_config = { "memory_limit" => 100, "cpu_limit" => 50 }
    assert @plugin.valid?

    @plugin.sandbox_config = "invalid"
    assert_not @plugin.valid?
  end

  test "should have many plugin_installations" do
    assert_respond_to @plugin, :plugin_installations
  end

  test "should have many extension_logs" do
    assert_respond_to @plugin, :extension_logs
  end

  test "should have many plugin_permissions" do
    assert_respond_to @plugin, :plugin_permissions
  end

  test "should scope active plugins" do
    active_plugin = Plugin.create!(@plugin.attributes)
    inactive_plugin = Plugin.create!(
      @plugin.attributes.except("id", "created_at", "updated_at").merge(
        name: "inactive-plugin",
        version: "1.0.1",
        status: "inactive"
      )
    )

    assert_includes Plugin.active, active_plugin
    assert_not_includes Plugin.active, inactive_plugin
  end

  test "should scope by category" do
    editor_plugin = Plugin.create!(@plugin.attributes)
    command_plugin = Plugin.create!(
      @plugin.attributes.except("id", "created_at", "updated_at").merge(
        name: "command-plugin",
        version: "1.0.2",
        category: "command"
      )
    )

    assert_includes Plugin.by_category("editor"), editor_plugin
    assert_not_includes Plugin.by_category("editor"), command_plugin
  end

  test "should determine if plugin is installed for user" do
    user = users(:one)
    @plugin.save!

    assert_not @plugin.installed_for?(user)

    PluginInstallation.create!(user: user, plugin: @plugin, status: "installed")
    assert @plugin.installed_for?(user)
  end

  test "should get installation for user" do
    user = users(:one)
    @plugin.save!
    installation = PluginInstallation.create!(user: user, plugin: @plugin, status: "installed")

    assert_equal installation, @plugin.installation_for(user)
  end

  test "should check compatibility with current platform" do
    @plugin.metadata = { "min_version" => "1.0.0", "max_version" => "2.0.0" }
    assert @plugin.compatible_with_platform?("1.5.0")
    assert_not @plugin.compatible_with_platform?("0.9.0")
    assert_not @plugin.compatible_with_platform?("2.1.0")
  end

  test "should generate sandbox identifier" do
    @plugin.save!
    identifier = @plugin.sandbox_identifier
    assert_match(/plugin_\d+_[a-f0-9]+/, identifier)
  end

  test "should check if plugin requires permissions" do
    @plugin.permissions = { "read_files" => true }
    assert @plugin.requires_permissions?

    @plugin.permissions = {}
    assert_not @plugin.requires_permissions?
  end
end
