require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User", 
      email_address: "test@example.com",
      password: "password123"
    )
    @document = Document.new(
      title: "Test Document",
      content: "This is test content for the document.",
      description: "Test description",
      user: @user
    )
  end

  test "should be valid with valid attributes" do
    assert @document.valid?
  end

  test "should require a title" do
    @document.title = ""
    assert_not @document.valid?
    assert_includes @document.errors[:title], "can't be blank"
  end

  test "should require content" do
    @document.content = ""
    assert_not @document.valid?
    assert_includes @document.errors[:content], "can't be blank"
  end

  test "should require a user" do
    @document.user = nil
    assert_not @document.valid?
    assert_includes @document.errors[:user], "must exist"
  end

  test "should limit title length to 255 characters" do
    @document.title = "a" * 256
    assert_not @document.valid?
    assert_includes @document.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should limit description length to 1000 characters" do
    @document.description = "a" * 1001
    assert_not @document.valid?
    assert_includes @document.errors[:description], "is too long (maximum is 1000 characters)"
  end

  test "should handle tags as an array" do
    @document.tags = ["ruby", "rails", "programming"]
    @document.save!
    @document.reload
    assert_equal ["ruby", "rails", "programming"], @document.tags
  end

  test "should convert tag_list string to array" do
    @document.tag_list = "ruby, rails, programming"
    assert_equal ["ruby", "rails", "programming"], @document.tags
  end

  test "should handle empty tag_list" do
    @document.tag_list = ""
    assert_equal [], @document.tags
  end

  test "should remove duplicate tags" do
    @document.tag_list = "ruby, rails, ruby, programming"
    assert_equal ["ruby", "rails", "programming"], @document.tags
  end

  test "should add tags without duplicates" do
    @document.tags = ["ruby"]
    @document.add_tag("rails")
    @document.add_tag("ruby") # Should not add duplicate
    assert_equal ["ruby", "rails"], @document.tags
  end

  test "should remove tags" do
    @document.tags = ["ruby", "rails", "programming"]
    @document.remove_tag("rails")
    assert_equal ["ruby", "programming"], @document.tags
  end

  test "should calculate word count" do
    @document.content = "This is a test document with exactly eight words."
    assert_equal 9, @document.word_count
  end

  test "should calculate reading time" do
    @document.content = "word " * 400  # 400 words
    assert_equal 2, @document.reading_time  # 400/200 = 2 minutes
  end

  test "should generate excerpt" do
    @document.content = "This is a very long document that contains a lot of text that should be truncated when we generate an excerpt for preview purposes. It continues on and on with more content than we need to show in a summary."
    excerpt = @document.excerpt(50)
    assert excerpt.length <= 50
    assert excerpt.ends_with?("...")
  end

  test "should handle blank content for excerpt" do
    @document.content = ""
    assert_equal "", @document.excerpt
  end

  test "recent scope should order by created_at desc" do
    # Clear existing documents to ensure clean test
    Document.destroy_all
    
    old_doc = @user.documents.create!(
      title: "Old Document",
      content: "Old content",
      created_at: 2.days.ago
    )
    new_doc = @user.documents.create!(
      title: "New Document",
      content: "New content",
      created_at: 1.day.ago
    )
    
    documents = Document.recent
    assert_equal new_doc.id, documents.first.id
    assert_equal old_doc.id, documents.second.id
  end

  test "by_user scope should filter by user" do
    other_user = User.create!(
      name: "Other User", 
      email_address: "other@example.com",
      password: "password123"
    )
    @document.save!
    other_doc = other_user.documents.create!(title: "Other Doc", content: "Other content")
    
    user_docs = Document.by_user(@user)
    assert_includes user_docs, @document
    assert_not_includes user_docs, other_doc
  end

  test "with_tag scope should filter by tag" do
    @document.tags = ["ruby", "rails"]
    @document.save!
    
    other_doc = @user.documents.create!(
      title: "Other Doc",
      content: "Other content",
      tags: ["javascript", "react"]
    )
    
    ruby_docs = Document.with_tag("ruby")
    assert_includes ruby_docs, @document
    assert_not_includes ruby_docs, other_doc
  end
  
  test "should duplicate document for user" do
    @document.save!
    other_user = User.create!(
      name: "Other User", 
      email_address: "other2@example.com",
      password: "password123"
    )
    duplicate = @document.duplicate_for(other_user)
    
    assert_equal "#{@document.title} (Copy)", duplicate.title
    assert_equal @document.description, duplicate.description
    assert_equal @document.tags, duplicate.tags
    assert_equal other_user, duplicate.user
    assert_not duplicate.persisted?
    
    # Content should be duplicated
    assert_equal @document.content.to_s, duplicate.content.to_s
  end
  
  test "should provide version info" do
    @document.save!
    info = @document.version_info
    
    assert_equal @document.current_version_number, info[:current_version]
    assert_equal 0, info[:total_versions]
    assert_nil info[:latest_version_created]
    assert_equal @document.created_at, info[:created]
    assert_equal @document.updated_at, info[:updated]
    assert_equal @document.word_count, info[:word_count]
  end
  
  # Additional tests for better coverage
  test "should ensure tags array before save" do
    @document.tags = nil
    @document.save!
    @document.reload
    assert_equal [], @document.tags
  end
  
  # Test all the version-related methods
  test "next_version_number returns incremented version" do
    @document.save!
    assert_equal 1, @document.next_version_number
    
    # Update current_version_number to test increment
    @document.update!(current_version_number: 5)
    assert_equal 6, @document.next_version_number
  end
  
  test "latest_version returns most recent version" do
    @document.save!
    assert_nil @document.latest_version
    
    # Create some versions
    v1 = @document.document_versions.create!(
      version_number: 1,
      created_by_user: @user,
      content_snapshot: "Version 1",
      title: "Title 1",
      word_count: 2
    )
    v2 = @document.document_versions.create!(
      version_number: 2,
      created_by_user: @user,
      content_snapshot: "Version 2",
      title: "Title 2",
      word_count: 2
    )
    
    assert_equal v2, @document.latest_version
  end
  
  test "version_at returns specific version" do
    @document.save!
    v1 = @document.document_versions.create!(
      version_number: 1,
      created_by_user: @user,
      content_snapshot: "Version 1",
      title: "Title 1",
      word_count: 2
    )
    
    assert_equal v1, @document.version_at(1)
    assert_nil @document.version_at(999)
  end
  
  test "create_version delegates to DocumentVersion" do
    @document.save!
    
    # Mock DocumentVersion.create_from_document
    DocumentVersion.expects(:create_from_document).with(@document, @user, {}).returns(true)
    
    @document.create_version(@user)
  end
  
  test "create_auto_version creates automatic version" do
    @document.save!
    
    DocumentVersion.expects(:create_from_document).with(@document, @user, is_auto_version: true).returns(true)
    
    @document.create_auto_version(@user)
  end
  
  test "create_manual_version creates manual version with metadata" do
    @document.save!
    
    expected_options = {
      is_auto_version: false,
      version_name: "Release v1.0",
      version_notes: "First release"
    }
    
    DocumentVersion.expects(:create_from_document).with(@document, @user, expected_options).returns(true)
    
    @document.create_manual_version(@user, version_name: "Release v1.0", version_notes: "First release")
  end
  
  test "content_changed_since_last_version returns true when no versions exist" do
    @document.save!
    assert @document.content_changed_since_last_version?
  end
  
  test "content_changed_since_last_version detects content changes" do
    @document.save!
    
    # Create initial version
    v1 = @document.document_versions.create!(
      version_number: 1,
      created_by_user: @user,
      content_snapshot: @document.content.to_plain_text,
      title: @document.title,
      description_snapshot: @document.description,
      tags_snapshot: @document.tags,
      word_count: @document.word_count
    )
    
    # No changes yet
    assert_not @document.content_changed_since_last_version?
    
    # Change content
    @document.content = "Updated content"
    assert @document.content_changed_since_last_version?
    
    # Reset and change title
    @document.content = v1.content_snapshot
    @document.title = "New Title"
    assert @document.content_changed_since_last_version?
    
    # Reset and change description
    @document.title = v1.title
    @document.description = "New Description"
    assert @document.content_changed_since_last_version?
    
    # Reset and change tags
    @document.description = v1.description_snapshot
    @document.tags = ["new", "tags"]
    assert @document.content_changed_since_last_version?
  end
  
  test "should strip and remove blank tags from tag_list" do
    @document.tag_list = " ruby , , rails , , "
    assert_equal ["ruby", "rails"], @document.tags
  end
  
  test "should handle nil tag_list" do
    @document.tag_list = nil
    assert_equal [], @document.tags
  end
  
  test "should return empty string for tag_list when tags is nil" do
    @document.tags = nil
    assert_equal "", @document.tag_list
  end
  
  test "should handle rich text content association" do
    assert @document.respond_to?(:content)
    @document.save!
    assert @document.content.is_a?(ActionText::RichText)
  end
  
  test "should handle removing non-existent tag" do
    @document.tags = ["ruby", "rails"]
    @document.remove_tag("javascript")
    assert_equal ["ruby", "rails"], @document.tags
  end
  
  test "should handle adding tag when tags is nil" do
    @document.tags = nil
    @document.add_tag("ruby")
    assert_equal ["ruby"], @document.tags
  end
  
  test "should calculate reading time with minimum of 1 minute" do
    @document.content = "Short content"
    assert_equal 1, @document.reading_time
  end
  
  test "should handle excerpt for content shorter than limit" do
    @document.content = "Short content"
    excerpt = @document.excerpt(100)
    assert_equal "Short content", excerpt
    assert_not excerpt.ends_with?("...")
  end
  
  # Tests for new versioning functionality
  test "should have document_versions association" do
    assert @document.respond_to?(:document_versions)
    @document.save!
    assert_equal [], @document.document_versions.to_a
  end
  
  test "should calculate next_version_number" do
    @document.current_version_number = 0
    assert_equal 1, @document.next_version_number
    
    @document.current_version_number = 5
    assert_equal 6, @document.next_version_number
    
    @document.current_version_number = nil
    assert_equal 1, @document.next_version_number
  end
  
  test "should get latest_version" do
    @document.save!
    assert_nil @document.latest_version
    
    version = @document.create_version(@user, version_name: "Test Version")
    assert_equal version, @document.latest_version
  end
  
  test "should get version_at specific number" do
    @document.save!
    version = @document.create_version(@user, version_name: "Test Version")
    
    assert_equal version, @document.version_at(1)
    assert_nil @document.version_at(2)
  end
  
  test "should create version" do
    @document.save!
    @document.update(current_version_number: 0)
    
    version = @document.create_version(@user, {
      version_name: "Test Version",
      version_notes: "Test notes",
      is_auto_version: false
    })
    
    assert version.persisted?
    assert_equal 1, version.version_number
    assert_equal @document.title, version.title
    assert_equal @document.content.to_plain_text, version.content_snapshot
    assert_equal "Test Version", version.version_name
    assert_equal "Test notes", version.version_notes
    assert_equal false, version.is_auto_version
    assert_equal 1, @document.reload.current_version_number
  end
  
  test "should create auto version" do
    @document.save!
    @document.update(current_version_number: 0)
    
    version = @document.create_auto_version(@user)
    
    assert version.persisted?
    assert_equal true, version.is_auto_version
    assert_nil version.version_name
    assert_nil version.version_notes
  end
  
  test "should create manual version" do
    @document.save!
    @document.update(current_version_number: 0)
    
    version = @document.create_manual_version(@user, 
      version_name: "Manual Version", 
      version_notes: "Manual notes"
    )
    
    assert version.persisted?
    assert_equal false, version.is_auto_version
    assert_equal "Manual Version", version.version_name
    assert_equal "Manual notes", version.version_notes
  end
  
  test "should detect content_changed_since_last_version" do
    @document.save!
    
    # No versions yet, should return true
    assert @document.content_changed_since_last_version?
    
    # Create a version
    @document.create_version(@user)
    
    # Content hasn't changed, should return false
    assert_not @document.content_changed_since_last_version?
    
    # Change content
    @document.update(content: "Updated content")
    assert @document.content_changed_since_last_version?
    
    # Change title
    @document.update(content: @document.latest_version.content_snapshot, title: "Updated Title")
    assert @document.content_changed_since_last_version?
    
    # Change description
    @document.update(title: @document.latest_version.title, description: "Updated description")
    assert @document.content_changed_since_last_version?
    
    # Change tags
    @document.update(description: @document.latest_version.description_snapshot, tags: ["new", "tags"])
    assert @document.content_changed_since_last_version?
  end
  
  test "should provide updated version_info" do
    @document.save!
    
    # Create a version
    version = @document.create_version(@user)
    
    info = @document.version_info
    
    assert_equal @document.current_version_number, info[:current_version]
    assert_equal 1, info[:total_versions]
    assert_equal version.created_at, info[:latest_version_created]
    assert_equal @document.created_at, info[:created]
    assert_equal @document.updated_at, info[:updated]
    assert_equal @document.word_count, info[:word_count]
  end
end