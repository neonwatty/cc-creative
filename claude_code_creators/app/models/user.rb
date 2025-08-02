class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :context_items, dependent: :destroy
  has_many :sub_agents, dependent: :destroy
  has_many :cloud_integrations, dependent: :destroy
  has_many :claude_contexts, dependent: :destroy
  has_many :command_histories, dependent: :destroy
  has_many :command_audit_logs, dependent: :destroy

  enum :role, { guest: "guest", user: "user", editor: "editor", admin: "admin" }, default: :user

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: roles.keys }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Rails 8 authentication token support
  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt
  end

  generates_token_for :email_confirmation, expires_in: 24.hours do
    email_address
  end

  def self.find_by_password_reset_token(token)
    find_by_token_for(:password_reset, token)
  end

  def self.find_by_password_reset_token!(token)
    find_by_token_for!(:password_reset, token)
  end

  def self.find_by_email_confirmation_token(token)
    find_by_token_for(:email_confirmation, token)
  end

  def self.find_by_email_confirmation_token!(token)
    find_by_token_for!(:email_confirmation, token)
  end

  def confirm_email!
    update!(email_confirmed: true, email_confirmed_at: Time.current)
  end

  def send_confirmation_email
    UserMailer.confirmation(self).deliver_later
  end

  # Summary of user's documents
  def documents_summary
    {
      total_count: documents.count,
      recent_count: documents.where('created_at > ?', 7.days.ago).count,
      total_size: 0, # File size not implemented yet
      last_updated: documents.maximum(:updated_at)
    }
  end

  # User's effective permissions based on role
  def effective_permissions
    case role
    when 'admin'
      %w[read write delete manage_users manage_system]
    when 'editor'
      %w[read write delete]
    when 'user'
      %w[read write]
    when 'guest'
      %w[read]
    else
      []
    end
  end

  private

  def password_salt
    password_digest&.last(10)
  end
end
