class CloudSyncChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to cloud sync updates for the current user
    stream_for current_user

    # Also subscribe to specific integration channels if provided
    if params[:integration_id].present?
      integration = current_user.cloud_integrations.find_by(id: params[:integration_id])
      if integration
        stream_for integration
      end
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # Client can request sync status updates
  def get_sync_status(data)
    integration_id = data["integration_id"]

    if integration_id.present?
      integration = current_user.cloud_integrations.find_by(id: integration_id)
      if integration
        # Get current sync status (this would be enhanced with actual job tracking)
        status = {
          integration_id: integration.id,
          provider: integration.provider,
          syncing: false, # This would check actual sync job status
          files_count: integration.cloud_files.count,
          last_sync: integration.cloud_files.maximum(:last_synced_at),
          error: nil
        }

        transmit(status)
      end
    else
      # Return status for all user integrations
      statuses = current_user.cloud_integrations.map do |integration|
        {
          integration_id: integration.id,
          provider: integration.provider,
          syncing: false, # This would check actual sync job status
          files_count: integration.cloud_files.count,
          last_sync: integration.cloud_files.maximum(:last_synced_at),
          error: nil
        }
      end

      transmit({ integrations: statuses })
    end
  end

  # Client can trigger sync (with rate limiting)
  def trigger_sync(data)
    integration_id = data["integration_id"]

    return unless integration_id.present?

    integration = current_user.cloud_integrations.find_by(id: integration_id)
    return unless integration&.active?

    # Rate limiting: prevent sync requests more than once every 30 seconds
    cache_key = "sync_limit:#{current_user.id}:#{integration_id}"
    if Rails.cache.exist?(cache_key)
      transmit({
        error: "Sync rate limited. Please wait before syncing again.",
        integration_id: integration_id
      })
      return
    end

    # Set rate limit cache
    Rails.cache.write(cache_key, true, expires_in: 30.seconds)

    # Queue sync job
    CloudFileSyncJob.perform_later(integration)

    # Notify client that sync started
    transmit({
      event: "sync_started",
      integration_id: integration_id,
      provider: integration.provider,
      message: "Sync started for #{integration.provider_name}"
    })

    # Broadcast to all subscribers
    CloudSyncChannel.broadcast_to(current_user, {
      event: "sync_started",
      integration_id: integration_id,
      provider: integration.provider
    })
  end

  private

  def current_user
    # This assumes user is set in the connection
    connection.current_user
  end
end
