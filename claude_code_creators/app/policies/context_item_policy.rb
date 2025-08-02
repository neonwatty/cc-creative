class ContextItemPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see context items belonging to their documents
      scope.joins(:document).where(documents: { user_id: user.id })
    end
  end

  def index?
    # User must own the document to view its context items
    record.user_id == user.id
  end

  def show?
    # User must own the context item (through its document)
    record.user_id == user.id
  end

  def create?
    # User must own the document to create context items for it
    record.document.user_id == user.id
  end

  def update?
    # User must own the context item to update it
    record.user_id == user.id
  end

  def destroy?
    # User must own the context item to destroy it
    record.user_id == user.id
  end
end
