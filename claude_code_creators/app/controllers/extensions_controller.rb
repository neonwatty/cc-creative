class ExtensionsController < ApplicationController
  before_action :authenticate_user!
  before_action :find_plugin, only: [ :show, :install, :uninstall, :enable, :disable, :configure, :status, :health, :execute, :documentation, :update ]
  before_action :rate_limit_check, only: [ :install, :uninstall, :execute ]

  # GET /extensions
  def index
    @plugins = Plugin.active.includes(:plugin_installations)

    # Apply filters
    @plugins = @plugins.by_category(params[:category]) if params[:category].present?
    @plugins = @plugins.search(params[:search]) if params[:search].present?

    # Sort options
    @plugins = case params[:sort]
    when "name" then @plugins.order(:name)
    when "author" then @plugins.order(:author)
    when "category" then @plugins.order(:category)
    else @plugins.order(:created_at)
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          plugins: @plugins.map { |plugin| plugin_summary(plugin) },
          total: @plugins.count,
          categories: Plugin.distinct.pluck(:category),
          filters: {
            category: params[:category],
            search: params[:search],
            sort: params[:sort]
          }
        }
      end
    end
  end

  # GET /extensions/:id
  def show
    @installation = @plugin.installation_for(current_user)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          plugin: plugin_detail(@plugin),
          installation: @installation ? installation_detail(@installation) : nil,
          compatibility: @plugin.compatible_with_platform?,
          permissions_required: @plugin.requires_permissions?
        }
      end
    end
  end

  # POST /extensions/:id/install
  def install
    result = plugin_manager.install_plugin(@plugin.id)

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # DELETE /extensions/:id/uninstall
  def uninstall
    result = plugin_manager.uninstall_plugin(@plugin.id)

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # PATCH /extensions/:id/enable
  def enable
    result = plugin_manager.enable_plugin(@plugin.id)

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # PATCH /extensions/:id/disable
  def disable
    result = plugin_manager.disable_plugin(@plugin.id)

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # PATCH /extensions/:id/configure
  def configure
    configuration = params[:configuration] || {}
    result = plugin_manager.configure_plugin(@plugin.id, configuration)

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # GET /extensions/installed
  def installed
    installations = plugin_manager.installed_plugins.includes(:plugin)

    render json: {
      plugins: installations.map { |installation|
        {
          id: installation.plugin.id,
          name: installation.plugin.name,
          version: installation.plugin.version,
          status: installation.status,
          installed_at: installation.installed_at,
          last_used_at: installation.last_used_at,
          configuration: installation.configuration
        }
      }
    }
  end

  # GET /extensions/:id/status
  def status
    installation = @plugin.installation_for(current_user)

    if installation
      render json: {
        status: installation.status,
        installed_at: installation.installed_at,
        last_used_at: installation.last_used_at,
        configuration: installation.configuration,
        days_since_install: installation.days_since_install
      }
    else
      render json: { status: "not_installed" }
    end
  end

  # GET /extensions/:id/health
  def health
    health_data = plugin_manager.plugin_health(@plugin.id)
    render json: health_data
  end

  # POST /extensions/:id/execute
  def execute
    installation = @plugin.installation_for(current_user)

    unless installation&.active?
      return render json: {
        success: false,
        error: "Plugin is not installed or is disabled"
      }, status: :unprocessable_entity
    end

    command_data = params[:command] || {}

    begin
      result = plugin_manager.execute_plugin_command(@plugin.id, command_data)
      render json: result
    rescue StandardError => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /extensions/marketplace
  def marketplace
    featured_plugins = Plugin.active.limit(6)
    recent_plugins = Plugin.active.order(created_at: :desc).limit(10)
    categories = Plugin.active.group(:category).count

    render json: {
      featured: featured_plugins.map { |plugin| plugin_summary(plugin) },
      recent: recent_plugins.map { |plugin| plugin_summary(plugin) },
      categories: categories,
      stats: {
        total_plugins: Plugin.active.count,
        total_installs: PluginInstallation.installed.count,
        total_categories: categories.keys.count
      }
    }
  end

  # GET /extensions/:id/documentation
  def documentation
    docs = @plugin.documentation

    if docs.present?
      render json: {
        documentation: docs,
        format: "markdown",
        last_updated: @plugin.updated_at
      }
    else
      render json: {
        documentation: "No documentation available for this plugin.",
        format: "text"
      }
    end
  end

  # PATCH /extensions/:id/update
  def update
    new_version_id = params[:new_version_id]

    unless new_version_id
      return render json: {
        success: false,
        error: "New version ID is required"
      }, status: :unprocessable_entity
    end

    result = plugin_manager.update_plugin(@plugin.id, new_version_id)

    if result[:success]
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # POST /extensions/bulk_install
  def bulk_install
    plugin_ids = params[:plugin_ids] || []

    results = plugin_ids.map do |plugin_id|
      result = plugin_manager.install_plugin(plugin_id)
      { plugin_id: plugin_id, success: result[:success], message: result[:message] || result[:error] }
    end

    render json: { results: results }
  end

  private

  def find_plugin
    @plugin = Plugin.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Plugin not found" }, status: :not_found
  end

  def plugin_manager
    @plugin_manager ||= PluginManagerService.new(current_user)
  end

  def plugin_summary(plugin)
    installation = plugin.installation_for(current_user)

    {
      id: plugin.id,
      name: plugin.name,
      version: plugin.version,
      description: plugin.description,
      author: plugin.author,
      category: plugin.category,
      icon_url: plugin.icon_url,
      homepage_url: plugin.homepage_url,
      license: plugin.license,
      keywords: plugin.keywords,
      installation_status: installation ? installation.status : "not_installed",
      compatible: plugin.compatible_with_platform?,
      requires_permissions: plugin.requires_permissions?
    }
  end

  def plugin_detail(plugin)
    installation = plugin.installation_for(current_user)

    {
      id: plugin.id,
      name: plugin.name,
      version: plugin.version,
      description: plugin.description,
      author: plugin.author,
      category: plugin.category,
      status: plugin.status,
      metadata: plugin.metadata,
      permissions: plugin.permissions,
      sandbox_config: plugin.sandbox_config,
      icon_url: plugin.icon_url,
      homepage_url: plugin.homepage_url,
      repository_url: plugin.repository_url,
      license: plugin.license,
      keywords: plugin.keywords,
      dependencies: plugin.dependencies,
      api_version: plugin.api_version,
      created_at: plugin.created_at,
      updated_at: plugin.updated_at,
      installation_status: installation ? installation.status : "not_installed",
      compatible: plugin.compatible_with_platform?,
      requires_permissions: plugin.requires_permissions?
    }
  end

  def installation_detail(installation)
    {
      status: installation.status,
      installed_at: installation.installed_at,
      last_used_at: installation.last_used_at,
      configuration: installation.configuration,
      days_since_install: installation.days_since_install,
      performance: installation.performance_summary
    }
  end

  def rate_limit_check
    # Simple rate limiting - in production use Redis or similar
    session[:plugin_actions] ||= []
    session[:plugin_actions] << Time.current

    # Keep only actions from last 5 minutes
    session[:plugin_actions].reject! { |time| time < 5.minutes.ago }

    if session[:plugin_actions].count > 10
      render json: {
        error: "Rate limit exceeded. Please try again later."
      }, status: :too_many_requests
    end
  end
end
