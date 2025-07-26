class CreateClaudeMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :claude_messages do |t|
      t.string :session_id
      t.string :sub_agent_name
      t.string :role
      t.text :content
      t.json :context
      t.json :message_metadata

      t.timestamps
    end
    
    add_index :claude_messages, :session_id
    add_index :claude_messages, :sub_agent_name
    add_index :claude_messages, [:session_id, :created_at]
  end
end
