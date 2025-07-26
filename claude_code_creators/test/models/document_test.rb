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
    
    assert info[:version].present?
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
end