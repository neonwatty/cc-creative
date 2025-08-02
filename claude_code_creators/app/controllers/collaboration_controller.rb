# frozen_string_literal: true

class CollaborationController < ApplicationController
  before_action :set_document
  before_action :authorize_collaboration_access!
  before_action :set_collaboration_session, only: %i[join leave status reconnect terminate]

  # Rate limiting for operations
  before_action :check_rate_limit, only: [ :operation ]

  # Session Management
  def start
    if existing_session = find_active_session
      render json: {
        status: "session_exists",
        session_id: existing_session.session_id,
        message: "Active session already exists",
        websocket_url: collaboration_websocket_url(existing_session)
      }
      return
    end

    session_settings = session_params[:session_settings] || {}

    collaboration_session = CollaborationSession.create!(
      document: @document,
      user: current_user,
      session_id: generate_session_id,
      settings: session_settings.to_json,
      max_users: session_settings[:max_users] || 10,
      started_at: Time.current,
      expires_at: session_settings[:expires_at]&.to_datetime || 24.hours.from_now
    )

    # Initialize presence tracking
    add_user_to_session_presence(collaboration_session)

    # Broadcast session started
    broadcast_session_event(collaboration_session, "session_started", {
      started_by: serialize_user(current_user)
    })

    render json: {
      status: "session_started",
      session_id: collaboration_session.session_id,
      document_id: @document.id,
      user_id: current_user.id,
      max_users: collaboration_session.max_users,
      expires_at: collaboration_session.expires_at,
      websocket_url: collaboration_websocket_url(collaboration_session)
    }
  rescue StandardError => e
    render json: {
      status: "error",
      error: e.message
    }, status: :unprocessable_entity
  end

  def join
    unless @collaboration_session
      render json: { error: "session_not_found" }, status: :not_found
      return
    end

    if @collaboration_session.active_users_count >= @collaboration_session.max_users
      render json: { error: "session_full" }, status: :unprocessable_entity
      return
    end

    # Add user to session
    add_user_to_session_presence(@collaboration_session)
    @collaboration_session.increment!(:active_users_count)

    # Broadcast user joined
    broadcast_session_event(@collaboration_session, "user_joined", {
      user: serialize_user(current_user),
      active_users_count: @collaboration_session.active_users_count
    })

    render json: {
      status: "session_joined",
      session_id: @collaboration_session.session_id,
      user_id: current_user.id,
      active_users: get_session_active_users(@collaboration_session),
      websocket_url: collaboration_websocket_url(@collaboration_session)
    }
  end

  def leave
    unless @collaboration_session
      render json: { error: "session_not_found" }, status: :not_found
      return
    end

    # Remove user from session
    remove_user_from_session_presence(@collaboration_session)
    @collaboration_session.decrement!(:active_users_count)

    # Broadcast user left
    broadcast_session_event(@collaboration_session, "user_left", {
      user_id: current_user.id,
      active_users_count: @collaboration_session.active_users_count
    })

    # End session if no users left
    if @collaboration_session.active_users_count <= 0
      @collaboration_session.update!(status: "ended")
      broadcast_session_event(@collaboration_session, "session_ended")
    end

    render json: {
      status: "session_left",
      session_id: @collaboration_session.session_id
    }
  end

  # Document Locking
  def lock
    lock_params = params.permit(:lock_type, :timeout, section: %i[start end])

    unless %w[read write].include?(lock_params[:lock_type])
      render json: { error: "invalid_lock_type" }, status: :unprocessable_entity
      return
    end

    # Check for conflicting locks
    conflicts = check_lock_conflicts(lock_params)
    if conflicts.any?
      render json: {
        error: "lock_conflict",
        conflicting_lock: conflicts.first,
        message: "Cannot acquire lock due to conflicts"
      }, status: :conflict
      return
    end

    # Acquire lock
    lock_data = {
      lock_id: generate_lock_id,
      lock_type: lock_params[:lock_type],
      user_id: current_user.id,
      section: lock_params[:section],
      acquired_at: Time.current,
      expires_at: lock_params[:timeout] ? lock_params[:timeout].to_i.seconds.from_now : 5.minutes.from_now
    }

    store_document_lock(@document.id, lock_data)

    # Broadcast lock acquired
    broadcast_lock_event(@document, "lock_acquired", lock_data)

    render json: {
      status: "lock_acquired",
      lock_id: lock_data[:lock_id],
      lock_type: lock_data[:lock_type],
      locked_by: current_user.id,
      expires_at: lock_data[:expires_at],
      section: lock_data[:section]
    }
  end

  def unlock
    lock_id = params[:lock_id]

    lock_data = get_document_lock(@document.id, lock_id)
    unless lock_data
      render json: { error: "lock_not_found" }, status: :not_found
      return
    end

    unless lock_data[:user_id] == current_user.id || current_user.admin?
      render json: { error: "unauthorized" }, status: :forbidden
      return
    end

    # Release lock
    release_document_lock(@document.id, lock_id)

    # Broadcast lock released
    broadcast_lock_event(@document, "lock_released", {
      lock_id: lock_id,
      released_by: current_user.id
    })

    render json: {
      status: "lock_released",
      lock_id: lock_id
    }
  end

  def lock_status
    lock_id = params[:lock_id]
    lock_data = get_document_lock(@document.id, lock_id)

    unless lock_data
      render json: { error: "lock_expired" }, status: :not_found
      return
    end

    render json: {
      status: "lock_active",
      lock_data: lock_data
    }
  end

  # Permissions and Access Control
  def permissions
    permissions = {
      can_collaborate: can_collaborate?(@document),
      can_read: can_read?(@document),
      can_write: can_write?(@document),
      can_admin: can_admin?(@document),
      user_role: current_user.role
    }

    render json: permissions
  end

  # Presence and Activity
  def presence
    status = params[:status] || "active"
    activity = params[:activity] || "viewing"

    # Update user presence
    update_user_presence(@document, {
      status: status,
      activity: activity,
      last_seen: Time.current
    })

    # Broadcast presence update
    PresenceChannel.broadcast_to(@document, {
      type: "user_status_changed",
      user_id: current_user.id,
      user_name: current_user.name,
      status: status,
      activity: activity,
      timestamp: Time.current.iso8601
    })

    render json: { status: "presence_updated" }
  end

  def typing
    typing = params[:typing] == true || params[:typing] == "true"

    # Broadcast typing indicator
    PresenceChannel.broadcast_to(@document, {
      type: typing ? "user_typing" : "user_stopped_typing",
      user_id: current_user.id,
      user_name: current_user.name,
      timestamp: Time.current.iso8601
    })

    render json: { status: "typing_updated" }
  end

  # Connection Recovery
  def reconnect
    unless @collaboration_session
      render json: { error: "session_not_found" }, status: :not_found
      return
    end

    last_known_state = params[:last_known_state] || {}

    # Get missed operations since last known state
    missed_operations = get_missed_operations(@document.id, last_known_state)

    # Re-add user to presence
    add_user_to_session_presence(@collaboration_session)

    # Get current document state
    sync_data = {
      current_content: @document.content,
      content_version: @document.current_version_number,
      active_users: get_session_active_users(@collaboration_session),
      active_locks: get_active_locks(@document.id)
    }

    render json: {
      status: "reconnected",
      session_id: @collaboration_session.session_id,
      sync_data: sync_data,
      missed_operations: missed_operations
    }
  end

  # Real-time Operation Processing
  def operation
    operation_data = operation_params.to_h.symbolize_keys
    operation_data[:user_id] = current_user.id
    operation_data[:timestamp] ||= Time.current.to_f

    # Process operation through OperationalTransformService
    result = OperationalTransformService.new.apply_and_broadcast_operation(@document, operation_data)

    case result[:status]
    when "success"
      render json: {
        status: "operation_applied",
        operation_id: result[:transformed_operation][:operation_id],
        transformed_operation: result[:transformed_operation]
      }
    when "conflict_resolved"
      render json: {
        status: "conflict_resolved",
        operation_id: result[:transformed_operation][:operation_id],
        transformed_operation: result[:transformed_operation],
        conflicts: result[:conflicts],
        resolution_strategy: result[:resolution_strategy]
      }
    else
      render json: {
        status: "error",
        error: result[:error]
      }, status: :unprocessable_entity
    end
  rescue OperationalTransformService::InvalidOperationError => e
    render json: {
      error: "invalid_operation",
      message: e.message
    }, status: :unprocessable_entity
  rescue StandardError => e
    render json: {
      error: "processing_error",
      message: e.message
    }, status: :internal_server_error
  end

  # Session Status and Monitoring
  def status
    unless @collaboration_session
      render json: { error: "session_not_found" }, status: :not_found
      return
    end

    active_users = get_session_active_users(@collaboration_session)
    active_locks = get_active_locks(@document.id)
    operation_count = OperationalTransform.for_document(@document.id).recent.count

    render json: {
      session_status: @collaboration_session.status,
      session_id: @collaboration_session.session_id,
      active_users: active_users,
      active_locks: active_locks,
      operation_count: operation_count,
      document_version: @document.current_version_number,
      last_activity: get_last_activity(@document.id)
    }
  end

  def users
    active_users = get_document_collaborators(@document.id)

    render json: {
      users: active_users.map { |user| serialize_user(user) },
      total_count: active_users.length
    }
  end

  # Administrative Controls
  def terminate
    unless current_user.admin? || @document.user == current_user
      render json: { error: "unauthorized" }, status: :forbidden
      return
    end

    unless @collaboration_session
      render json: { error: "session_not_found" }, status: :not_found
      return
    end

    reason = params[:reason] || "terminated_by_admin"

    # End session
    @collaboration_session.update!(status: "terminated")

    # Clear all presence data
    clear_session_presence(@collaboration_session)

    # Release all locks
    release_all_document_locks(@document.id)

    # Broadcast termination
    broadcast_session_event(@collaboration_session, "session_terminated", {
      terminated_by: current_user.id,
      reason: reason
    })

    render json: {
      status: "session_terminated",
      session_id: @collaboration_session.session_id,
      terminated_by: current_user.id,
      reason: reason
    }
  end

  private

  def set_document
    @document = Document.find(params[:document_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "document_not_found" }, status: :not_found
  end

  def set_collaboration_session
    session_id = params[:session_id]
    @collaboration_session = CollaborationSession.find_by(
      session_id: session_id,
      document: @document
    ) if session_id
  end

  def authorize_collaboration_access!
    unless can_collaborate?(@document)
      render json: { error: "unauthorized" }, status: :forbidden
    end
  end

  def check_rate_limit
    cache_key = "rate_limit:operations:#{current_user.id}"
    current_count = Rails.cache.read(cache_key) || 0

    if current_count >= 30 # 30 operations per minute
      render json: { error: "rate_limit_exceeded" }, status: :too_many_requests
      return
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end

  def session_params
    params.permit(session_settings: %i[max_users editing_mode conflict_resolution expires_at])
  end

  def operation_params
    params.require(:operation).permit(:type, :position, :length, :content, :timestamp)
  end

  # Session Management Helpers
  def find_active_session
    CollaborationSession.find_by(
      document: @document,
      status: "active"
    )
  end

  def generate_session_id
    "collab_#{SecureRandom.hex(16)}"
  end

  def generate_lock_id
    "lock_#{SecureRandom.hex(8)}"
  end

  def collaboration_websocket_url(session)
    # Return WebSocket URL for ActionCable connection
    "#{request.protocol == 'https://' ? 'wss' : 'ws'}://#{request.host_with_port}/cable"
  end

  # Presence Management
  def add_user_to_session_presence(session)
    presence_key = "collaboration_session_#{session.session_id}_users"
    users = Rails.cache.read(presence_key) || {}
    users[current_user.id] = {
      id: current_user.id,
      name: current_user.name,
      email: current_user.email_address,
      joined_at: Time.current.iso8601,
      last_seen: Time.current.iso8601
    }
    Rails.cache.write(presence_key, users, expires_in: 1.hour)
  end

  def remove_user_from_session_presence(session)
    presence_key = "collaboration_session_#{session.session_id}_users"
    users = Rails.cache.read(presence_key) || {}
    users.delete(current_user.id)
    Rails.cache.write(presence_key, users, expires_in: 1.hour)
  end

  def get_session_active_users(session)
    presence_key = "collaboration_session_#{session.session_id}_users"
    users = Rails.cache.read(presence_key) || {}
    users.values
  end

  def clear_session_presence(session)
    presence_key = "collaboration_session_#{session.session_id}_users"
    Rails.cache.delete(presence_key)
  end

  # Lock Management
  def store_document_lock(document_id, lock_data)
    locks_key = "document_#{document_id}_locks"
    locks = Rails.cache.read(locks_key) || {}
    locks[lock_data[:lock_id]] = lock_data
    Rails.cache.write(locks_key, locks, expires_in: 1.hour)
  end

  def get_document_lock(document_id, lock_id)
    locks_key = "document_#{document_id}_locks"
    locks = Rails.cache.read(locks_key) || {}
    lock_data = locks[lock_id]

    # Check if lock has expired
    if lock_data && lock_data[:expires_at] < Time.current
      locks.delete(lock_id)
      Rails.cache.write(locks_key, locks, expires_in: 1.hour)
      return nil
    end

    lock_data
  end

  def release_document_lock(document_id, lock_id)
    locks_key = "document_#{document_id}_locks"
    locks = Rails.cache.read(locks_key) || {}
    locks.delete(lock_id)
    Rails.cache.write(locks_key, locks, expires_in: 1.hour)
  end

  def get_active_locks(document_id)
    locks_key = "document_#{document_id}_locks"
    locks = Rails.cache.read(locks_key) || {}

    # Filter out expired locks
    current_time = Time.current
    active_locks = locks.select { |_, lock| lock[:expires_at] > current_time }

    # Update cache with only active locks
    Rails.cache.write(locks_key, active_locks, expires_in: 1.hour)

    active_locks.values
  end

  def release_all_document_locks(document_id)
    locks_key = "document_#{document_id}_locks"
    Rails.cache.delete(locks_key)
  end

  def check_lock_conflicts(lock_params)
    active_locks = get_active_locks(@document.id)
    section = lock_params[:section]

    active_locks.select do |lock|
      next false if lock[:user_id] == current_user.id # User can have multiple locks
      next true if lock_params[:lock_type] == "write" || lock[:lock_type] == "write" # Write locks conflict with everything

      # Check section overlap if both have sections defined
      if section && lock[:section]
        sections_overlap?(section, lock[:section])
      else
        false # Read locks don't conflict with each other if no sections
      end
    end
  end

  def sections_overlap?(section1, section2)
    return false unless section1 && section2

    start1, end1 = section1[:start], section1[:end]
    start2, end2 = section2[:start], section2[:end]

    !(end1 <= start2 || end2 <= start1)
  end

  # Broadcasting Helpers
  def broadcast_session_event(session, event_type, data = {})
    CollaborationChannel.broadcast_to(session.document, {
      type: event_type,
      session_id: session.session_id,
      timestamp: Time.current.iso8601,
      **data
    })
  end

  def broadcast_lock_event(document, event_type, data = {})
    CollaborationChannel.broadcast_to(document, {
      type: event_type,
      document_id: document.id,
      timestamp: Time.current.iso8601,
      **data
    })
  end

  # Permission Helpers
  def can_collaborate?(document)
    can_write?(document) # Collaboration requires write access
  end

  def can_read?(document)
    document.user == current_user || current_user.admin?
  end

  def can_write?(document)
    document.user == current_user || current_user.admin?
  end

  def can_admin?(document)
    document.user == current_user || current_user.admin?
  end

  # Utility Helpers
  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email_address,
      role: user.role
    }
  end

  def get_missed_operations(document_id, last_known_state)
    since_timestamp = last_known_state[:last_operation_timestamp]
    return [] unless since_timestamp

    OperationalTransform.for_document(document_id)
                       .where("timestamp > ?", since_timestamp)
                       .order(:timestamp)
                       .limit(100) # Limit to prevent huge responses
                       .map(&:to_operation_hash)
  end

  def get_document_collaborators(document_id)
    # Get users from all active collaboration sessions
    sessions = CollaborationSession.where(document_id: document_id, status: "active")
    user_ids = []

    sessions.each do |session|
      users = get_session_active_users(session)
      user_ids.concat(users.map { |u| u[:id] })
    end

    User.where(id: user_ids.uniq)
  end

  def get_last_activity(document_id)
    last_operation = OperationalTransform.for_document(document_id).order(:applied_at).last
    last_operation&.applied_at || @document.updated_at
  end

  def update_user_presence(document, presence_data)
    presence_key = "user_presence_#{document.id}_#{current_user.id}"
    Rails.cache.write(presence_key, presence_data.merge(user_id: current_user.id), expires_in: 10.minutes)
  end
end
