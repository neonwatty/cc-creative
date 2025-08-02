class CreateClaudeContexts < ActiveRecord::Migration[8.0]
  def change
    create_table :claude_contexts do |t|
      t.string :session_id
      t.string :context_type
      t.json :content
      t.integer :token_count

      t.timestamps
    end

    add_index :claude_contexts, :session_id
    add_index :claude_contexts, :context_type
    add_index :claude_contexts, [ :session_id, :context_type ]
  end
end
