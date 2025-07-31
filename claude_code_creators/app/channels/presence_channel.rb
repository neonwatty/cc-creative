# frozen_string_literal: true

class PresenceChannel < ApplicationCable::Channel
  def subscribed
    document = find_document
    return reject unless document && authorized_for_document?(document)

    stream_for document
    
    # Track user presence
    add_user_to_presence(document)
    
    # Broadcast user joined to other subscribers
    broadcast_presence_update(document, {
      type: 'user_joined',
      user: serialize_user(current_user),
      timestamp: Time.current.iso8601
    })
    
    logger.info "User #{current_user.id} joined presence for document #{document.id}"
  end

  def unsubscribed
    document = find_document
    return unless document && authorized_for_document?(document)

    # Remove user from presence
    remove_user_from_presence(document)
    
    # Broadcast user left to other subscribers
    broadcast_presence_update(document, {
      type: 'user_left',
      user_id: current_user.id,
      timestamp: Time.current.iso8601
    })
    
    logger.info "User #{current_user.id} left presence for document #{document.id}"
  end

  # Handle typing indicators
  def user_typing(data = {})
    document = find_document
    return unless document && authorized_for_document?(document)

    # Update typing timestamp
    update_typing_status(document, true)
    
    # Broadcast to other users (excluding sender)
    broadcast_presence_update(document, {
      type: 'user_typing',
      user_id: current_user.id,
      user_name: current_user.name,
      timestamp: Time.current.iso8601
    }, except: current_user)
  end

  def user_stopped_typing(data = {})
    document = find_document
    return unless document && authorized_for_document?(document)

    # Update typing timestamp
    update_typing_status(document, false)
    
    # Broadcast to other users (excluding sender)
    broadcast_presence_update(document, {
      type: 'user_stopped_typing',
      user_id: current_user.id,
      timestamp: Time.current.iso8601
    }, except: current_user)
  end

  # Handle cursor position updates
  def cursor_moved(data = {})
    document = find_document
    return unless document && authorized_for_document?(document)

    position = data['position'] || {}
    return unless position['x'] && position['y']

    # Store cursor position (optional, for persistence)
    update_cursor_position(document, position)
    
    # Broadcast to other users (excluding sender)
    broadcast_presence_update(document, {
      type: 'cursor_moved',
      user_id: current_user.id,
      user_name: current_user.name,
      position: {
        x: position['x'].to_f,
        y: position['y'].to_f
      },
      timestamp: Time.current.iso8601
    }, except: current_user)
  end

  # Handle selection changes
  def selection_changed(data = {})
    document = find_document
    return unless document && authorized_for_document?(document)

    selection = data['selection'] || {}
    
    # Broadcast selection to other users (excluding sender)
    broadcast_presence_update(document, {
      type: 'selection_changed',
      user_id: current_user.id,
      user_name: current_user.name,
      selection: selection,
      timestamp: Time.current.iso8601
    }, except: current_user)
  end

  # Get current presence for a document
  def get_presence(data = {})
    document = find_document
    return unless document && authorized_for_document?(document)

    presence_data = get_document_presence(document)
    
    # Send presence data back to requesting user
    transmit({
      type: 'presence_data',
      users: presence_data[:users],
      cursors: presence_data[:cursors],
      typing_users: presence_data[:typing_users],
      timestamp: Time.current.iso8601
    })
  end

  private

  def find_document
    document_id = params[:document_id]
    return nil unless document_id
    
    @document ||= Document.find_by(id: document_id)
  end

  def authorized_for_document?(document)
    # Use Pundit policy to check authorization
    Pundit.policy(current_user, document).show?
  rescue Pundit::NotAuthorizedError
    false
  end

  def add_user_to_presence(document)
    # Store user presence in Redis or in-memory store
    presence_key = "document_#{document.id}_presence"
    user_data = {
      id: current_user.id,
      name: current_user.name,
      email: current_user.email_address,
      joined_at: Time.current.iso8601,
      last_seen: Time.current.iso8601,
      typing: false
    }

    if Rails.cache.respond_to?(:hset)
      # Redis-backed cache
      Rails.cache.hset(presence_key, current_user.id, user_data.to_json)
      Rails.cache.expire(presence_key, 1.hour.to_i)
    else
      # Memory-backed cache
      presence_data = Rails.cache.read(presence_key) || {}
      presence_data[current_user.id] = user_data
      Rails.cache.write(presence_key, presence_data, expires_in: 1.hour)
    end
  end

  def remove_user_from_presence(document)
    presence_key = "document_#{document.id}_presence"
    
    if Rails.cache.respond_to?(:hdel)
      # Redis-backed cache
      Rails.cache.hdel(presence_key, current_user.id)
    else
      # Memory-backed cache
      presence_data = Rails.cache.read(presence_key) || {}
      presence_data.delete(current_user.id)
      Rails.cache.write(presence_key, presence_data, expires_in: 1.hour)
    end
  end

  def update_typing_status(document, typing)
    presence_key = "document_#{document.id}_presence"
    
    if Rails.cache.respond_to?(:hget)
      # Redis-backed cache
      user_data_json = Rails.cache.hget(presence_key, current_user.id)
      return unless user_data_json
      
      user_data = JSON.parse(user_data_json)
      user_data['typing'] = typing
      user_data['last_seen'] = Time.current.iso8601
      user_data['typing_at'] = typing ? Time.current.iso8601 : nil
      
      Rails.cache.hset(presence_key, current_user.id, user_data.to_json)
    else
      # Memory-backed cache
      presence_data = Rails.cache.read(presence_key) || {}
      if presence_data[current_user.id]
        presence_data[current_user.id][:typing] = typing
        presence_data[current_user.id][:last_seen] = Time.current.iso8601
        presence_data[current_user.id][:typing_at] = typing ? Time.current.iso8601 : nil
        Rails.cache.write(presence_key, presence_data, expires_in: 1.hour)
      end
    end
  end

  def update_cursor_position(document, position)
    cursor_key = "document_#{document.id}_cursors"
    cursor_data = {
      user_id: current_user.id,
      x: position['x'].to_f,
      y: position['y'].to_f,
      updated_at: Time.current.iso8601
    }

    if Rails.cache.respond_to?(:hset)
      # Redis-backed cache
      Rails.cache.hset(cursor_key, current_user.id, cursor_data.to_json)
      Rails.cache.expire(cursor_key, 10.minutes.to_i)
    else
      # Memory-backed cache
      cursors = Rails.cache.read(cursor_key) || {}
      cursors[current_user.id] = cursor_data
      Rails.cache.write(cursor_key, cursors, expires_in: 10.minutes)
    end
  end

  def get_document_presence(document)
    presence_key = "document_#{document.id}_presence"
    cursor_key = "document_#{document.id}_cursors"
    
    users = []
    cursors = {}
    typing_users = []

    if Rails.cache.respond_to?(:hgetall)
      # Redis-backed cache
      presence_data = Rails.cache.hgetall(presence_key) || {}
      presence_data.each do |user_id, user_data_json|
        next if user_id.to_i == current_user.id # Exclude current user
        
        begin
          user_data = JSON.parse(user_data_json)
          users << serialize_user_from_data(user_data)
          typing_users << user_id.to_i if user_data['typing']
        rescue JSON::ParserError
          next
        end
      end

      cursor_data = Rails.cache.hgetall(cursor_key) || {}
      cursor_data.each do |user_id, cursor_json|
        next if user_id.to_i == current_user.id # Exclude current user
        
        begin
          cursor_info = JSON.parse(cursor_json)
          cursors[user_id] = cursor_info
        rescue JSON::ParserError
          next
        end
      end
    else
      # Memory-backed cache
      presence_data = Rails.cache.read(presence_key) || {}
      presence_data.each do |user_id, user_data|
        next if user_id == current_user.id # Exclude current user
        
        users << serialize_user_from_data(user_data)
        typing_users << user_id if user_data[:typing]
      end

      cursors = Rails.cache.read(cursor_key) || {}
      cursors = cursors.reject { |user_id, _| user_id == current_user.id }
    end

    {
      users: users,
      cursors: cursors,
      typing_users: typing_users
    }
  end

  def broadcast_presence_update(document, data, options = {})
    # Exclude specific users if needed
    if options[:except]
      excluded_users = Array(options[:except])
      # This would need to be implemented based on your ActionCable setup
      # For now, we'll broadcast to all and let clients filter
    end

    PresenceChannel.broadcast_to(document, data)
  end

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email_address,
      avatar_url: nil  # Avatar functionality not implemented in User model
    }
  end

  def serialize_user_from_data(user_data)
    if user_data.is_a?(Hash) && user_data.key?('id')
      # JSON data (from Redis)
      {
        id: user_data['id'],
        name: user_data['name'],
        email: user_data['email'],
        joined_at: user_data['joined_at'],
        last_seen: user_data['last_seen'],
        typing: user_data['typing']
      }
    else 
      # Ruby hash data (from memory cache)
      user_data
    end
  end
end