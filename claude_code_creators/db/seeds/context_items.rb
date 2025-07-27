# Create context items for testing drag and drop
if User.any? && Document.any?
  user = User.first
  document = Document.first
  
  # Create snippets
  5.times do |i|
    ContextItem.create!(
      document: document,
      user: user,
      item_type: 'snippet',
      title: "Code Snippet #{i + 1}",
      content: "```ruby\n# Sample code snippet #{i + 1}\ndef method_#{i + 1}\n  puts 'Hello from snippet #{i + 1}'\nend\n```",
      metadata: { tags: ['ruby', 'code', "snippet#{i + 1}"] }
    )
  end
  
  # Create drafts
  3.times do |i|
    ContextItem.create!(
      document: document,
      user: user,
      item_type: 'draft',
      title: "Draft Version #{i + 1}",
      content: "This is draft content #{i + 1}. Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
      metadata: { tags: ['draft', "version#{i + 1}"] }
    )
  end
  
  # Create versions
  2.times do |i|
    ContextItem.create!(
      document: document,
      user: user,
      item_type: 'version',
      title: "Version #{i + 1}.0",
      content: "Version #{i + 1}.0 of the document. Major changes include updates to the structure and content.",
      metadata: { tags: ['version', 'release'] }
    )
  end
  
  puts "Created #{ContextItem.count} context items"
else
  puts "Skipping context items creation - no users or documents found"
end