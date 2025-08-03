# frozen_string_literal: true

# Service for orchestrating development workflows, task management, and team coordination
# Provides comprehensive project management and development workflow automation
class WorkflowOrchestrationService
  include ActiveModel::Validations

  VALID_TASK_STATUSES = %w[pending in_progress completed blocked on_hold].freeze
  VALID_PRIORITIES = %w[low medium high critical].freeze
  VALID_CATEGORIES = %w[feature bug enhancement refactor documentation test].freeze
  VALID_COLLABORATION_TYPES = %w[individual paired_programming team_review].freeze
  VALID_REVIEW_STATUSES = %w[pending approved approved_with_comments rejected].freeze

  class Error < StandardError; end
  class AuthorizationError < Error; end
  class ValidationError < Error; end
  class DependencyError < Error; end

  def initialize
    @logger = Rails.logger
    setup_channels
  end

  # Task Management Methods
  def create_task(document_id, creator_id, task_data)
    validate_task_data!(task_data)

    task_id = generate_task_id
    task_record = {
      task_id: task_id,
      document_id: document_id,
      title: task_data[:title],
      description: task_data[:description] || "",
      priority: task_data[:priority] || "medium",
      category: task_data[:category] || "feature",
      status: "pending",
      estimated_hours: task_data[:estimated_hours] || 0,
      created_by: creator_id,
      created_at: Time.current,
      due_date: task_data[:due_date],
      tags: task_data[:tags] || [],
      acceptance_criteria: task_data[:acceptance_criteria] || [],
      depends_on: task_data[:depends_on] || [],
      progress_percentage: 0,
      time_spent: 0,
      git_branch: nil,
      git_commits: []
    }

    # Handle assignment
    if task_data[:assigned_to].is_a?(Array)
      task_record[:assigned_users] = task_data[:assigned_to]
      task_record[:collaboration_type] = task_data[:collaboration_type] || "team_review"
      task_record[:assigned_to] = task_data[:assigned_to].first
    else
      task_record[:assigned_to] = task_data[:assigned_to]
      task_record[:assigned_users] = task_data[:assigned_to] ? [ task_data[:assigned_to] ] : []
      task_record[:collaboration_type] = "individual"
    end

    # Validate assigned users exist
    assigned_user_ids = Array(task_record[:assigned_users])
    invalid_users = assigned_user_ids.reject { |user_id| User.exists?(user_id) }

    if invalid_users.any?
      return error_response("invalid_assignee", invalid_user_ids: invalid_users)
    end

    # Handle milestone assignment
    if task_data[:milestone_id]
      task_record[:milestone_id] = task_data[:milestone_id]
    end

    # Handle git branch creation
    if task_data[:create_git_branch]
      branch_result = create_git_branch(
        branch_name: generate_branch_name(task_id, task_data[:title], task_data[:branch_naming_pattern]),
        base_branch: "main"
      )

      if branch_result[:success]
        task_record[:git_branch] = branch_result[:branch_name]
      end
    end

    # Validate dependencies
    if task_record[:depends_on].any?
      dependency_validation = validate_dependencies(task_record[:depends_on])
      return dependency_validation unless dependency_validation[:success]
    end

    store_task(task_record)

    # Send notifications for assignments
    notify_task_assignment(task_id) if task_record[:assigned_to]

    success_response(
      status: "task_created",
      task_id: task_id
    )
  rescue ValidationError => e
    error_response("validation_failed", message: e.message)
  rescue StandardError => e
    @logger.error "Task creation failed: #{e.message}"
    error_response("task_creation_failed", message: e.message)
  end

  def get_task(task_id)
    task = find_task(task_id)
    return nil unless task

    {
      title: task[:title],
      description: task[:description],
      priority: task[:priority],
      category: task[:category],
      status: task[:status],
      assigned_to: task[:assigned_to],
      assigned_users: task[:assigned_users],
      collaboration_type: task[:collaboration_type],
      estimated_hours: task[:estimated_hours],
      progress_percentage: task[:progress_percentage],
      time_spent: task[:time_spent],
      created_by: task[:created_by],
      created_at: task[:created_at],
      due_date: task[:due_date],
      tags: task[:tags],
      acceptance_criteria: task[:acceptance_criteria],
      depends_on: task[:depends_on],
      git_branch: task[:git_branch],
      git_commits: task[:git_commits],
      milestone_id: task[:milestone_id]
    }
  end

  def update_task_status(task_id, user_id, update_data)
    task = find_task(task_id)
    return error_response("task_not_found") unless task
    return error_response("unauthorized") unless can_user_modify_task?(task, user_id)

    # Validate status
    new_status = update_data[:status]
    if new_status && !VALID_TASK_STATUSES.include?(new_status)
      return error_response("invalid_status", valid_statuses: VALID_TASK_STATUSES)
    end

    updates = {
      updated_at: Time.current,
      updated_by: user_id
    }

    # Update allowed fields
    %i[status progress_percentage time_spent notes].each do |field|
      updates[field] = update_data[field] if update_data.key?(field)
    end

    update_task(task_id, updates)

    # Broadcast real-time updates
    broadcast_task_update(task_id, updates)

    # Check for automation triggers
    execute_task_automation(task_id, "task_status_updated", update_data)
    
    # If task was completed, trigger completion-specific automation
    if update_data[:status] == "completed"
      execute_task_automation(task_id, "task_completed", update_data)
    end

    success_response(status: "status_updated")
  rescue StandardError => e
    @logger.error "Task status update failed: #{e.message}"
    error_response("update_failed", message: e.message)
  end

  def get_task_dependencies(task_id)
    task = find_task(task_id)
    return error_response("task_not_found") unless task

    {
      prerequisites: task[:depends_on],
      dependents: find_dependent_tasks(task_id)
    }
  end

  def attempt_task_start(task_id, user_id)
    task = find_task(task_id)
    return error_response("task_not_found") unless task

    # Check if prerequisites are completed
    unfinished_prerequisites = task[:depends_on].select do |prereq_id|
      prereq_task = find_task(prereq_id)
      prereq_task && prereq_task[:status] != "completed"
    end

    if unfinished_prerequisites.any?
      return {
        can_start: false,
        blocking_reason: "pending_prerequisites",
        unfinished_prerequisites: unfinished_prerequisites
      }
    end

    { can_start: true }
  end

  def update_task_dependencies(task_id, dependency_data)
    new_dependencies = dependency_data[:depends_on] || []

    # Check for circular dependencies
    circular_check = detect_circular_dependencies(task_id, new_dependencies)

    if circular_check[:has_circular]
      return error_response("circular_dependency", dependency_chain: circular_check[:chain])
    end

    update_task(task_id, { depends_on: new_dependencies })
    success_response(status: "dependencies_updated")
  rescue StandardError => e
    @logger.error "Dependency update failed: #{e.message}"
    error_response("dependency_update_failed", message: e.message)
  end

  # Code Review Workflow Methods
  def initiate_code_review(task_id, requester_id, review_data)
    task = find_task(task_id)
    return error_response("task_not_found") unless task
    return error_response("unauthorized") unless can_user_modify_task?(task, requester_id)

    review_id = generate_review_id
    review_record = {
      review_id: review_id,
      task_id: task_id,
      requester_id: requester_id,
      reviewers: review_data[:reviewers] || [],
      review_type: review_data[:review_type] || "standard",
      files_changed: review_data[:files_changed] || [],
      description: review_data[:description] || "",
      status: "pending",
      created_at: Time.current,
      comments: [],
      approvals: {}
    }

    # Validate reviewers exist
    invalid_reviewers = review_record[:reviewers].reject { |reviewer_id| User.exists?(reviewer_id) }

    if invalid_reviewers.any?
      return error_response("invalid_reviewers", invalid_reviewer_ids: invalid_reviewers)
    end

    store_review(review_record)

    # Notify reviewers
    review_record[:reviewers].each do |reviewer_id|
      send_review_notification(reviewer_id, review_id, "review_requested")
    end

    success_response(
      status: "review_initiated",
      review_id: review_id
    )
  rescue StandardError => e
    @logger.error "Code review initiation failed: #{e.message}"
    error_response("review_initiation_failed", message: e.message)
  end

  def get_code_review(review_id)
    review = find_review(review_id)
    return nil unless review

    {
      task_id: review[:task_id],
      requester_id: review[:requester_id],
      reviewers: review[:reviewers],
      review_type: review[:review_type],
      files_changed: review[:files_changed],
      description: review[:description],
      status: review[:status],
      created_at: review[:created_at],
      comments: review[:comments],
      approvals: review[:approvals]
    }
  end

  def submit_review_feedback(review_id, reviewer_id, feedback_data)
    review = find_review(review_id)
    return error_response("review_not_found") unless review
    return error_response("unauthorized") unless review[:reviewers].include?(reviewer_id)

    approval_status = feedback_data[:approval_status] || "approved"

    unless VALID_REVIEW_STATUSES.include?(approval_status)
      return error_response("invalid_approval_status", valid_statuses: VALID_REVIEW_STATUSES)
    end

    # Add comments
    if feedback_data[:comments]
      new_comments = feedback_data[:comments].map do |comment|
        comment.merge(
          reviewer_id: reviewer_id,
          created_at: Time.current,
          comment_id: generate_comment_id
        )
      end

      review[:comments].concat(new_comments)
    end

    # Record approval
    review[:approvals][reviewer_id] = {
      status: approval_status,
      submitted_at: Time.current,
      overall_comment: feedback_data[:overall_comment]
    }

    # Update review status
    review[:status] = calculate_review_status(review)

    update_review(review_id, review)

    success_response(status: "feedback_submitted")
  rescue StandardError => e
    @logger.error "Review feedback submission failed: #{e.message}"
    error_response("feedback_submission_failed", message: e.message)
  end

  # Git Integration Methods
  def create_git_branch(branch_name:, base_branch: "main")
    # Mock git branch creation - in real implementation this would use git commands
    success_response(
      branch_name: branch_name,
      base_branch: base_branch
    )
  rescue StandardError => e
    @logger.error "Git branch creation failed: #{e.message}"
    error_response("branch_creation_failed", message: e.message)
  end

  def track_git_commit(task_id, commit_data)
    task = find_task(task_id)
    return error_response("task_not_found") unless task

    commit_record = {
      sha: commit_data[:sha],
      message: commit_data[:message],
      author: commit_data[:author],
      timestamp: commit_data[:timestamp],
      files_changed: commit_data[:files_changed] || []
    }

    # Add commit to task
    task[:git_commits] << commit_record
    update_task(task_id, { git_commits: task[:git_commits] })

    success_response(status: "commit_tracked")
  rescue StandardError => e
    @logger.error "Git commit tracking failed: #{e.message}"
    error_response("commit_tracking_failed", message: e.message)
  end

  def handle_git_conflict(task_id, conflict_data)
    task = find_task(task_id)
    return error_response("task_not_found") unless task

    conflict_record = {
      task_id: task_id,
      conflicting_files: conflict_data[:conflicting_files],
      base_branch: conflict_data[:base_branch],
      conflict_markers: conflict_data[:conflict_markers],
      auto_resolvable: conflict_data[:auto_resolvable],
      detected_at: Time.current
    }

    # Update task status to blocked
    update_task(task_id, {
      status: "blocked",
      blocking_reason: "git_conflict",
      conflict_info: conflict_record
    })

    resolution_type = conflict_data[:auto_resolvable] ? "auto_resolution_available" : "manual_resolution_required"

    success_response(
      status: "conflict_detected",
      resolution_type: resolution_type,
      conflict_info: conflict_record
    )
  rescue StandardError => e
    @logger.error "Git conflict handling failed: #{e.message}"
    error_response("conflict_handling_failed", message: e.message)
  end

  # Milestone Management Methods
  def create_milestone(document_id, creator_id, milestone_data)
    milestone_id = generate_milestone_id
    milestone_record = {
      milestone_id: milestone_id,
      document_id: document_id,
      name: milestone_data[:name],
      description: milestone_data[:description] || "",
      target_date: milestone_data[:target_date],
      created_by: creator_id,
      created_at: Time.current,
      success_criteria: milestone_data[:success_criteria] || [],
      tasks: milestone_data[:tasks] || [],
      status: "active",
      auto_create_document_version: milestone_data[:auto_create_document_version] || false
    }

    store_milestone(milestone_record)

    success_response(
      status: "milestone_created",
      milestone_id: milestone_id
    )
  rescue StandardError => e
    @logger.error "Milestone creation failed: #{e.message}"
    error_response("milestone_creation_failed", message: e.message)
  end

  def get_milestone(milestone_id)
    milestone = find_milestone(milestone_id)
    return nil unless milestone

    {
      name: milestone[:name],
      description: milestone[:description],
      target_date: milestone[:target_date],
      created_by: milestone[:created_by],
      created_at: milestone[:created_at],
      success_criteria: milestone[:success_criteria],
      status: milestone[:status],
      auto_create_document_version: milestone[:auto_create_document_version]
    }
  end

  def get_milestone_progress(milestone_id)
    milestone = find_milestone(milestone_id)
    return error_response("milestone_not_found") unless milestone

    milestone_tasks = find_tasks_by_milestone(milestone_id)
    total_tasks = milestone_tasks.length
    completed_tasks = milestone_tasks.count { |task| task[:status] == "completed" }

    completion_percentage = total_tasks > 0 ? (completed_tasks.to_f / total_tasks * 100).round : 0

    {
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      completion_percentage: completion_percentage,
      remaining_tasks: total_tasks - completed_tasks
    }
  end

  def complete_milestone(milestone_id, user_id)
    milestone = find_milestone(milestone_id)
    return error_response("milestone_not_found") unless milestone

    progress = get_milestone_progress(milestone_id)

    if progress[:completion_percentage] == 100
      update_milestone(milestone_id, { status: "completed", completed_at: Time.current, completed_by: user_id })

      # Create document version if configured
      if milestone[:auto_create_document_version]
        document = Document.find_by(id: milestone[:document_id])
        user = User.find_by(id: user_id)

        if document && user
          document.create_version!(
            created_by_user: user,
            version_name: milestone[:name],
            version_notes: "Automated version created on milestone completion",
            is_auto_version: true
          )
        end
      end

      success_response(status: "milestone_completed")
    else
      error_response("milestone_incomplete", progress: progress)
    end
  rescue StandardError => e
    @logger.error "Milestone completion failed: #{e.message}"
    error_response("milestone_completion_failed", message: e.message)
  end

  # Team Communication Methods
  def create_communication_channel(document_id, creator_id, channel_data)
    channel_id = generate_channel_id
    channel_record = {
      channel_id: channel_id,
      document_id: document_id,
      name: channel_data[:name],
      type: channel_data[:type] || "team_chat",
      participants: channel_data[:participants] || [],
      purpose: channel_data[:purpose] || "",
      created_by: creator_id,
      created_at: Time.current,
      message_count: 0,
      active: true
    }

    store_channel(channel_record)

    success_response(
      status: "channel_created",
      channel_id: channel_id
    )
  rescue StandardError => e
    @logger.error "Communication channel creation failed: #{e.message}"
    error_response("channel_creation_failed", message: e.message)
  end

  def get_communication_channel(channel_id)
    channel = find_channel(channel_id)
    return nil unless channel

    {
      name: channel[:name],
      type: channel[:type],
      participants: channel[:participants],
      purpose: channel[:purpose],
      created_by: channel[:created_by],
      created_at: channel[:created_at],
      message_count: channel[:message_count],
      active: channel[:active]
    }
  end

  def send_channel_message(channel_id, sender_id, message_data)
    channel = find_channel(channel_id)
    return error_response("channel_not_found") unless channel
    return error_response("unauthorized") unless channel[:participants].include?(sender_id)

    message_record = {
      message_id: generate_message_id,
      channel_id: channel_id,
      sender_id: sender_id,
      content: message_data[:content],
      message_type: message_data[:message_type] || "text",
      related_task_id: message_data[:related_task_id],
      sent_at: Time.current
    }

    store_channel_message(message_record)

    # Update channel message count
    update_channel(channel_id, { message_count: channel[:message_count] + 1 })

    # Broadcast to channel participants
    broadcast_channel_message(channel_id, message_record)

    success_response(status: "message_sent")
  rescue StandardError => e
    @logger.error "Channel message sending failed: #{e.message}"
    error_response("message_sending_failed", message: e.message)
  end

  def send_task_notification(task_id, notification_type)
    task = find_task(task_id)
    return unless task

    case notification_type
    when "task_assigned"
      if task[:assigned_to]
        user = User.find_by(id: task[:assigned_to])
        NotificationChannel.broadcast_to(user, {
          type: "task_assigned",
          task_id: task_id,
          title: task[:title],
          assigned_by: task[:created_by],
          timestamp: Time.current.iso8601
        }) if user
      end
    end
  rescue StandardError => e
    @logger.error "Task notification failed: #{e.message}"
  end

  # Performance and Metrics Methods
  def get_team_performance_metrics(document_id, options = {})
    period = options[:period] || "last_30_days"
    include_individual = options[:include_individual_stats] || false

    # Find all tasks for the document
    document_tasks = find_tasks_by_document(document_id)

    # Filter by period
    start_date = case period
    when "last_30_days"
                   30.days.ago
    when "last_week"
                   1.week.ago
    else
                   1.month.ago
    end

    period_tasks = document_tasks.select { |task| task[:created_at] >= start_date }
    completed_tasks = period_tasks.select { |task| task[:status] == "completed" }

    metrics = {
      success: true,
      period: period,
      total_tasks: period_tasks.length,
      completed_tasks: completed_tasks.length,
      completion_rate: period_tasks.length > 0 ? (completed_tasks.length.to_f / period_tasks.length * 100).round(2) : 0,
      average_completion_time: calculate_average_completion_time(completed_tasks)
    }

    if include_individual
      metrics[:user_statistics] = calculate_user_statistics(period_tasks)
    end

    metrics
  rescue StandardError => e
    @logger.error "Performance metrics calculation failed: #{e.message}"
    error_response("metrics_calculation_failed", message: e.message)
  end

  def generate_productivity_report(document_id, options = {})
    report_type = options[:report_type] || "weekly_summary"
    include_charts = options[:include_charts] || false
    breakdown_by_user = options[:breakdown_by_user] || false

    document_tasks = find_tasks_by_document(document_id)

    # Calculate summary statistics
    status_counts = VALID_TASK_STATUSES.each_with_object({}) do |status, counts|
      counts["#{status}_tasks"] = document_tasks.count { |task| task[:status] == status }
    end

    report = {
      success: true,
      report_type: report_type,
      generated_at: Time.current,
      summary: status_counts
    }

    if breakdown_by_user
      report[:user_breakdown] = calculate_user_breakdown(document_tasks)
    end

    if include_charts
      report[:chart_data] = generate_chart_data(document_tasks)
    end

    report
  rescue StandardError => e
    @logger.error "Productivity report generation failed: #{e.message}"
    error_response("report_generation_failed", message: e.message)
  end

  # Workflow Automation Methods
  def create_automation_rule(document_id, creator_id, rule_data)
    rule_id = generate_rule_id
    rule_record = {
      rule_id: rule_id,
      document_id: document_id,
      created_by: creator_id,
      trigger: rule_data[:trigger],
      conditions: rule_data[:conditions] || [],
      actions: rule_data[:actions] || [],
      active: true,
      created_at: Time.current
    }

    store_automation_rule(rule_record)

    success_response(
      status: "automation_rule_created",
      rule_id: rule_id
    )
  rescue StandardError => e
    @logger.error "Automation rule creation failed: #{e.message}"
    error_response("rule_creation_failed", message: e.message)
  end

  def execute_task_automation(task_id, trigger_event, event_data)
    task = find_task(task_id)
    return unless task

    # Find applicable automation rules
    applicable_rules = find_automation_rules_by_trigger(task[:document_id], trigger_event)

    applicable_rules.each do |rule|
      if rule_conditions_met?(rule, task, event_data)
        execute_automation_actions(rule[:rule_id], task_id, rule[:actions])
      end
    end
  rescue StandardError => e
    @logger.error "Task automation execution failed: #{e.message}"
  end

  def execute_automation_actions(rule_id, task_id, actions)
    actions.each do |action|
      case action[:type]
      when "create_review_request"
        # Mock automation action execution
        @logger.info "Automation: Creating review request for task #{task_id}"
      when "notify_stakeholders"
        @logger.info "Automation: Notifying stakeholders for task #{task_id}"
      when "update_milestone_progress"
        @logger.info "Automation: Updating milestone progress for task #{task_id}"
      end
    end
  rescue StandardError => e
    @logger.error "Automation action execution failed: #{e.message}"
  end

  def create_recurring_task(document_id, creator_id, recurring_data)
    schedule_id = generate_schedule_id
    schedule_record = {
      schedule_id: schedule_id,
      document_id: document_id,
      created_by: creator_id,
      title: recurring_data[:title],
      description: recurring_data[:description] || "",
      schedule: recurring_data[:schedule],
      assigned_to: recurring_data[:assigned_to],
      auto_assign: recurring_data[:auto_assign] || false,
      active: true,
      created_at: Time.current,
      next_occurrence: calculate_next_occurrence(recurring_data[:schedule])
    }

    store_task_schedule(schedule_record)

    success_response(
      status: "recurring_task_created",
      schedule_id: schedule_id
    )
  rescue StandardError => e
    @logger.error "Recurring task creation failed: #{e.message}"
    error_response("recurring_task_creation_failed", message: e.message)
  end

  def get_task_schedule(schedule_id)
    schedule = find_task_schedule(schedule_id)
    return nil unless schedule

    {
      title: schedule[:title],
      description: schedule[:description],
      frequency: schedule[:schedule][:type],
      next_occurrence: schedule[:next_occurrence],
      assigned_to: schedule[:assigned_to],
      auto_assign: schedule[:auto_assign],
      active: schedule[:active]
    }
  end

  private

  # Validation Methods
  def validate_task_data!(task_data)
    raise ValidationError, "Title is required" if task_data[:title].blank?

    if task_data[:priority] && !VALID_PRIORITIES.include?(task_data[:priority])
      raise ValidationError, "Invalid priority: #{task_data[:priority]}"
    end

    if task_data[:category] && !VALID_CATEGORIES.include?(task_data[:category])
      raise ValidationError, "Invalid category: #{task_data[:category]}"
    end
  end

  # Authorization Methods
  def can_user_modify_task?(task, user_id)
    return true if task[:created_by] == user_id
    return true if task[:assigned_to] == user_id
    return true if task[:assigned_users]&.include?(user_id)

    false
  end

  # Dependency Management
  def validate_dependencies(dependency_ids)
    invalid_deps = dependency_ids.reject { |dep_id| find_task(dep_id) }

    if invalid_deps.any?
      return error_response("invalid_dependencies", invalid_dependency_ids: invalid_deps)
    end

    success_response
  end

  def detect_circular_dependencies(task_id, new_dependencies, visited = [])
    return { has_circular: true, chain: visited + [ task_id ] } if visited.include?(task_id)

    new_visited = visited + [ task_id ]

    new_dependencies.each do |dep_id|
      dep_task = find_task(dep_id)
      next unless dep_task

      dep_result = detect_circular_dependencies(dep_id, dep_task[:depends_on], new_visited)
      return dep_result if dep_result[:has_circular]
    end

    { has_circular: false, chain: [] }
  end

  def find_dependent_tasks(task_id)
    # Find all tasks that depend on this task
    all_tasks = find_all_tasks
    all_tasks.select { |task| task[:depends_on].include?(task_id) }.map { |task| task[:task_id] }
  end

  # Review Status Calculation
  def calculate_review_status(review)
    task = find_task(review[:task_id])
    requires_unanimous = task && task[:requires_unanimous_approval]

    approved_count = review[:approvals].count { |_, approval| approval[:status] == "approved" }
    total_reviewers = review[:reviewers].length
    has_approved_with_comments = review[:approvals].any? { |_, approval| approval[:status] == "approved_with_comments" }

    if requires_unanimous
      return "approved" if approved_count == total_reviewers
      return "rejected" if review[:approvals].any? { |_, approval| approval[:status] == "rejected" }
      "pending"
    else
      return "rejected" if review[:approvals].any? { |_, approval| approval[:status] == "rejected" }
      return "approved_with_comments" if has_approved_with_comments && approved_count == 0
      return "approved" if approved_count > 0 || has_approved_with_comments
      "pending"
    end
  end

  # Git Helper Methods
  def generate_branch_name(task_id, title, pattern = nil)
    pattern ||= "feature/task-{id}-{title-slug}"
    title_slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")

    pattern.gsub("{id}", task_id.to_s).gsub("{title-slug}", title_slug)
  end

  # Performance Calculation Methods
  def calculate_average_completion_time(completed_tasks)
    return 0 if completed_tasks.empty?

    total_time = completed_tasks.sum { |task| task[:time_spent] || 0 }
    (total_time.to_f / completed_tasks.length).round(2)
  end

  def calculate_user_statistics(tasks)
    stats = {}

    tasks.group_by { |task| task[:assigned_to] }.each do |user_id, user_tasks|
      next unless user_id

      completed = user_tasks.count { |task| task[:status] == "completed" }
      total_time = user_tasks.sum { |task| task[:time_spent] || 0 }

      stats[user_id] = {
        tasks_assigned: user_tasks.length,
        tasks_completed: completed,
        completion_rate: user_tasks.length > 0 ? (completed.to_f / user_tasks.length * 100).round(2) : 0,
        total_time_spent: total_time,
        average_time_per_task: user_tasks.length > 0 ? (total_time.to_f / user_tasks.length).round(2) : 0
      }
    end

    stats
  end

  def calculate_user_breakdown(tasks)
    breakdown = {}

    VALID_TASK_STATUSES.each do |status|
      breakdown[status] = tasks.select { |task| task[:status] == status }
                               .group_by { |task| task[:assigned_to] }
                               .transform_values(&:length)
    end

    breakdown
  end

  def generate_chart_data(tasks)
    {
      status_distribution: VALID_TASK_STATUSES.each_with_object({}) do |status, counts|
        counts[status] = tasks.count { |task| task[:status] == status }
      end,
      priority_distribution: VALID_PRIORITIES.each_with_object({}) do |priority, counts|
        counts[priority] = tasks.count { |task| task[:priority] == priority }
      end
    }
  end

  # Automation Helper Methods
  def find_automation_rules_by_trigger(document_id, trigger_event)
    # Find all automation rules for this document with matching trigger
    rules = []
    
    # Get all automation rule keys for this document
    keys = Rails.cache.instance_variable_get(:@data).keys.select do |key|
      key.start_with?("automation_rule_")
    end
    
    keys.each do |key|
      rule = Rails.cache.read(key)
      if rule && rule[:document_id] == document_id && rule[:trigger] == trigger_event
        rules << rule
      end
    end
    
    rules
  end

  def rule_conditions_met?(rule, task, event_data)
    rule[:conditions].all? do |condition|
      field_value = task[condition[:field].to_sym]

      case condition[:operator]
      when "equals"
        field_value == condition[:value]
      when "not_equals"
        field_value != condition[:value]
      when "contains"
        field_value&.include?(condition[:value])
      else
        false
      end
    end
  end

  def calculate_next_occurrence(schedule)
    case schedule[:type]
    when "weekly"
      # Calculate next occurrence based on day_of_week and time
      1.week.from_now
    when "daily"
      1.day.from_now
    when "monthly"
      1.month.from_now
    else
      1.week.from_now
    end
  end

  # Real-time Updates
  def broadcast_task_update(task_id, updates)
    task = find_task(task_id)
    return unless task

    WorkflowChannel.broadcast_to(Document.find(task[:document_id]), {
      type: "task_status_updated",
      task_id: task_id,
      updates: updates,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    @logger.error "Task update broadcast failed: #{e.message}"
  end

  def broadcast_channel_message(channel_id, message_record)
    channel = find_channel(channel_id)
    return unless channel

    channel[:participants].each do |participant_id|
      user = User.find_by(id: participant_id)
      next unless user

      NotificationChannel.broadcast_to(user, {
        type: "channel_message",
        channel_id: channel_id,
        message: message_record,
        timestamp: Time.current.iso8601
      })
    end
  rescue StandardError => e
    @logger.error "Channel message broadcast failed: #{e.message}"
  end

  def send_review_notification(reviewer_id, review_id, notification_type)
    user = User.find_by(id: reviewer_id)
    return unless user

    NotificationChannel.broadcast_to(user, {
      type: notification_type,
      review_id: review_id,
      timestamp: Time.current.iso8601
    })
  rescue StandardError => e
    @logger.error "Review notification failed: #{e.message}"
  end

  def notify_task_assignment(task_id)
    send_task_notification(task_id, "task_assigned")
  end

  # Storage Methods (using Rails.cache for simplicity in test environment)
  def store_task(task_record)
    task_key = "task_#{task_record[:task_id]}"
    document_tasks_key = "document_tasks_#{task_record[:document_id]}"

    Rails.cache.write(task_key, task_record, expires_in: 1.week)

    # Add to document task list
    document_tasks = Rails.cache.read(document_tasks_key) || []
    document_tasks << task_record
    Rails.cache.write(document_tasks_key, document_tasks, expires_in: 1.week)
  end

  def find_task(task_id)
    task_key = "task_#{task_id}"
    Rails.cache.read(task_key)
  end

  def update_task(task_id, updates)
    task = find_task(task_id)
    return unless task

    updated_task = task.merge(updates)
    task_key = "task_#{task_id}"
    Rails.cache.write(task_key, updated_task, expires_in: 1.week)
    
    # Also update the task in the document task list
    document_tasks_key = "document_tasks_#{task[:document_id]}"
    document_tasks = Rails.cache.read(document_tasks_key) || []
    
    # Find and replace the task in the document list
    document_tasks.map! do |doc_task|
      doc_task[:task_id] == task_id ? updated_task : doc_task
    end
    
    Rails.cache.write(document_tasks_key, document_tasks, expires_in: 1.week)
  end

  def find_all_tasks
    # Find all tasks from cache across all documents
    pattern = "task_*"
    task_keys = Rails.cache.instance_variable_get(:@data)&.keys&.select { |k| k.start_with?("task_") } || []
    task_keys.map { |key| Rails.cache.read(key) }.compact
  end

  def find_tasks_by_document(document_id)
    document_tasks_key = "document_tasks_#{document_id}"
    Rails.cache.read(document_tasks_key) || []
  end

  def find_tasks_by_milestone(milestone_id)
    document_tasks = find_tasks_by_document_all
    document_tasks.select { |task| task[:milestone_id] == milestone_id }
  end

  def find_tasks_by_document_all
    # Find tasks across all documents
    pattern = "document_tasks_*"
    cache_keys = Rails.cache.instance_variable_get(:@data)&.keys&.select { |k| k.start_with?("document_tasks_") } || []
    cache_keys.flat_map { |key| Rails.cache.read(key) || [] }
  end

  def store_review(review_record)
    review_key = "review_#{review_record[:review_id]}"
    Rails.cache.write(review_key, review_record, expires_in: 1.week)
  end

  def find_review(review_id)
    review_key = "review_#{review_id}"
    Rails.cache.read(review_key)
  end

  def update_review(review_id, review_record)
    review_key = "review_#{review_id}"
    Rails.cache.write(review_key, review_record, expires_in: 1.week)
  end

  def store_milestone(milestone_record)
    milestone_key = "milestone_#{milestone_record[:milestone_id]}"
    Rails.cache.write(milestone_key, milestone_record, expires_in: 1.week)
  end

  def find_milestone(milestone_id)
    milestone_key = "milestone_#{milestone_id}"
    Rails.cache.read(milestone_key)
  end

  def update_milestone(milestone_id, updates)
    milestone = find_milestone(milestone_id)
    return unless milestone

    updated_milestone = milestone.merge(updates)
    milestone_key = "milestone_#{milestone_id}"
    Rails.cache.write(milestone_key, updated_milestone, expires_in: 1.week)
  end

  def store_channel(channel_record)
    channel_key = "channel_#{channel_record[:channel_id]}"
    Rails.cache.write(channel_key, channel_record, expires_in: 1.week)
  end

  def find_channel(channel_id)
    channel_key = "channel_#{channel_id}"
    Rails.cache.read(channel_key)
  end

  def update_channel(channel_id, updates)
    channel = find_channel(channel_id)
    return unless channel

    updated_channel = channel.merge(updates)
    channel_key = "channel_#{channel_id}"
    Rails.cache.write(channel_key, updated_channel, expires_in: 1.week)
  end

  def store_channel_message(message_record)
    message_key = "message_#{message_record[:message_id]}"
    Rails.cache.write(message_key, message_record, expires_in: 1.week)
  end

  def store_automation_rule(rule_record)
    rule_key = "automation_rule_#{rule_record[:rule_id]}"
    Rails.cache.write(rule_key, rule_record, expires_in: 1.week)
  end

  def store_task_schedule(schedule_record)
    schedule_key = "task_schedule_#{schedule_record[:schedule_id]}"
    Rails.cache.write(schedule_key, schedule_record, expires_in: 1.week)
  end

  def find_task_schedule(schedule_id)
    schedule_key = "task_schedule_#{schedule_id}"
    Rails.cache.read(schedule_key)
  end

  # ID Generation Methods
  def generate_task_id
    "task_#{SecureRandom.hex(8)}"
  end

  def generate_review_id
    "review_#{SecureRandom.hex(8)}"
  end

  def generate_comment_id
    "comment_#{SecureRandom.hex(6)}"
  end

  def generate_milestone_id
    "milestone_#{SecureRandom.hex(8)}"
  end

  def generate_channel_id
    "channel_#{SecureRandom.hex(8)}"
  end

  def generate_message_id
    "message_#{SecureRandom.hex(8)}"
  end

  def generate_rule_id
    "rule_#{SecureRandom.hex(8)}"
  end

  def generate_schedule_id
    "schedule_#{SecureRandom.hex(8)}"
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

    unless defined?(::WorkflowChannel)
      Object.const_set(:WorkflowChannel, Class.new do
        def self.broadcast_to(target, data)
          Rails.logger.info "Workflow broadcast: #{data}"
        end
      end)
    end
  end

  def success_response(data = {})
    { success: true }.merge(data)
  end

  def error_response(error_type, additional_data = {})
    { success: false, error: error_type }.merge(additional_data)
  end
end
