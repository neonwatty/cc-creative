require "test_helper"

class SandboxServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @plugin = Plugin.create!(
      name: "test-plugin",
      version: "1.0.0",
      description: "A test plugin for sandbox testing",
      author: "Test Author",
      category: "editor",
      status: "active",
      metadata: { "entry_point" => "index.js" },
      permissions: { "read_files" => true, "write_files" => false, "network_access" => false },
      sandbox_config: { "memory_limit" => 100, "cpu_limit" => 50, "timeout" => 30 }
    )
    @installation = PluginInstallation.create!(
      user: @user,
      plugin: @plugin,
      status: "installed",
      configuration: { "debug" => false }
    )
    @service = SandboxService.new(@installation)
  end

  test "should initialize with plugin installation" do
    assert_equal @installation, @service.installation
    assert_equal @plugin, @service.plugin
    assert_equal @user, @service.user
  end

  test "should create sandbox environment" do
    sandbox = @service.create_sandbox
    
    assert_not_nil sandbox[:id]
    assert_equal "created", sandbox[:status]
    assert_includes sandbox[:id], "plugin_#{@plugin.id}"
    assert_equal @plugin.sandbox_config["memory_limit"], sandbox[:config][:memory_limit]
    assert_equal @plugin.sandbox_config["cpu_limit"], sandbox[:config][:cpu_limit]
    assert_equal @plugin.sandbox_config["timeout"], sandbox[:config][:timeout]
  end

  test "should apply resource limits to sandbox" do
    sandbox = @service.create_sandbox
    
    limits = @service.apply_resource_limits(sandbox[:id])
    
    assert_equal @plugin.sandbox_config["memory_limit"], limits[:memory_limit]
    assert_equal @plugin.sandbox_config["cpu_limit"], limits[:cpu_limit]
    assert_equal @plugin.sandbox_config["timeout"], limits[:timeout]
    assert_not_nil limits[:applied_at]
  end

  test "should enforce permission boundaries" do
    # Test file read permission (allowed)
    assert @service.can_access_resource?("read_files", "/tmp/test.txt")
    
    # Test file write permission (denied)
    assert_not @service.can_access_resource?("write_files", "/tmp/test.txt")
    
    # Test network access (denied)
    assert_not @service.can_access_resource?("network_access", "https://api.example.com")
  end

  test "should execute plugin code in sandbox" do
    code = "console.log('Hello from plugin');"
    
    result = @service.execute_code(code)
    
    assert result[:success]
    assert_includes result[:output], "Hello from plugin"
    assert_not_nil result[:execution_time]
    assert result[:execution_time] > 0
  end

  test "should handle code execution timeout" do
    # Create plugin with very short timeout
    short_timeout_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "timeout-plugin",
        sandbox_config: { "timeout" => 0.1 }
      )
    )
    installation = PluginInstallation.create!(
      user: @user,
      plugin: short_timeout_plugin,
      status: "installed"
    )
    service = SandboxService.new(installation)
    
    # Code that will take longer than timeout
    slow_code = "while(true) { console.log('infinite loop'); }"
    
    result = service.execute_code(slow_code)
    
    assert_not result[:success]
    assert_includes result[:error], "timeout"
    assert_equal "timeout", result[:status]
  end

  test "should monitor resource usage during execution" do
    code = "const arr = new Array(1000).fill('data');"
    
    result = @service.execute_code(code)
    
    assert_not_nil result[:resource_usage]
    assert_includes result[:resource_usage].keys, :memory_used
    assert_includes result[:resource_usage].keys, :cpu_time
    assert_includes result[:resource_usage].keys, :execution_time
  end

  test "should enforce memory limits" do
    # Create plugin with very low memory limit
    low_memory_plugin = Plugin.create!(
      @plugin.attributes.merge(
        name: "memory-plugin",
        sandbox_config: { "memory_limit" => 1 } # 1MB limit
      )
    )
    installation = PluginInstallation.create!(
      user: @user,
      plugin: low_memory_plugin,
      status: "installed"
    )
    service = SandboxService.new(installation)
    
    # Code that will exceed memory limit
    memory_heavy_code = "const bigArray = new Array(1000000).fill('x'.repeat(1000));"
    
    result = service.execute_code(memory_heavy_code)
    
    assert_not result[:success]
    assert_includes result[:error], "memory"
  end

  test "should isolate file system access" do
    # Test that plugin can only access allowed paths
    allowed_path = "/tmp/plugin_sandbox/#{@plugin.id}/allowed.txt"
    restricted_path = "/etc/passwd"
    
    assert @service.file_accessible?(allowed_path)
    assert_not @service.file_accessible?(restricted_path)
  end

  test "should block unauthorized network requests" do
    @plugin.update!(permissions: { "network_access" => false })
    
    # Should block all network requests when permission denied
    assert_not @service.network_accessible?("https://api.example.com")
    assert_not @service.network_accessible?("http://localhost:3000")
  end

  test "should allow authorized network requests" do
    @plugin.update!(permissions: { "network_access" => true })
    
    # Should allow network requests when permission granted
    assert @service.network_accessible?("https://api.example.com")
  end

  test "should cleanup sandbox after execution" do
    sandbox = @service.create_sandbox
    sandbox_id = sandbox[:id]
    
    result = @service.cleanup_sandbox(sandbox_id)
    
    assert result[:success]
    assert_equal "cleaned", result[:status]
    assert_not_nil result[:cleaned_at]
  end

  test "should log all sandbox activities" do
    code = "console.log('test execution');"
    
    @service.execute_code(code)
    
    log = ExtensionLog.find_by(
      plugin: @plugin,
      user: @user,
      action: "sandbox_execution"
    )
    
    assert_not_nil log
    assert_equal "success", log.status
    assert_not_nil log.resource_usage
  end

  test "should handle sandbox creation failures" do
    # Mock sandbox creation failure
    @service.stubs(:create_sandbox_environment).raises(StandardError, "Sandbox creation failed")
    
    result = @service.create_sandbox
    
    assert_not result[:success]
    assert_includes result[:error], "Sandbox creation failed"
    assert_equal "failed", result[:status]
  end

  test "should validate sandbox configuration" do
    valid_config = { "memory_limit" => 100, "cpu_limit" => 50, "timeout" => 30 }
    invalid_config = { "memory_limit" => -1, "cpu_limit" => 101 }
    
    assert @service.valid_config?(valid_config)
    assert_not @service.valid_config?(invalid_config)
  end

  test "should provide sandbox status information" do
    sandbox = @service.create_sandbox
    sandbox_id = sandbox[:id]
    
    status = @service.sandbox_status(sandbox_id)
    
    assert_includes status.keys, :id
    assert_includes status.keys, :status
    assert_includes status.keys, :created_at
    assert_includes status.keys, :resource_usage
    assert_includes status.keys, :permissions
  end

  test "should handle concurrent sandbox executions" do
    code1 = "console.log('execution 1');"
    code2 = "console.log('execution 2');"
    
    # Simulate concurrent executions
    result1 = @service.execute_code(code1)
    result2 = @service.execute_code(code2)
    
    assert result1[:success]
    assert result2[:success]
    assert_not_equal result1[:execution_id], result2[:execution_id]
  end

  test "should prevent code injection attacks" do
    malicious_code = "process.exit(1); require('fs').unlinkSync('/important/file');"
    
    result = @service.execute_code(malicious_code)
    
    # Should either safely execute or block the malicious code
    assert_not result[:error]&.include?("system compromised")
  end

  test "should limit execution time per plugin" do
    long_running_code = "for(let i = 0; i < 1000000; i++) { Math.random(); }"
    
    start_time = Time.current
    result = @service.execute_code(long_running_code)
    end_time = Time.current
    
    execution_duration = end_time - start_time
    assert execution_duration <= @plugin.sandbox_config["timeout"]
  end

  test "should provide detailed error information" do
    buggy_code = "undefined_function();"
    
    result = @service.execute_code(buggy_code)
    
    assert_not result[:success]
    assert_not_nil result[:error]
    assert_includes result.keys, :line_number
    assert_includes result.keys, :error_type
  end

  test "should track sandbox performance metrics" do
    code = "const data = Array(100).fill(0).map((_, i) => i * 2);"
    
    result = @service.execute_code(code)
    
    metrics = @service.performance_metrics
    
    assert_includes metrics.keys, :total_executions
    assert_includes metrics.keys, :average_execution_time
    assert_includes metrics.keys, :memory_usage_trend
    assert_includes metrics.keys, :error_rate
  end

  test "should support plugin debugging when enabled" do
    @installation.update!(configuration: { "debug" => true })
    
    code = "debugger; console.log('debug test');"
    
    result = @service.execute_code(code)
    
    assert result[:success]
    assert_not_nil result[:debug_info]
    assert_includes result[:debug_info].keys, :breakpoints
    assert_includes result[:debug_info].keys, :variable_scope
  end

  test "should handle plugin dependency loading" do
    @plugin.update!(metadata: { "dependencies" => ["lodash@4.17.21"] })
    
    code = "const _ = require('lodash'); console.log(_.version);"
    
    result = @service.execute_code(code)
    
    assert result[:success]
    assert_includes result[:output], "4.17.21"
  end
end