class CreateClaudeSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :claude_sessions do |t|
      t.string :session_id
      t.json :context
      t.json :metadata

      t.timestamps
    end
    add_index :claude_sessions, :session_id, unique: true
  end
end
