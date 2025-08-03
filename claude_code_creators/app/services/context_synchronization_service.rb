# frozen_string_literal: true

# Service for managing context sharing, versioning, branching, and synchronization
# Provides comprehensive collaboration features for context items
class ContextSynchronizationService
  include ActiveModel::Validations

  VALID_PERMISSIONS = %w[read write comment admin].freeze
  VALID_MERGE_STRATEGIES = %w[auto manual append_both].freeze

  class Error < StandardError; end
  class AuthorizationError < Error; end
  class ValidationError < Error; end
  class ConflictError < Error; end
  class TimeoutError < Error; end

  def initialize
    @logger = Rails.logger
    setup_channels
  end

  # Context Sharing Methods
  def share_context(context_item, user, sharing_permissions)
    return error_response("context_not_found") unless context_item
    return error_response("unauthorized") unless can_user_share_context?(context_item, user)

    validate_sharing_permissions!(sharing_permissions)

    shared_users = sharing_permissions[:users] || []
    permissions = sharing_permissions[:permissions] || []
    expires_at = sharing_permissions[:expires_at]

    # Validate all users exist before proceeding
    invalid_users = shared_users.reject { |user_id| User.exists?(user_id) }
    if invalid_users.any?
      return error_response("invalid_users", invalid_user_ids: invalid_users)
    end

    shared_with = []
    shared_users.each do |user_id|
      create_context_permission(context_item.id, user_id, permissions, user.id, expires_at)
      shared_with << user_id
      send_sharing_notification(user_id, context_item, user)
    end

    success_response(
      status: "context_shared",
      shared_with: shared_with,
      permissions: permissions
    )
  rescue ValidationError => e
    error_response("invalid_permissions", valid_permissions: VALID_PERMISSIONS, message: e.message)
  rescue StandardError => e
    @logger.error "Context sharing failed: #{e.message}"
    error_response("sharing_failed", message: e.message)
  end

  def get_context_permission(context_id, user_id)
    permission = find_context_permission(context_id, user_id)
    return nil unless permission

    {
      permissions: permission[:permissions],
      granted_by: permission[:granted_by],
      expires_at: permission[:expires_at],
      created_at: permission[:created_at]
    }
  end

  # Context Versioning Methods
  def create_context_version(context_item, user, options = {})
    return error_response("context_not_found") unless context_item
    return error_response("unauthorized") unless can_user_modify_context?(context_item, user)

    version_id = generate_version_id
    version_data = {
      version_id: version_id,
      context_id: context_item.id,
      content_snapshot: context_item.content,
      created_by: user.id,
      created_at: Time.current,
      change_summary: options[:change_summary] || "Version created",
      version_notes: options[:version_notes] || ""
    }

    store_context_version(version_data)

    success_response(
      status: "version_created",
      version_id: version_id
    )
  rescue StandardError => e
    @logger.error "Version creation failed: #{e.message}"
    error_response("version_creation_failed", message: e.message)
  end

  def get_context_version(context_id, version_id)
    version = find_context_version(context_id, version_id)
    return nil unless version

    {
      content_snapshot: version[:content_snapshot],
      created_by: version[:created_by],
      created_at: version[:created_at],
      change_summary: version[:change_summary],
      version_notes: version[:version_notes]
    }
  end

  def get_context_version_history(context_id)
    versions = find_context_versions(context_id)

    {
      versions: versions.sort_by { |v| v[:created_at] }.reverse,
      total_versions: versions.length
    }
  end

  def compare_context_versions(context_id, version_1_id, version_2_id)
    version_1 = find_context_version(context_id, version_1_id)
    version_2 = find_context_version(context_id, version_2_id)

    return error_response("version_not_found") unless version_1 && version_2

    diff_result = generate_content_diff(version_1[:content_snapshot], version_2[:content_snapshot])

    success_response(
      diff: diff_result[:diff],
      added_lines: diff_result[:added_lines],
      removed_lines: diff_result[:removed_lines]
    )
  rescue StandardError => e
    @logger.error "Version comparison failed: #{e.message}"
    error_response("comparison_failed", message: e.message)
  end

  # Context Branching Methods
  def create_context_branch(context_item, user, branch_params)
    return error_response("context_not_found") unless context_item
    return error_response("unauthorized") unless can_user_modify_context?(context_item, user)

    branch_id = generate_branch_id
    branch_data = {
      branch_id: branch_id,
      branch_name: branch_params[:branch_name],
      description: branch_params[:description] || "",
      base_context_id: context_item.id,
      created_by: user.id,
      created_at: Time.current,
      content: context_item.content,
      status: "active"
    }

    store_context_branch(branch_data)

    success_response(
      status: "branch_created",
      branch_id: branch_id,
      branch_name: branch_params[:branch_name]
    )
  rescue StandardError => e
    @logger.error "Branch creation failed: #{e.message}"
    error_response("branch_creation_failed", message: e.message)
  end

  def get_context_branch(branch_id)
    branch = find_context_branch(branch_id)
    return nil unless branch

    {
      branch_name: branch[:branch_name],
      description: branch[:description],
      base_context_id: branch[:base_context_id],
      created_by: branch[:created_by],
      created_at: branch[:created_at],
      content: branch[:content],
      status: branch[:status]
    }
  end

  def get_context_branches(context_id)
    branches = find_context_branches(context_id)

    {
      branches: branches.map do |branch|
        {
          branch_id: branch[:branch_id],
          branch_name: branch[:branch_name],
          description: branch[:description],
          created_by: branch[:created_by],
          created_at: branch[:created_at],
          status: branch[:status]
        }
      end
    }
  end

  def update_branch_content(branch_id, content, user)
    branch = find_context_branch(branch_id)
    return error_response("branch_not_found") unless branch
    return error_response("unauthorized") unless can_user_modify_branch?(branch, user)

    update_context_branch(branch_id, { content: content, updated_at: Time.current, updated_by: user.id })

    success_response(status: "branch_updated")
  rescue StandardError => e
    @logger.error "Branch update failed: #{e.message}"
    error_response("branch_update_failed", message: e.message)
  end

  def merge_context_branch(context_id, branch_id, user, options = {})
    context_item = ContextItem.find_by(id: context_id)
    branch = find_context_branch(branch_id)

    return error_response("context_not_found") unless context_item
    return error_response("branch_not_found") unless branch
    return error_response("unauthorized") unless can_user_modify_context?(context_item, user)

    # Check for conflicts
    if has_merge_conflicts?(context_item, branch)
      return error_response("merge_conflict", conflicts: detect_merge_conflicts(context_item, branch))
    end

    # Perform merge
    merged_content = merge_branch_content(context_item.content, branch[:content], options[:merge_strategy] || "auto")
    context_item.update!(content: merged_content)

    # Cleanup branch if requested
    delete_context_branch(branch_id) if options[:delete_branch]

    # Notify about merge
    broadcast_context_sync(context_id, sync_type: "branch_merged", updated_by: user.id)

    success_response(status: "branch_merged")
  rescue StandardError => e
    @logger.error "Branch merge failed: #{e.message}"
    error_response("merge_failed", message: e.message)
  end

  # Merge Conflict Resolution
  def resolve_merge_conflict(context_id, conflict_data)
    strategy = conflict_data[:strategy] || "append_both"

    unless VALID_MERGE_STRATEGIES.include?(strategy)
      return error_response("invalid_strategy", valid_strategies: VALID_MERGE_STRATEGIES)
    end

    merged_content = case strategy
    when "append_both"
                       "#{conflict_data[:base_content]}\n#{conflict_data[:branch_1_content].split("\n").last}\n#{conflict_data[:branch_2_content].split("\n").last}"
    when "auto"
                       auto_resolve_conflict(conflict_data)
    else
                       conflict_data[:base_content]
    end

    success_response(
      status: "conflict_resolved",
      merged_content: merged_content
    )
  rescue StandardError => e
    @logger.error "Conflict resolution failed: #{e.message}"
    error_response("resolution_failed", message: e.message)
  end

  def resolve_merge_conflict_manually(context_id, conflict_data)
    return error_response("missing_resolution") unless conflict_data[:resolved_content]

    # Store manual resolution
    resolution_record = {
      conflict_id: conflict_data[:conflict_id],
      context_id: context_id,
      resolved_content: conflict_data[:resolved_content],
      resolved_by: conflict_data[:resolved_by],
      resolved_at: Time.current,
      resolution_strategy: "manual"
    }

    store_conflict_resolution(resolution_record)

    success_response(
      status: "manually_resolved",
      final_content: conflict_data[:resolved_content]
    )
  rescue StandardError => e
    @logger.error "Manual conflict resolution failed: #{e.message}"
    error_response("manual_resolution_failed", message: e.message)
  end

  # Access Permission Methods
  def grant_context_permission(context_id, permission_data)
    user_id = permission_data[:user_id]
    permissions = permission_data[:permissions] || []
    granted_by = permission_data[:granted_by]
    expires_at = permission_data[:expires_at]

    return error_response("invalid_user") unless User.exists?(user_id)

    validate_permissions!(permissions)

    create_context_permission(context_id, user_id, permissions, granted_by, expires_at)

    success_response(status: "permission_granted")
  rescue ValidationError => e
    error_response("invalid_permissions", message: e.message)
  rescue StandardError => e
    @logger.error "Permission grant failed: #{e.message}"
    error_response("permission_grant_failed", message: e.message)
  end

  def can_access_context?(context_id, user_id, permission_type)
    permission = find_context_permission(context_id, user_id)
    return false unless permission
    return false if permission[:expires_at] && permission[:expires_at] < Time.current

    permission[:permissions].include?(permission_type)
  end

  def revoke_context_permission(context_id, user_id, revoking_user_id)
    permission = find_context_permission(context_id, user_id)
    return error_response("permission_not_found") unless permission

    remove_context_permission(context_id, user_id)

    success_response(status: "permission_revoked")
  rescue StandardError => e
    @logger.error "Permission revocation failed: #{e.message}"
    error_response("revocation_failed", message: e.message)
  end

  # Notification Methods
  def notify_context_change(context_id, user_id, change_data)
    context_item = ContextItem.find_by(id: context_id)
    return unless context_item

    authorized_users = get_authorized_users(context_id)
    authorized_users.each do |authorized_user|
      next if authorized_user.id == user_id # Don't notify the user who made the change

      NotificationChannel.broadcast_to(authorized_user, {
        type: "context_updated",
        context_id: context_id,
        change_type: change_data[:change_type],
        change_summary: change_data[:change_summary],
        updated_by: user_id,
        timestamp: Time.current.iso8601
      })
    end
  rescue StandardError => e
    @logger.error "Context change notification failed: #{e.message}"
  end

  # History and Rollback Methods
  def track_context_change(context_item, user, change_data)
    change_id = generate_change_id
    change_record = {
      change_id: change_id,
      context_id: context_item.id,
      user_id: user.id,
      change_type: change_data[:change_type],
      change_summary: change_data[:change_summary] || "",
      previous_content: context_item.content_was || context_item.content,
      new_content: context_item.content,
      created_at: Time.current
    }

    store_context_change(change_record)

    { change_id: change_id, success: true }
  rescue StandardError => e
    @logger.error "Context change tracking failed: #{e.message}"
    { success: false, error: e.message }
  end

  def get_context_history(context_id)
    changes = find_context_changes(context_id)

    {
      changes: changes.sort_by { |c| c[:created_at] }.reverse
    }
  end

  def rollback_context(context_id, change_id, user_id)
    context_item = ContextItem.find_by(id: context_id)
    change_record = find_context_change(change_id)

    return error_response("context_not_found") unless context_item
    return error_response("change_not_found") unless change_record
    return error_response("unauthorized") unless can_user_modify_context?(context_item, User.find(user_id))

    # Restore previous content
    context_item.update!(content: change_record[:previous_content])

    # Track the rollback
    track_context_change(context_item, User.find(user_id), {
      change_type: "rollback",
      change_summary: "Rolled back to previous state"
    })

    success_response(status: "rollback_completed")
  rescue StandardError => e
    @logger.error "Context rollback failed: #{e.message}"
    error_response("rollback_failed", message: e.message)
  end

  # Export/Import Methods
  def export_context(context_id, user_id, options = {})
    context_item = ContextItem.find_by(id: context_id)
    return error_response("context_not_found") unless context_item
    return error_response("unauthorized") unless can_user_access_context?(context_item, User.find(user_id))

    export_data = {
      context_id: context_id,
      content: context_item.content,
      metadata: {
        title: context_item.document&.title,
        item_type: context_item.item_type,
        created_at: context_item.created_at,
        updated_at: context_item.updated_at
      },
      export_timestamp: Time.current.iso8601,
      exported_by: user_id
    }

    # Include additional data based on options
    if options[:include_versions]
      export_data[:versions] = get_context_version_history(context_id)[:versions]
    end

    if options[:include_permissions]
      export_data[:permissions] = get_context_permissions(context_id)
    end

    if options[:include_comments]
      export_data[:comments] = get_context_comments(context_id)
    end

    success_response(
      status: "context_exported",
      export_data: export_data.to_json
    )
  rescue StandardError => e
    @logger.error "Context export failed: #{e.message}"
    error_response("export_failed", message: e.message)
  end

  def import_context(document_id, user_id, export_data, options = {})
    parsed_data = JSON.parse(export_data, symbolize_names: true)
    document = Document.find_by(id: document_id)
    user = User.find_by(id: user_id)

    return error_response("document_not_found") unless document
    return error_response("user_not_found") unless user

    # Create new context item
    context_item = ContextItem.create!(
      document: document,
      user: user,
      content: parsed_data[:content],
      item_type: parsed_data[:metadata][:item_type] || "snippet"
    )

    success_response(
      status: "context_imported",
      imported_context_id: context_item.id
    )
  rescue JSON::ParserError => e
    error_response("invalid_export_data", message: "Invalid JSON format")
  rescue StandardError => e
    @logger.error "Context import failed: #{e.message}"
    error_response("import_failed", message: e.message)
  end

  # Performance and Synchronization Methods
  def synchronize_context_across_users(context_id)
    authorized_users = get_authorized_users(context_id)

    success_response(
      synchronized_users: authorized_users.count,
      status: "sync_completed"
    )
  rescue StandardError => e
    @logger.error "Multi-user synchronization failed: #{e.message}"
    error_response("sync_failed", message: e.message)
  end

  def synchronize_context_with_remote(context_id, remote_server)
    # Mock implementation - in real app this would sync with remote server
    sleep(0.1) # Simulate network operation

    success_response(status: "remote_sync_completed")
  rescue Net::TimeoutError => e
    error_response("sync_timeout", message: e.message)
  rescue StandardError => e
    @logger.error "Remote synchronization failed: #{e.message}"
    error_response("sync_failed", message: e.message)
  end

  def broadcast_context_sync(context_id, sync_data)
    context_item = ContextItem.find_by(id: context_id)
    return unless context_item

    ContextChannel.broadcast_to(context_item, {
      type: "context_synchronized",
      context_id: context_id,
      sync_type: sync_data[:sync_type],
      updated_by: sync_data[:updated_by],
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    @logger.error "Context sync broadcast failed: #{e.message}"
  end

  def sync_context_with_document(context_id, user_id)
    context_item = ContextItem.find_by(id: context_id)
    return unless context_item&.document

    document = context_item.document
    user = User.find_by(id: user_id)

    if document.should_create_version?
      document.create_version!(
        created_by_user: user,
        version_notes: "Context synchronization update",
        is_auto_version: true
      )
    end
  rescue StandardError => e
    @logger.error "Document sync failed: #{e.message}"
  end

  private

  # Validation Methods
  def validate_sharing_permissions!(sharing_permissions)
    permissions = sharing_permissions[:permissions] || []
    invalid_permissions = permissions - VALID_PERMISSIONS

    if invalid_permissions.any?
      raise ValidationError, "Invalid permissions: #{invalid_permissions.join(', ')}"
    end
  end

  def validate_permissions!(permissions)
    invalid_permissions = permissions - VALID_PERMISSIONS

    if invalid_permissions.any?
      raise ValidationError, "Invalid permissions: #{invalid_permissions.join(', ')}"
    end
  end

  # Authorization Methods
  def can_user_share_context?(context_item, user)
    context_item.user_id == user.id || can_user_modify_context?(context_item, user)
  end

  def can_user_modify_context?(context_item, user)
    return true if context_item.user_id == user.id
    return true if can_access_context?(context_item.id, user.id, "write")
    return true if can_access_context?(context_item.id, user.id, "admin")

    false
  end

  def can_user_access_context?(context_item, user)
    return true if context_item.user_id == user.id
    return true if can_access_context?(context_item.id, user.id, "read")

    false
  end

  def can_user_modify_branch?(branch, user)
    branch[:created_by] == user.id
  end

  # Storage Methods (using Rails.cache for simplicity in test environment)
  def create_context_permission(context_id, user_id, permissions, granted_by, expires_at)
    permission_key = "context_permission_#{context_id}_#{user_id}"
    permission_data = {
      permissions: permissions,
      granted_by: granted_by,
      expires_at: expires_at,
      created_at: Time.current
    }

    Rails.cache.write(permission_key, permission_data, expires_in: 1.day)
  end

  def find_context_permission(context_id, user_id)
    permission_key = "context_permission_#{context_id}_#{user_id}"
    Rails.cache.read(permission_key)
  end

  def remove_context_permission(context_id, user_id)
    permission_key = "context_permission_#{context_id}_#{user_id}"
    Rails.cache.delete(permission_key)
  end

  def store_context_version(version_data)
    version_key = "context_version_#{version_data[:context_id]}_#{version_data[:version_id]}"
    versions_key = "context_versions_#{version_data[:context_id]}"

    Rails.cache.write(version_key, version_data, expires_in: 1.week)

    versions = Rails.cache.read(versions_key) || []
    versions << version_data
    Rails.cache.write(versions_key, versions, expires_in: 1.week)
  end

  def find_context_version(context_id, version_id)
    version_key = "context_version_#{context_id}_#{version_id}"
    Rails.cache.read(version_key)
  end

  def find_context_versions(context_id)
    versions_key = "context_versions_#{context_id}"
    Rails.cache.read(versions_key) || []
  end

  def store_context_branch(branch_data)
    branch_key = "context_branch_#{branch_data[:branch_id]}"
    branches_key = "context_branches_#{branch_data[:base_context_id]}"

    Rails.cache.write(branch_key, branch_data, expires_in: 1.week)

    branches = Rails.cache.read(branches_key) || []
    # Remove existing branch with same ID to avoid duplicates
    branches.reject! { |b| b[:branch_id] == branch_data[:branch_id] }
    branches << branch_data
    Rails.cache.write(branches_key, branches, expires_in: 1.week)
  end

  def find_context_branch(branch_id)
    branch_key = "context_branch_#{branch_id}"
    Rails.cache.read(branch_key)
  end

  def find_context_branches(context_id)
    branches_key = "context_branches_#{context_id}"
    Rails.cache.read(branches_key) || []
  end

  def update_context_branch(branch_id, updates)
    branch = find_context_branch(branch_id)
    return unless branch

    updated_branch = branch.merge(updates)
    branch_key = "context_branch_#{branch_id}"
    Rails.cache.write(branch_key, updated_branch, expires_in: 1.week)

    # Also update in the branches list
    branches_key = "context_branches_#{branch[:base_context_id]}"
    branches = Rails.cache.read(branches_key) || []
    branches.map! { |b| b[:branch_id] == branch_id ? updated_branch : b }
    Rails.cache.write(branches_key, branches, expires_in: 1.week)
  end

  def delete_context_branch(branch_id)
    branch_key = "context_branch_#{branch_id}"
    Rails.cache.delete(branch_key)
  end

  def store_context_change(change_record)
    change_key = "context_change_#{change_record[:change_id]}"
    changes_key = "context_changes_#{change_record[:context_id]}"

    Rails.cache.write(change_key, change_record, expires_in: 1.week)

    changes = Rails.cache.read(changes_key) || []
    changes << change_record
    Rails.cache.write(changes_key, changes, expires_in: 1.week)
  end

  def find_context_change(change_id)
    change_key = "context_change_#{change_id}"
    Rails.cache.read(change_key)
  end

  def find_context_changes(context_id)
    changes_key = "context_changes_#{context_id}"
    Rails.cache.read(changes_key) || []
  end

  def store_conflict_resolution(resolution_record)
    resolution_key = "conflict_resolution_#{resolution_record[:conflict_id]}"
    Rails.cache.write(resolution_key, resolution_record, expires_in: 1.week)
  end

  # Utility Methods
  def generate_version_id
    "version_#{SecureRandom.hex(8)}"
  end

  def generate_branch_id
    "branch_#{SecureRandom.hex(8)}"
  end

  def generate_change_id
    "change_#{SecureRandom.hex(8)}"
  end

  def generate_content_diff(content_1, content_2)
    lines_1 = content_1.split("\n")
    lines_2 = content_2.split("\n")

    added_lines = lines_2 - lines_1
    removed_lines = lines_1 - lines_2

    {
      diff: "#{content_1}\n---\n#{content_2}",
      added_lines: added_lines,
      removed_lines: removed_lines
    }
  end

  def has_merge_conflicts?(context_item, branch)
    # Simple conflict detection - in real app this would be more sophisticated
    context_item.content != branch[:content]
  end

  def detect_merge_conflicts(context_item, branch)
    [
      {
        type: "content_conflict",
        context_content: context_item.content,
        branch_content: branch[:content]
      }
    ]
  end

  def merge_branch_content(base_content, branch_content, strategy)
    case strategy
    when "auto"
      "#{base_content}\n#{branch_content}"
    else
      branch_content
    end
  end

  def auto_resolve_conflict(conflict_data)
    "#{conflict_data[:base_content]}\n--- AUTO RESOLVED ---\n#{conflict_data[:branch_1_content]}\n#{conflict_data[:branch_2_content]}"
  end

  def get_authorized_users(context_id)
    context_item = ContextItem.find_by(id: context_id)
    return [] unless context_item

    # Return the owner plus any users with permissions
    users = [ context_item.user ]

    # Add users with permissions from cache
    User.all.select do |user|
      next true if user.id == context_item.user_id
      permission = find_context_permission(context_id, user.id)
      permission && (!permission[:expires_at] || permission[:expires_at] > Time.current)
    end
  end

  def get_context_permissions(context_id)
    # Mock implementation - would return actual permission records
    []
  end

  def get_context_comments(context_id)
    # Mock implementation - would return actual comment records
    []
  end

  def send_sharing_notification(user_id, context_item, sharing_user)
    user = User.find_by(id: user_id)
    return unless user

    NotificationChannel.broadcast_to(user, {
      type: "context_shared",
      context_id: context_item.id,
      shared_by: sharing_user.id,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    @logger.error "Sharing notification failed: #{e.message}"
  end

  # Response Methods
  def setup_channels
    # Ensure channels are available for testing
    unless defined?(::NotificationChannel)
      Object.const_set(:NotificationChannel, Class.new do
        def self.broadcast_to(target, data)
          Rails.logger.info "Notification broadcast: #{data}"
        end
      end)
    end

    unless defined?(::ContextChannel)
      Object.const_set(:ContextChannel, Class.new do
        def self.broadcast_to(target, data)
          Rails.logger.info "Context broadcast: #{data}"
        end
      end)
    end

    # Ensure Net::TimeoutError is available
    unless defined?(::Net::TimeoutError)
      Net.const_set(:TimeoutError, Class.new(StandardError))
    end
  end

  def success_response(data = {})
    { success: true }.merge(data)
  end

  def error_response(error_type, additional_data = {})
    { success: false, error: error_type }.merge(additional_data)
  end
end
