# Create test data
user = User.first
if user
  document = Document.new(
    title: "Test Document",
    description: "Document for testing drag and drop",
    user: user
  )
  document.content = "This is the initial content of the test document. You can drag and drop context items here."
  document.save!
  
  puts "Created document: #{document.title}"
  
  # Now create context items
  load Rails.root.join('db/seeds/context_items.rb')
end