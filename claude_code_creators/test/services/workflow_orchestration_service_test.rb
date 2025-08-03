# frozen_string_literal: true

require "test_helper"

class WorkflowOrchestrationServiceTest < ActiveSupport::TestCase
  setup do
    @service = WorkflowOrchestrationService.new
    @user = users(:one)
    @other_user = users(:two)
    @admin_user = users(:one)
    @admin_user.update!(role: "admin")
    @document = documents(:one)
  end

  # Task Assignment and Tracking Tests
  test "creates development task with proper assignment" do
    task_data = {
      title: "Implement user authentication",
      description: "Add login/logout functionality with session management",
      priority: "high",
      category: "feature",
      estimated_hours: 8,
      assigned_to: @other_user.id,
      due_date: 1.week.from_now,
      tags: [ "authentication", "security" ],
      acceptance_criteria: [
        "User can log in with email/password",
        "User can log out",
        "Session persists across browser refreshes"
      ]
    }

    result = @service.create_task(@document.id, @user.id, task_data)

    assert result[:success]
    assert_equal "task_created", result[:status]
    assert_present result[:task_id]

    # Verify task data
    task = @service.get_task(result[:task_id])
    assert_equal "Implement user authentication", task[:title]
    assert_equal @other_user.id, task[:assigned_to]
    assert_equal "high", task[:priority]
    assert_equal "pending", task[:status]
  end

  test "assigns task to multiple users for collaboration" do
    task_data = {
      title: "Complex feature implementation",
      description: "Requires multiple developers",
      assigned_to: [ @user.id, @other_user.id ],
      collaboration_type: "paired_programming"
    }

    result = @service.create_task(@document.id, @admin_user.id, task_data)

    assert result[:success]

    task = @service.get_task(result[:task_id])
    assert_includes task[:assigned_users], @user.id
    assert_includes task[:assigned_users], @other_user.id
    assert_equal "paired_programming", task[:collaboration_type]
  end

  test "updates task status with progress tracking" do
    # Create task first
    task_result = @service.create_task(@document.id, @user.id, {
      title: "Test task",
      assigned_to: @user.id
    })

    # Update task status
    update_result = @service.update_task_status(
      task_result[:task_id],
      @user.id,
      {
        status: "in_progress",
        progress_percentage: 25,
        time_spent: 2.5,
        notes: "Started implementation, completed basic structure"
      }
    )

    assert update_result[:success]
    assert_equal "status_updated", update_result[:status]

    # Verify task updated
    task = @service.get_task(task_result[:task_id])
    assert_equal "in_progress", task[:status]
    assert_equal 25, task[:progress_percentage]
    assert_equal 2.5, task[:time_spent]
  end

  test "tracks task dependencies and prerequisites" do
    # Create prerequisite task
    prereq_task = @service.create_task(@document.id, @user.id, {
      title: "Setup database schema",
      priority: "high"
    })

    # Create dependent task
    dependent_task = @service.create_task(@document.id, @user.id, {
      title: "Implement data models",
      depends_on: [ prereq_task[:task_id] ],
      priority: "medium"
    })

    assert dependent_task[:success]

    # Verify dependency relationship
    dependencies = @service.get_task_dependencies(dependent_task[:task_id])
    assert_includes dependencies[:prerequisites], prereq_task[:task_id]

    # Verify task cannot start until prerequisites complete
    start_result = @service.attempt_task_start(dependent_task[:task_id], @user.id)
    assert_not start_result[:can_start]
    assert_equal "pending_prerequisites", start_result[:blocking_reason]
  end

  # Code Review and Approval Workflow Tests
  test "initiates code review workflow" do
    # Create completed task
    task_result = @service.create_task(@document.id, @user.id, {
      title: "Feature implementation",
      assigned_to: @user.id
    })

    @service.update_task_status(task_result[:task_id], @user.id, {
      status: "completed"
    })

    # Initiate review
    review_result = @service.initiate_code_review(
      task_result[:task_id],
      @user.id,
      {
        reviewers: [ @other_user.id, @admin_user.id ],
        review_type: "feature_review",
        files_changed: [ "app/models/user.rb", "app/controllers/sessions_controller.rb" ],
        description: "Implemented user authentication feature"
      }
    )

    assert review_result[:success]
    assert_equal "review_initiated", review_result[:status]
    assert_present review_result[:review_id]

    # Verify review data
    review = @service.get_code_review(review_result[:review_id])
    assert_includes review[:reviewers], @other_user.id
    assert_includes review[:reviewers], @admin_user.id
    assert_equal "pending", review[:status]
  end

  test "handles code review feedback and approval" do
    # Set up review
    task_result = @service.create_task(@document.id, @user.id, { title: "Test task" })
    review_result = @service.initiate_code_review(task_result[:task_id], @user.id, {
      reviewers: [ @other_user.id ]
    })

    # Submit review feedback
    feedback_result = @service.submit_review_feedback(
      review_result[:review_id],
      @other_user.id,
      {
        approval_status: "approved_with_comments",
        comments: [
          {
            file: "app/models/user.rb",
            line: 25,
            comment: "Consider adding validation for email uniqueness",
            severity: "suggestion"
          }
        ],
        overall_comment: "Good implementation, minor suggestions for improvement"
      }
    )

    assert feedback_result[:success]
    assert_equal "feedback_submitted", feedback_result[:status]

    # Verify review status updated
    review = @service.get_code_review(review_result[:review_id])
    assert_equal "approved_with_comments", review[:status]
    assert_equal 1, review[:comments].length
  end

  test "requires approval from all reviewers for critical tasks" do
    # Create critical task
    task_result = @service.create_task(@document.id, @admin_user.id, {
      title: "Security implementation",
      priority: "critical",
      requires_unanimous_approval: true
    })

    review_result = @service.initiate_code_review(task_result[:task_id], @user.id, {
      reviewers: [ @other_user.id, @admin_user.id ]
    })

    # First reviewer approves
    @service.submit_review_feedback(review_result[:review_id], @other_user.id, {
      approval_status: "approved"
    })

    review = @service.get_code_review(review_result[:review_id])
    assert_equal "pending", review[:status] # Still pending second approval

    # Second reviewer approves
    @service.submit_review_feedback(review_result[:review_id], @admin_user.id, {
      approval_status: "approved"
    })

    review = @service.get_code_review(review_result[:review_id])
    assert_equal "approved", review[:status] # Now fully approved
  end

  # Git Integration Tests
  test "integrates task with git branch creation" do
    task_data = {
      title: "Add search feature",
      description: "Implement full-text search",
      create_git_branch: true,
      branch_naming_pattern: "feature/task-{id}-{title-slug}"
    }

    # Mock git operations - use anything() for flexible matching
    @service.expects(:create_git_branch).with(
      branch_name: anything(),
      base_branch: "main"
    ).returns({ success: true, branch_name: "feature/task-123-add-search-feature" })

    result = @service.create_task(@document.id, @user.id, task_data)

    assert result[:success]
    task = @service.get_task(result[:task_id])
    assert_present task[:git_branch]
    assert_match(/feature\/task-\w+-add-search-feature/, task[:git_branch])
  end

  test "tracks git commits for task progress" do
    task_result = @service.create_task(@document.id, @user.id, {
      title: "Database migration task"
    })

    # Mock git commit tracking
    commit_data = {
      sha: "abc123def456",
      message: "Add user authentication migration",
      author: @user.email_address,
      timestamp: Time.current.iso8601,
      files_changed: [ "db/migrate/20250802_add_auth.rb" ]
    }

    track_result = @service.track_git_commit(task_result[:task_id], commit_data)

    assert track_result[:success]
    assert_equal "commit_tracked", track_result[:status]

    # Verify commit associated with task
    task = @service.get_task(task_result[:task_id])
    assert_includes task[:git_commits], commit_data[:sha]
  end

  test "handles git merge conflicts in workflow" do
    task_result = @service.create_task(@document.id, @user.id, {
      title: "Conflicting feature",
      git_branch: "feature/conflicting-branch"
    })

    # Simulate merge conflict
    conflict_data = {
      conflicting_files: [ "app/models/user.rb", "config/routes.rb" ],
      base_branch: "main",
      conflict_markers: true,
      auto_resolvable: false
    }

    conflict_result = @service.handle_git_conflict(task_result[:task_id], conflict_data)

    assert conflict_result[:success]
    assert_equal "conflict_detected", conflict_result[:status]
    assert_equal "manual_resolution_required", conflict_result[:resolution_type]

    # Verify task status updated
    task = @service.get_task(task_result[:task_id])
    assert_equal "blocked", task[:status]
    assert_equal "git_conflict", task[:blocking_reason]
  end

  # Development Milestone Tracking Tests
  test "creates and tracks development milestones" do
    milestone_data = {
      name: "Beta Release v1.0",
      description: "First beta version with core features",
      target_date: 1.month.from_now,
      tasks: [],
      success_criteria: [
        "All core features implemented",
        "95% test coverage achieved",
        "Performance benchmarks met"
      ]
    }

    result = @service.create_milestone(@document.id, @admin_user.id, milestone_data)

    assert result[:success]
    assert_equal "milestone_created", result[:status]
    assert_present result[:milestone_id]

    milestone = @service.get_milestone(result[:milestone_id])
    assert_equal "Beta Release v1.0", milestone[:name]
    assert_equal 3, milestone[:success_criteria].length
  end

  test "associates tasks with milestones" do
    # Create milestone
    milestone_result = @service.create_milestone(@document.id, @admin_user.id, {
      name: "Sprint 1",
      target_date: 2.weeks.from_now
    })

    # Create tasks
    task_1 = @service.create_task(@document.id, @user.id, {
      title: "Task 1",
      milestone_id: milestone_result[:milestone_id]
    })

    task_2 = @service.create_task(@document.id, @user.id, {
      title: "Task 2",
      milestone_id: milestone_result[:milestone_id]
    })

    # Check milestone progress
    progress = @service.get_milestone_progress(milestone_result[:milestone_id])

    assert_equal 2, progress[:total_tasks]
    assert_equal 0, progress[:completed_tasks]
    assert_equal 0, progress[:completion_percentage]

    # Complete one task
    @service.update_task_status(task_1[:task_id], @user.id, { status: "completed" })

    updated_progress = @service.get_milestone_progress(milestone_result[:milestone_id])
    assert_equal 50, updated_progress[:completion_percentage]
  end

  # Team Communication and Coordination Tests
  test "facilitates team communication through channels" do
    # Create team communication channel for document
    channel_result = @service.create_communication_channel(@document.id, @admin_user.id, {
      name: "Development Coordination",
      type: "team_chat",
      participants: [ @user.id, @other_user.id, @admin_user.id ],
      purpose: "Coordinate development tasks and share updates"
    })

    assert channel_result[:success]
    assert_equal "channel_created", channel_result[:status]

    # Send message to channel
    message_result = @service.send_channel_message(
      channel_result[:channel_id],
      @user.id,
      {
        content: "Started working on authentication feature",
        message_type: "status_update",
        related_task_id: "task_123"
      }
    )

    assert message_result[:success]
    assert_equal "message_sent", message_result[:status]

    # Verify message broadcast
    channel = @service.get_communication_channel(channel_result[:channel_id])
    assert_equal 1, channel[:message_count]
  end

  test "sends automated workflow notifications" do
    # Create task
    task_result = @service.create_task(@document.id, @user.id, {
      title: "Notification test task",
      assigned_to: @other_user.id
    })

    # Mock notification broadcast
    NotificationChannel.expects(:broadcast_to).with(@other_user, hash_including(
      type: "task_assigned",
      task_id: task_result[:task_id]
    ))

    # Trigger notification
    @service.send_task_notification(task_result[:task_id], "task_assigned")
  end

  # Performance Monitoring and Metrics Tests
  test "tracks development team performance metrics" do
    # Create and complete several tasks for metrics
    5.times do |i|
      task = @service.create_task(@document.id, @admin_user.id, {
        title: "Task #{i + 1}",
        assigned_to: @user.id,
        estimated_hours: 4
      })

      @service.update_task_status(task[:task_id], @user.id, {
        status: "completed",
        time_spent: 3.5 + (i * 0.5)
      })
    end

    metrics = @service.get_team_performance_metrics(@document.id, {
      period: "last_30_days",
      include_individual_stats: true
    })

    assert metrics[:success]
    assert_equal 5, metrics[:completed_tasks]
    assert_present metrics[:average_completion_time]
    assert_present metrics[:user_statistics][@user.id]
    assert metrics[:user_statistics][@user.id][:tasks_completed] > 0
  end

  test "generates productivity reports" do
    # Set up test data with various task statuses
    statuses = [ "completed", "in_progress", "blocked", "pending" ]
    statuses.each_with_index do |status, index|
      task = @service.create_task(@document.id, @admin_user.id, {
        title: "Task with #{status} status",
        assigned_to: @user.id
      })

      @service.update_task_status(task[:task_id], @user.id, { status: status })
    end

    report = @service.generate_productivity_report(@document.id, {
      report_type: "weekly_summary",
      include_charts: true,
      breakdown_by_user: true
    })

    assert report[:success]
    assert_present report[:summary]
    assert_equal 1, report[:summary][:completed_tasks]
    assert_equal 1, report[:summary][:in_progress_tasks]
    assert_equal 1, report[:summary][:blocked_tasks]
    assert_present report[:user_breakdown]
  end

  # Workflow Automation Tests
  test "automates task transitions based on conditions" do
    # Create automation rule
    automation_rule = {
      trigger: "task_completed",
      conditions: [
        { field: "priority", operator: "equals", value: "high" },
        { field: "category", operator: "equals", value: "feature" }
      ],
      actions: [
        { type: "create_review_request", reviewers: [ @admin_user.id ] },
        { type: "notify_stakeholders" },
        { type: "update_milestone_progress" }
      ]
    }

    rule_result = @service.create_automation_rule(@document.id, @admin_user.id, automation_rule)
    assert rule_result[:success]

    # Create task that matches conditions
    task = @service.create_task(@document.id, @user.id, {
      title: "High priority feature",
      priority: "high",
      category: "feature"
    })

    # Mock automation execution
    @service.expects(:execute_automation_actions).with(
      rule_result[:rule_id],
      task[:task_id],
      automation_rule[:actions]
    )

    # Complete task to trigger automation
    @service.update_task_status(task[:task_id], @user.id, { status: "completed" })
  end

  test "schedules recurring workflow tasks" do
    recurring_task_data = {
      title: "Weekly code review",
      description: "Review code quality and standards",
      schedule: {
        type: "weekly",
        day_of_week: "friday",
        time: "15:00"
      },
      assigned_to: @admin_user.id,
      auto_assign: true
    }

    result = @service.create_recurring_task(@document.id, @admin_user.id, recurring_task_data)

    assert result[:success]
    assert_equal "recurring_task_created", result[:status]
    assert_present result[:schedule_id]

    # Verify next occurrence scheduled
    schedule = @service.get_task_schedule(result[:schedule_id])
    assert_present schedule[:next_occurrence]
    assert_equal "weekly", schedule[:frequency]
  end

  # Error Handling and Edge Cases Tests
  test "handles task assignment to non-existent user" do
    result = @service.create_task(@document.id, @user.id, {
      title: "Invalid assignment test",
      assigned_to: 99999
    })

    assert_not result[:success]
    assert_equal "invalid_assignee", result[:error]
  end

  test "handles circular task dependencies" do
    # Create three tasks with circular dependencies
    task_a = @service.create_task(@document.id, @user.id, { title: "Task A" })
    task_b = @service.create_task(@document.id, @user.id, { title: "Task B", depends_on: [ task_a[:task_id] ] })

    # Try to make task_a depend on task_b (creating circular dependency)
    result = @service.update_task_dependencies(task_a[:task_id], {
      depends_on: [ task_b[:task_id] ]
    })

    assert_not result[:success]
    assert_equal "circular_dependency", result[:error]
    assert_includes result[:dependency_chain], task_a[:task_id]
    assert_includes result[:dependency_chain], task_b[:task_id]
  end

  test "handles workflow service unavailable" do
    # Mock service failure
    @service.stubs(:validate_workflow_state).raises(StandardError.new("Service temporarily unavailable"))

    result = @service.create_task(@document.id, @user.id, { title: "Test task" })

    assert_not result[:success]
    assert_equal "service_error", result[:error]
    assert_includes result[:message], "temporarily unavailable"
  end

  # Integration Tests
  test "integrates with document versioning for milestone releases" do
    # Create milestone
    milestone = @service.create_milestone(@document.id, @admin_user.id, {
      name: "Version 1.0 Release",
      auto_create_document_version: true
    })

    # Complete all milestone tasks (mock)
    @service.stubs(:get_milestone_progress).returns({
      completion_percentage: 100,
      all_tasks_completed: true
    })

    # Mock document version creation
    @document.expects(:create_version!).with(
      created_by_user: @admin_user,
      version_name: "Version 1.0 Release",
      version_notes: "Automated version created on milestone completion",
      is_auto_version: true
    )

    @service.complete_milestone(milestone[:milestone_id], @admin_user.id)
  end

  test "coordinates with ActionCable for real-time workflow updates" do
    task_result = @service.create_task(@document.id, @user.id, {
      title: "Real-time test task"
    })

    # Mock ActionCable broadcast
    WorkflowChannel.expects(:broadcast_to).with(@document, hash_including(
      type: "task_status_updated",
      task_id: task_result[:task_id]
    ))

    @service.update_task_status(task_result[:task_id], @user.id, {
      status: "in_progress"
    })
  end

  private

  def create_test_user(name, email)
    User.create!(
      name: name,
      email_address: email,
      password: "password123"
    )
  end
end
