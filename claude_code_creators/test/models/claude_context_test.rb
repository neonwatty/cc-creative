require "test_helper"

class ClaudeContextTest < ActiveSupport::TestCase
  setup do
    @claude_context = claude_contexts(:one)
    @session_id = "test-session-123"
  end

  # Validation tests
  test "should be valid with valid attributes" do
    context = ClaudeContext.new(
      session_id: @session_id,
      context_type: "document",
      content: { text: "Sample content" }
    )
    assert context.valid?
  end

  test "should require session_id" do
    context = ClaudeContext.new(context_type: "document")
    assert_not context.valid?
    assert_includes context.errors[:session_id], "can't be blank"
  end

  test "should require context_type" do
    context = ClaudeContext.new(session_id: @session_id)
    assert_not context.valid?
    assert_includes context.errors[:context_type], "can't be blank"
  end

  test "should validate context_type inclusion" do
    context = ClaudeContext.new(session_id: @session_id, context_type: "invalid_type")
    assert_not context.valid?
    assert_includes context.errors[:context_type], "is not included in the list"
  end

  test "should accept valid context types" do
    ClaudeContext::CONTEXT_TYPES.each do |type|
      context = ClaudeContext.new(session_id: @session_id, context_type: type)
      assert context.valid?, "#{type} should be a valid context type"
    end
  end

  test "should validate token_count is non-negative" do
    context = ClaudeContext.new(session_id: @session_id, context_type: "document", token_count: -1)
    assert_not context.valid?
    assert_includes context.errors[:token_count], "must be greater than or equal to 0"
  end

  test "should allow nil token_count" do
    context = ClaudeContext.new(session_id: @session_id, context_type: "document", token_count: nil)
    assert context.valid?
  end

  # Association tests
  test "belongs to claude_session through session_id" do
    session = ClaudeSession.create!(session_id: @session_id)
    context = ClaudeContext.create!(
      session_id: @session_id,
      context_type: "document",
      content: { text: "Test" }
    )
    assert_equal session, context.claude_session
  end

  test "claude_session association is optional" do
    context = ClaudeContext.create!(
      session_id: "non-existent-session",
      context_type: "document",
      content: { text: "Test" }
    )
    assert_nil context.claude_session
    assert context.persisted?
  end

  # Scope tests
  test "by_session scope filters by session_id" do
    context1 = ClaudeContext.create!(session_id: "session1", context_type: "document")
    context2 = ClaudeContext.create!(session_id: "session2", context_type: "document")
    context3 = ClaudeContext.create!(session_id: "session1", context_type: "code")
    
    results = ClaudeContext.by_session("session1")
    assert_includes results, context1
    assert_includes results, context3
    assert_not_includes results, context2
  end

  test "by_type scope filters by context_type" do
    context1 = ClaudeContext.create!(session_id: @session_id, context_type: "document")
    context2 = ClaudeContext.create!(session_id: @session_id, context_type: "code")
    context3 = ClaudeContext.create!(session_id: @session_id, context_type: "document")
    
    results = ClaudeContext.by_type("document")
    assert_includes results, context1
    assert_includes results, context3
    assert_not_includes results, context2
  end

  test "documents scope returns only document contexts" do
    doc = ClaudeContext.create!(session_id: @session_id, context_type: "document")
    code = ClaudeContext.create!(session_id: @session_id, context_type: "code")
    
    results = ClaudeContext.documents
    assert_includes results, doc
    assert_not_includes results, code
  end

  test "code_contexts scope returns only code contexts" do
    doc = ClaudeContext.create!(session_id: @session_id, context_type: "document")
    code = ClaudeContext.create!(session_id: @session_id, context_type: "code")
    
    results = ClaudeContext.code_contexts
    assert_includes results, code
    assert_not_includes results, doc
  end

  test "recent scope orders by updated_at descending" do
    old = ClaudeContext.create!(session_id: @session_id, context_type: "document", updated_at: 2.days.ago)
    new = ClaudeContext.create!(session_id: @session_id, context_type: "document", updated_at: 1.hour.ago)
    middle = ClaudeContext.create!(session_id: @session_id, context_type: "document", updated_at: 1.day.ago)
    
    results = ClaudeContext.recent.to_a
    assert_equal [new, middle, old], results.select { |c| [new, middle, old].include?(c) }
  end

  # Class method tests
  test "total_tokens_for_session sums token counts" do
    # Create contexts with content so token counts are calculated
    ClaudeContext.create!(session_id: @session_id, context_type: "document", content: { text: "a" * 400 })
    ClaudeContext.create!(session_id: @session_id, context_type: "code", content: { text: "b" * 800 })
    ClaudeContext.create!(session_id: "other", context_type: "document", content: { text: "c" * 1200 })
    
    # Token counts are calculated automatically based on content
    total = ClaudeContext.total_tokens_for_session(@session_id)
    assert total > 0, "Expected total tokens to be greater than 0"
    
    # Should not include the "other" session's tokens
    other_total = ClaudeContext.total_tokens_for_session("other")
    assert_not_equal total, other_total
  end

  test "compress_context removes oldest contexts when over limit" do
    # Create contexts with content that will generate token counts
    oldest = ClaudeContext.create!(
      session_id: @session_id, 
      context_type: "reference", 
      content: { text: "a" * 120000 }, # ~30000 tokens
      updated_at: 2.days.ago
    )
    middle = ClaudeContext.create!(
      session_id: @session_id, 
      context_type: "code", 
      content: { text: "b" * 80000 }, # ~20000 tokens
      updated_at: 1.day.ago
    )
    newest = ClaudeContext.create!(
      session_id: @session_id, 
      context_type: "document", 
      content: { text: "c" * 40000 }, # ~10000 tokens
      updated_at: 1.hour.ago
    )
    
    # Force token calculation
    oldest.reload
    middle.reload
    newest.reload
    
    # Total should be around 60000, compress to 35000
    ClaudeContext.compress_context(@session_id, max_tokens: 35000)
    
    # Oldest should be removed
    assert_not ClaudeContext.exists?(oldest.id)
    assert ClaudeContext.exists?(middle.id)
    assert ClaudeContext.exists?(newest.id)
  end

  test "compress_context does nothing when under limit" do
    context1 = ClaudeContext.create!(session_id: @session_id, context_type: "document", token_count: 100)
    context2 = ClaudeContext.create!(session_id: @session_id, context_type: "code", token_count: 200)
    
    ClaudeContext.compress_context(@session_id, max_tokens: 1000)
    
    assert ClaudeContext.exists?(context1.id)
    assert ClaudeContext.exists?(context2.id)
  end

  # Instance method tests
  test "document? returns true for document type" do
    context = ClaudeContext.new(context_type: "document")
    assert context.document?
    
    context.context_type = "code"
    assert_not context.document?
  end

  test "code? returns true for code type" do
    context = ClaudeContext.new(context_type: "code")
    assert context.code?
    
    context.context_type = "document"
    assert_not context.code?
  end

  test "add_content adds key-value pairs to content" do
    context = ClaudeContext.create!(session_id: @session_id, context_type: "document")
    
    context.add_content("title", "My Document")
    context.add_content("body", "Document content")
    
    assert_equal "My Document", context.content["title"]
    assert_equal "Document content", context.content["body"]
  end

  test "remove_content removes key from content" do
    context = ClaudeContext.create!(
      session_id: @session_id, 
      context_type: "document",
      content: { "title" => "My Document", "body" => "Content" }
    )
    
    context.remove_content("title")
    
    assert_nil context.content["title"]
    assert_equal "Content", context.content["body"]
  end

  test "estimated_tokens calculates based on content size" do
    context = ClaudeContext.new(content: { text: "a" * 400 })
    # JSON will add some overhead, but roughly 400 chars / 4 = 100 tokens
    assert_in_delta 100, context.estimated_tokens, 20
  end

  test "estimated_tokens returns 0 for blank content" do
    context = ClaudeContext.new(content: nil)
    assert_equal 0, context.estimated_tokens
    
    context.content = {}
    assert_equal 0, context.estimated_tokens
  end

  # Callback tests
  test "sets default values after initialize" do
    context = ClaudeContext.new
    assert_equal({}, context.content)
    assert_equal 0, context.token_count
  end

  test "calculates tokens before save" do
    context = ClaudeContext.new(
      session_id: @session_id,
      context_type: "document",
      content: { text: "a" * 400 }
    )
    
    assert_equal 0, context.token_count
    context.save!
    assert context.token_count > 0
  end

  test "updates token count when content changes" do
    context = ClaudeContext.create!(
      session_id: @session_id,
      context_type: "document",
      content: { text: "short" }
    )
    
    initial_tokens = context.token_count
    
    context.content = { text: "a" * 1000 }
    context.save!
    
    assert context.token_count > initial_tokens
  end
end