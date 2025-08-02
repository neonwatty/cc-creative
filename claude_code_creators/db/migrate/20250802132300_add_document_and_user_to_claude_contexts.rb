class AddDocumentAndUserToClaudeContexts < ActiveRecord::Migration[8.0]
  def change
    add_reference :claude_contexts, :document, null: true, foreign_key: true
    add_reference :claude_contexts, :user, null: true, foreign_key: true
    add_column :claude_contexts, :context_data, :text

    add_index :claude_contexts, [ :document_id, :user_id ]
    add_index :claude_contexts, [ :user_id, :created_at ]
  end
end
