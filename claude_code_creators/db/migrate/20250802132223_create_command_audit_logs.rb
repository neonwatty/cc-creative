class CreateCommandAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :command_audit_logs do |t|
      t.string :command, null: false
      t.text :parameters
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.datetime :executed_at, null: false
      t.decimal :execution_time, precision: 8, scale: 4
      t.string :status, null: false
      t.text :error_message
      t.string :ip_address
      t.text :user_agent
      t.string :session_id
      t.text :metadata

      t.timestamps
    end

    add_index :command_audit_logs, [:user_id, :executed_at]
    add_index :command_audit_logs, [:document_id, :executed_at]
    add_index :command_audit_logs, [:command, :status]
    add_index :command_audit_logs, :session_id
  end
end
