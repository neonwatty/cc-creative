class PluginPermission < ApplicationRecord
  # Associations
  belongs_to :plugin
  belongs_to :user

  # Validations
  validates :plugin, presence: true
  validates :user, presence: true
  validates :permission_type, presence: true
  validates :resource, presence: true
  validates :permission_type, inclusion: {
    in: %w[
      read_files write_files delete_files
      network_access api_access
      clipboard_access
      system_notifications
      user_data_access
      editor_integration
      command_execution
    ]
  }
  validates :permission_type, uniqueness: { scope: [ :plugin_id, :user_id, :resource ] }

  # Callbacks
  before_save :set_granted_at

  # Scopes
  scope :active, -> { where(revoked_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :for_plugin, ->(plugin) { where(plugin: plugin) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_type, ->(type) { where(permission_type: type) }

  # Instance methods
  def active?
    revoked_at.nil?
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def restore!
    update!(revoked_at: nil)
  end

  def duration_granted
    return nil unless granted_at
    end_time = revoked_at || Time.current
    ((end_time - granted_at) / 1.day).round(2)
  end

  def self.grant_permission(plugin, user, permission_type, resource)
    permission = find_or_initialize_by(
      plugin: plugin,
      user: user,
      permission_type: permission_type,
      resource: resource
    )

    if permission.revoked?
      permission.restore!
    elsif permission.new_record?
      permission.save!
    end

    permission
  end

  def self.revoke_permission(plugin, user, permission_type, resource)
    permission = find_by(
      plugin: plugin,
      user: user,
      permission_type: permission_type,
      resource: resource
    )

    permission&.revoke!
    permission
  end

  def self.has_permission?(plugin, user, permission_type, resource)
    active.exists?(
      plugin: plugin,
      user: user,
      permission_type: permission_type,
      resource: resource
    )
  end

  def self.permissions_for_plugin(plugin, user)
    where(plugin: plugin, user: user)
      .active
      .group_by(&:permission_type)
      .transform_values { |perms| perms.map(&:resource) }
  end

  def self.cleanup_expired_permissions(days_old: 365)
    revoked.where("revoked_at < ?", days_old.days.ago).delete_all
  end

  private

  def set_granted_at
    self.granted_at ||= Time.current if granted_at.blank?
  end
end
