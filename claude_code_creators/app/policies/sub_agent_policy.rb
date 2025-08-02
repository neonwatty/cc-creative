class SubAgentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see sub_agents belonging to their documents
      scope.joins(:document).where(documents: { user_id: user.id })
    end
  end

  def index?
    # Checked at document level in controller
    true
  end

  def show?
    # User must own the sub_agent (through its document)
    record.user_id == user.id || record.document.user_id == user.id
  end

  def create?
    # User must own the document to create sub_agents for it
    record.document.user_id == user.id
  end

  def update?
    # User must own the sub_agent or the document
    record.user_id == user.id || record.document.user_id == user.id
  end

  def destroy?
    # User must own the sub_agent or the document
    record.user_id == user.id || record.document.user_id == user.id
  end

  def activate?
    update?
  end

  def complete?
    update?
  end

  def pause?
    update?
  end
end
