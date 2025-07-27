require "test_helper"

class DocumentVersionTest < ActiveSupport::TestCase
  def setup
    @document = documents(:one)
    @user = users(:one)
    @version = document_versions(:version_one)
  end

  test "should be valid with valid attributes" do
    assert @version.valid?
  end

  test "should belong to document and user" do
    assert_respond_to @version, :document
    assert_respond_to @version, :created_by_user
    assert_equal @document, @version.document
    assert_equal @user, @version.created_by_user
  end

  test "should require version_number" do
    @version.version_number = nil
    assert_not @version.valid?
    assert_includes @version.errors[:version_number], "can't be blank"
  end

  test "should require unique version_number per document" do
    duplicate_version = @version.dup
    assert_not duplicate_version.valid?
    assert_includes duplicate_version.errors[:version_number], "has already been taken"
  end

  test "should require title and content_snapshot" do
    @version.title = nil
    @version.content_snapshot = nil
    assert_not @version.valid?
    assert_includes @version.errors[:title], "can't be blank"
    assert_includes @version.errors[:content_snapshot], "can't be blank"
  end

  test "should ensure tags_snapshot is always an array" do
    @version.tags_snapshot = nil
    @version.save
    assert_equal [], @version.reload.tags_snapshot
  end

  test "should provide version_type based on is_auto_version" do
    assert_equal "Manual", @version.version_type
    
    auto_version = document_versions(:auto_version)
    assert_equal "Auto", auto_version.version_type
  end

  test "should provide display_name" do
    assert_equal "Initial Version", @version.display_name
    
    @version.version_name = nil
    assert_equal "Version 1", @version.display_name
  end

  test "should detect content changes from previous version" do
    version_two = document_versions(:version_two)
    assert version_two.content_changed_from_previous?
    
    # First version should always return true (no previous version)
    assert @version.content_changed_from_previous?
  end

  test "should detect tag changes from previous version" do
    version_two = document_versions(:version_two)
    assert version_two.tags_changed_from_previous?
    
    # First version should always return true (no previous version)
    assert @version.tags_changed_from_previous?
  end

  test "should provide content diff from previous version" do
    version_two = document_versions(:version_two)
    diff = version_two.content_diff_from_previous
    
    assert_not_nil diff
    assert_equal @version.content_snapshot, diff[:previous_content]
    assert_equal version_two.content_snapshot, diff[:current_content]
    assert_equal 2, diff[:word_count_diff]
  end

  test "should filter by scopes" do
    assert_includes DocumentVersion.auto_versions, document_versions(:auto_version)
    assert_not_includes DocumentVersion.auto_versions, @version
    
    assert_includes DocumentVersion.manual_versions, @version
    assert_not_includes DocumentVersion.manual_versions, document_versions(:auto_version)
    
    assert_includes DocumentVersion.by_document(@document), @version
    assert_not_includes DocumentVersion.by_document(@document), document_versions(:auto_version)
  end

  test "create_from_document should create new version" do
    # Create a fresh document without conflicting fixture data
    fresh_document = Document.create!(
      title: "Fresh Document",
      content: "Fresh content for versioning test",
      description: "Fresh description",
      user: @user,
      current_version_number: 0
    )
    
    version = DocumentVersion.create_from_document(fresh_document, @user, {
      version_name: "Test Version",
      version_notes: "Test notes"
    })
    
    assert version.persisted?
    assert_equal 1, version.version_number
    assert_equal fresh_document.title, version.title
    assert_equal fresh_document.content.to_plain_text, version.content_snapshot
    assert_equal @user, version.created_by_user
    assert_equal "Test Version", version.version_name
    assert_equal "Test notes", version.version_notes
    assert_equal 1, fresh_document.reload.current_version_number
  end
end
