# frozen_string_literal: true

require "test_helper"

class ContextSynchronizationServiceTest < ActiveSupport::TestCase
  setup do
    @service = ContextSynchronizationService.new
    @user = users(:one)
    @other_user = users(:two)
    @document = documents(:one)
    @context_item = context_items(:one)
  end

  # Context Sharing Tests
  test "shares context with authorized users" do
    sharing_permissions = {
      users: [ @other_user.id ],
      permissions: [ "read", "comment" ],
      expires_at: 1.week.from_now
    }

    result = @service.share_context(@context_item, @user, sharing_permissions)

    assert result[:success]
    assert_equal "context_shared", result[:status]
    assert_includes result[:shared_with], @other_user.id

    # Verify permission record created
    permission = @service.get_context_permission(@context_item.id, @other_user.id)
    assert permission.present?
    assert_includes permission[:permissions], "read"
    assert_includes permission[:permissions], "comment"
  end

  test "prevents unauthorized context sharing" do
    unauthorized_context = ContextItem.create!(
      document: @document,
      user: @other_user,
      content: "Private context",
      item_type: "snippet"
    )

    sharing_permissions = {
      users: [ @user.id ],
      permissions: [ "read" ]
    }

    result = @service.share_context(unauthorized_context, @user, sharing_permissions)

    assert_not result[:success]
    assert_equal "unauthorized", result[:error]
  end

  test "validates sharing permissions" do
    invalid_permissions = {
      users: [ @other_user.id ],
      permissions: [ "invalid_permission" ]
    }

    result = @service.share_context(@context_item, @user, invalid_permissions)

    assert_not result[:success]
    assert_equal "invalid_permissions", result[:error]
    assert_includes result[:valid_permissions], "read"
    assert_includes result[:valid_permissions], "write"
    assert_includes result[:valid_permissions], "comment"
    assert_includes result[:valid_permissions], "admin"
  end

  # Context Versioning Tests
  test "creates context version on significant changes" do
    original_content = @context_item.content
    new_content = "Significantly updated content with major changes"

    version_result = @service.create_context_version(@context_item, @user, {
      change_summary: "Major content update",
      version_notes: "Updated for collaboration features"
    })

    assert version_result[:success]
    assert_equal "version_created", version_result[:status]
    assert_present version_result[:version_id]

    # Verify version data
    version = @service.get_context_version(@context_item.id, version_result[:version_id])
    assert_equal original_content, version[:content_snapshot]
    assert_equal @user.id, version[:created_by]
    assert_equal "Major content update", version[:change_summary]
  end

  test "tracks context version history" do
    # Create multiple versions
    3.times do |i|
      @context_item.update!(content: "Version #{i + 1} content")
      @service.create_context_version(@context_item, @user, {
        change_summary: "Update #{i + 1}",
        version_notes: "Test version #{i + 1}"
      })
    end

    history = @service.get_context_version_history(@context_item.id)

    assert_equal 3, history[:versions].length
    assert history[:versions].all? { |v| v[:created_by] == @user.id }
    assert_equal "Update 3", history[:versions].first[:change_summary] # Most recent first
  end

  test "enables context version comparison" do
    # Create initial version
    @context_item.update!(content: "Original content")
    version_1 = @service.create_context_version(@context_item, @user, {
      change_summary: "Initial version"
    })

    # Update and create second version
    @context_item.update!(content: "Updated content with changes")
    version_2 = @service.create_context_version(@context_item, @user, {
      change_summary: "Updated version"
    })

    comparison = @service.compare_context_versions(
      @context_item.id,
      version_1[:version_id],
      version_2[:version_id]
    )

    assert comparison[:success]
    assert_present comparison[:diff]
    assert_includes comparison[:diff], "Original content"
    assert_includes comparison[:diff], "Updated content with changes"
    assert_present comparison[:added_lines]
    assert_present comparison[:removed_lines]
  end

  # Context Branching Tests
  test "creates context branch for parallel editing" do
    branch_params = {
      branch_name: "feature-enhancement",
      description: "Working on new features",
      base_version: @context_item.id
    }

    branch_result = @service.create_context_branch(@context_item, @user, branch_params)

    assert branch_result[:success]
    assert_equal "branch_created", branch_result[:status]
    assert_present branch_result[:branch_id]
    assert_equal "feature-enhancement", branch_result[:branch_name]

    # Verify branch data
    branch = @service.get_context_branch(branch_result[:branch_id])
    assert_equal @context_item.id, branch[:base_context_id]
    assert_equal @user.id, branch[:created_by]
    assert_equal "Working on new features", branch[:description]
  end

  test "manages parallel context branches" do
    # Create multiple branches
    branch_1 = @service.create_context_branch(@context_item, @user, {
      branch_name: "feature-a",
      description: "Feature A development"
    })

    branch_2 = @service.create_context_branch(@context_item, @other_user, {
      branch_name: "feature-b",
      description: "Feature B development"
    })

    branches = @service.get_context_branches(@context_item.id)

    assert_equal 2, branches[:branches].length
    branch_names = branches[:branches].map { |b| b[:branch_name] }
    assert_includes branch_names, "feature-a"
    assert_includes branch_names, "feature-b"
  end

  test "merges context branches" do
    # Create branch with changes
    branch = @service.create_context_branch(@context_item, @user, {
      branch_name: "test-branch",
      description: "Test branch for merging"
    })

    # Make changes to branch
    branch_content = "Updated content in branch"
    @service.update_branch_content(branch[:branch_id], branch_content, @user)

    # Merge branch back to main
    merge_result = @service.merge_context_branch(
      @context_item.id,
      branch[:branch_id],
      @user,
      {
        merge_strategy: "auto",
        delete_branch: true
      }
    )

    assert merge_result[:success]
    assert_equal "branch_merged", merge_result[:status]

    # Verify content updated
    @context_item.reload
    assert_includes @context_item.content, branch_content
  end

  # Context Merge Conflict Resolution Tests
  test "detects context merge conflicts" do
    # Create two branches with conflicting changes
    branch_1 = @service.create_context_branch(@context_item, @user, {
      branch_name: "branch-1"
    })
    branch_2 = @service.create_context_branch(@context_item, @other_user, {
      branch_name: "branch-2"
    })

    # Make conflicting changes
    @service.update_branch_content(branch_1[:branch_id], "Content from branch 1", @user)
    @service.update_branch_content(branch_2[:branch_id], "Content from branch 2", @other_user)

    # Attempt to merge both
    @service.merge_context_branch(@context_item.id, branch_1[:branch_id], @user)
    merge_result = @service.merge_context_branch(@context_item.id, branch_2[:branch_id], @other_user)

    assert_not merge_result[:success]
    assert_equal "merge_conflict", merge_result[:error]
    assert_present merge_result[:conflicts]
    assert_includes merge_result[:conflicts].first[:type], "content_conflict"
  end

  test "resolves context merge conflicts automatically" do
    original_content = @context_item.content

    # Create conflicting changes
    conflict_data = {
      base_content: original_content,
      branch_1_content: "#{original_content}\nAddition from branch 1",
      branch_2_content: "#{original_content}\nAddition from branch 2",
      strategy: "append_both"
    }

    resolution = @service.resolve_merge_conflict(@context_item.id, conflict_data)

    assert resolution[:success]
    assert_equal "conflict_resolved", resolution[:status]
    assert_includes resolution[:merged_content], "Addition from branch 1"
    assert_includes resolution[:merged_content], "Addition from branch 2"
  end

  test "handles manual conflict resolution" do
    conflict_data = {
      conflict_id: "conflict_123",
      resolution_strategy: "manual",
      resolved_content: "Manually resolved content",
      resolved_by: @user.id
    }

    resolution = @service.resolve_merge_conflict_manually(@context_item.id, conflict_data)

    assert resolution[:success]
    assert_equal "manually_resolved", resolution[:status]
    assert_equal "Manually resolved content", resolution[:final_content]
  end

  # Context Access Permissions Tests
  test "manages context access permissions" do
    permission_data = {
      user_id: @other_user.id,
      permissions: [ "read", "comment" ],
      granted_by: @user.id,
      expires_at: 1.month.from_now
    }

    result = @service.grant_context_permission(@context_item.id, permission_data)

    assert result[:success]
    assert_equal "permission_granted", result[:status]

    # Verify permission exists
    permission = @service.get_context_permission(@context_item.id, @other_user.id)
    assert_includes permission[:permissions], "read"
    assert_includes permission[:permissions], "comment"
    assert_equal @user.id, permission[:granted_by]
  end

  test "validates context access permissions" do
    # Test read permission
    @service.grant_context_permission(@context_item.id, {
      user_id: @other_user.id,
      permissions: [ "read" ],
      granted_by: @user.id
    })

    can_read = @service.can_access_context?(@context_item.id, @other_user.id, "read")
    can_write = @service.can_access_context?(@context_item.id, @other_user.id, "write")

    assert can_read
    assert_not can_write
  end

  test "revokes context access permissions" do
    # Grant permission first
    @service.grant_context_permission(@context_item.id, {
      user_id: @other_user.id,
      permissions: [ "read", "write" ],
      granted_by: @user.id
    })

    # Revoke permission
    revoke_result = @service.revoke_context_permission(@context_item.id, @other_user.id, @user.id)

    assert revoke_result[:success]
    assert_equal "permission_revoked", revoke_result[:status]

    # Verify permission removed
    can_access = @service.can_access_context?(@context_item.id, @other_user.id, "read")
    assert_not can_access
  end

  # Context Change Notification Tests
  test "notifies users of context changes" do
    # Set up users with access
    @service.grant_context_permission(@context_item.id, {
      user_id: @other_user.id,
      permissions: [ "read" ],
      granted_by: @user.id
    })

    # Mock notification broadcast
    NotificationChannel.expects(:broadcast_to).with(@other_user, hash_including(
      type: "context_updated",
      context_id: @context_item.id
    ))

    @service.notify_context_change(@context_item.id, @user.id, {
      change_type: "content_update",
      change_summary: "Updated context content"
    })
  end

  test "sends context sharing notifications" do
    # Mock notification
    NotificationChannel.expects(:broadcast_to).with(@other_user, hash_including(
      type: "context_shared",
      shared_by: @user.id
    ))

    @service.share_context(@context_item, @user, {
      users: [ @other_user.id ],
      permissions: [ "read" ]
    })
  end

  # Context History and Rollback Tests
  test "tracks context history for rollback" do
    original_content = @context_item.content

    # Make several changes
    changes = [
      "First update to context",
      "Second update to context",
      "Third update to context"
    ]

    changes.each_with_index do |content, index|
      @context_item.update!(content: content)
      @service.track_context_change(@context_item, @user, {
        change_type: "content_update",
        change_summary: "Update #{index + 1}"
      })
    end

    history = @service.get_context_history(@context_item.id)

    assert_equal 3, history[:changes].length
    assert history[:changes].all? { |c| c[:user_id] == @user.id }
  end

  test "rolls back context to previous state" do
    original_content = @context_item.content

    # Make changes and track
    @context_item.update!(content: "Updated content")
    change_record = @service.track_context_change(@context_item, @user, {
      change_type: "content_update"
    })

    # Rollback to previous state
    rollback_result = @service.rollback_context(@context_item.id, change_record[:change_id], @user.id)

    assert rollback_result[:success]
    assert_equal "rollback_completed", rollback_result[:status]

    # Verify content restored
    @context_item.reload
    assert_equal original_content, @context_item.content
  end

  # Context Export/Import Tests
  test "exports context with metadata" do
    export_options = {
      include_versions: true,
      include_permissions: true,
      include_comments: true,
      format: "json"
    }

    export_result = @service.export_context(@context_item.id, @user.id, export_options)

    assert export_result[:success]
    assert_equal "context_exported", export_result[:status]
    assert_present export_result[:export_data]

    export_data = JSON.parse(export_result[:export_data])
    assert_equal @context_item.content, export_data["content"]
    assert_present export_data["metadata"]
    assert_present export_data["export_timestamp"]
  end

  test "imports context from export data" do
    # First export existing context
    export_result = @service.export_context(@context_item.id, @user.id, { format: "json" })

    # Create new document for import
    new_document = Document.create!(
      title: "Import Test Document",
      user: @user,
      description: "For testing context import"
    )

    # Import context
    import_result = @service.import_context(
      new_document.id,
      @user.id,
      export_result[:export_data],
      {
        preserve_ids: false,
        import_permissions: false
      }
    )

    assert import_result[:success]
    assert_equal "context_imported", import_result[:status]
    assert_present import_result[:imported_context_id]

    # Verify imported context
    imported_context = ContextItem.find(import_result[:imported_context_id])
    assert_equal @context_item.content, imported_context.content
    assert_equal new_document.id, imported_context.document_id
  end

  # Performance and Scalability Tests
  test "handles large context synchronization efficiently" do
    # Create large context with many versions
    large_content = "A" * 10000 # 10KB of content
    @context_item.update!(content: large_content)

    # Create many versions
    start_time = Time.current

    10.times do |i|
      @service.create_context_version(@context_item, @user, {
        change_summary: "Large version #{i}"
      })
    end

    processing_time = Time.current - start_time

    assert processing_time < 5.0, "Large context processing took too long: #{processing_time}s"

    # Verify all versions created
    history = @service.get_context_version_history(@context_item.id)
    assert_equal 10, history[:versions].length
  end

  test "efficiently synchronizes across multiple users" do
    # Set up 10 users with context access
    users = []
    10.times do |i|
      user = User.create!(
        name: "Test User #{i}",
        email_address: "testuser#{i}@example.com",
        password: "password123"
      )
      users << user

      @service.grant_context_permission(@context_item.id, {
        user_id: user.id,
        permissions: [ "read" ],
        granted_by: @user.id
      })
    end

    start_time = Time.current

    # Simulate synchronization across all users
    sync_result = @service.synchronize_context_across_users(@context_item.id)

    processing_time = Time.current - start_time

    assert sync_result[:success]
    assert processing_time < 3.0, "Multi-user sync took too long: #{processing_time}s"
    assert_equal 10, sync_result[:synchronized_users]
  end

  # Edge Cases and Error Handling Tests
  test "handles context not found gracefully" do
    result = @service.share_context(nil, @user, { users: [ @other_user.id ] })

    assert_not result[:success]
    assert_equal "context_not_found", result[:error]
  end

  test "handles invalid user permissions gracefully" do
    # Try to share with non-existent user
    result = @service.share_context(@context_item, @user, {
      users: [ 99999 ],
      permissions: [ "read" ]
    })

    assert_not result[:success]
    assert_equal "invalid_users", result[:error]
    assert_includes result[:invalid_user_ids], 99999
  end

  test "handles network timeout during synchronization" do
    # Mock network timeout
    @service.stubs(:sync_with_remote).raises(Net::TimeoutError.new("Network timeout"))

    result = @service.synchronize_context_with_remote(@context_item.id, "remote_server")

    assert_not result[:success]
    assert_equal "sync_timeout", result[:error]
    assert_includes result[:message], "Network timeout"
  end

  # Integration Tests
  test "integrates with ActionCable for real-time updates" do
    # Mock ActionCable broadcast
    ContextChannel.expects(:broadcast_to).with(@context_item, hash_including(
      type: "context_synchronized",
      context_id: @context_item.id
    ))

    @service.broadcast_context_sync(@context_item.id, {
      sync_type: "content_update",
      updated_by: @user.id
    })
  end

  test "integrates with document versioning system" do
    # Update context should trigger document version check
    @document.expects(:should_create_version?).returns(true)
    @document.expects(:create_version!).with(
      created_by_user: @user,
      version_notes: "Context synchronization update",
      is_auto_version: true
    )

    @service.sync_context_with_document(@context_item.id, @user.id)
  end
end
