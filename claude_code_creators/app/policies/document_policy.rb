class DocumentPolicy < ApplicationPolicy
  attr_reader :user, :document

  def initialize(user, document)
    @user = user
    @document = document
  end

  def index?
    true
  end

  def show?
    # Users can see their own documents
    # Admins can see all documents
    # Editors can see all documents
    owner? || admin? || editor?
  end

  def create?
    # All authenticated users can create documents
    user.present?
  end

  def new?
    create?
  end

  def update?
    # Users can update their own documents
    # Admins can update all documents
    # Editors can update all documents
    owner? || admin? || editor?
  end

  def edit?
    update?
  end

  def destroy?
    # Users can destroy their own documents
    # Admins can destroy all documents
    owner? || admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin? || user.editor?
        # Admins and editors can see all documents
        scope.all
      else
        # Regular users can only see their own documents
        scope.where(user: user)
      end
    end
  end

  private

  def owner?
    user.present? && document.user_id == user.id
  end

  def admin?
    user.present? && user.admin?
  end

  def editor?
    user.present? && user.editor?
  end
end
