class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  def self.find_or_create_from_auth(auth)
    identity = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    identity.email = auth.info.email
    identity.name = auth.info.name
    identity
  end
end
