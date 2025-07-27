class AddFullTextSearchToContextItems < ActiveRecord::Migration[8.0]
  def up
    # SQLite doesn't support tsvector, so we'll add a text column for search content
    add_column :context_items, :search_content, :text
    
    # Create an index for better search performance
    add_index :context_items, :search_content
    
    # Update existing records to populate search_content
    ContextItem.reset_column_information
    ContextItem.find_each do |item|
      item.update_column(:search_content, "#{item.title} #{item.content} #{item.item_type}".downcase)
    end
  end
  
  def down
    # Remove index
    remove_index :context_items, :search_content
    
    # Remove column
    remove_column :context_items, :search_content
  end
end
