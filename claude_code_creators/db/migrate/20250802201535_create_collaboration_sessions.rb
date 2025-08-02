class CreateCollaborationSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :collaboration_sessions do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, comment: "Session owner"
      t.string :session_id, null: false
      t.string :status, null: false, default: "active"
      t.text :settings
      t.integer :max_users, default: 10
      t.integer :active_users_count, default: 0
      t.datetime :started_at, null: false
      t.datetime :expires_at

      t.timestamps
    end
    add_index :collaboration_sessions, :session_id, unique: true
    add_index :collaboration_sessions, [:document_id, :status]
    add_index :collaboration_sessions, :started_at
  end
end
