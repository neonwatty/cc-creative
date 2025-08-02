class CreateErrorLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :error_logs do |t|
      t.string :error_class, null: false
      t.text :message, null: false
      t.text :backtrace
      t.json :context
      t.string :environment, null: false
      t.string :request_id
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :error_logs, :occurred_at
    add_index :error_logs, :error_class
    add_index :error_logs, :environment
    add_index :error_logs, :request_id
    add_index :error_logs, [ :error_class, :occurred_at ]
    add_index :error_logs, [ :environment, :occurred_at ]
  end
end
