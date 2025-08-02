class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user

  def user
    session&.user
  end
end
