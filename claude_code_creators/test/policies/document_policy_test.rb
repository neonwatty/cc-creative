require "test_helper"

class DocumentPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @admin = users(:admin)
    @editor = users(:editor)
    @document = documents(:document_one)
    @other_document = documents(:document_two)
  end

  test "user can view their own documents" do
    policy = DocumentPolicy.new(@user, @document)
    assert policy.show?
  end

  test "user cannot view other users documents" do
    policy = DocumentPolicy.new(@user, @other_document)
    assert_not policy.show?
  end

  test "admin can view any document" do
    policy = DocumentPolicy.new(@admin, @document)
    assert policy.show?
    
    policy = DocumentPolicy.new(@admin, @other_document)
    assert policy.show?
  end

  test "editor can view any document" do
    policy = DocumentPolicy.new(@editor, @document)
    assert policy.show?
    
    policy = DocumentPolicy.new(@editor, @other_document)
    assert policy.show?
  end

  test "user can create documents" do
    policy = DocumentPolicy.new(@user, Document.new)
    assert policy.create?
  end

  test "user can update their own documents" do
    policy = DocumentPolicy.new(@user, @document)
    assert policy.update?
  end

  test "user cannot update other users documents" do
    policy = DocumentPolicy.new(@user, @other_document)
    assert_not policy.update?
  end

  test "admin can update any document" do
    policy = DocumentPolicy.new(@admin, @other_document)
    assert policy.update?
  end

  test "editor can update any document" do
    policy = DocumentPolicy.new(@editor, @other_document)
    assert policy.update?
  end

  test "user can destroy their own documents" do
    policy = DocumentPolicy.new(@user, @document)
    assert policy.destroy?
  end

  test "user cannot destroy other users documents" do
    policy = DocumentPolicy.new(@user, @other_document)
    assert_not policy.destroy?
  end

  test "admin can destroy any document" do
    policy = DocumentPolicy.new(@admin, @other_document)
    assert policy.destroy?
  end

  test "editor cannot destroy documents they don't own" do
    policy = DocumentPolicy.new(@editor, @other_document)
    assert_not policy.destroy?
  end

  test "scope returns only user documents for regular users" do
    scope = DocumentPolicy::Scope.new(@user, Document).resolve
    assert_includes scope, @document
    assert_not_includes scope, @other_document
  end

  test "scope returns all documents for admin" do
    scope = DocumentPolicy::Scope.new(@admin, Document).resolve
    assert_includes scope, @document
    assert_includes scope, @other_document
  end

  test "scope returns all documents for editor" do
    scope = DocumentPolicy::Scope.new(@editor, Document).resolve
    assert_includes scope, @document
    assert_includes scope, @other_document
  end
end