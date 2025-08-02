class CreatePerformanceLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_logs do |t|
      t.string :operation, null: false
      t.float :duration_ms, null: false
      t.json :metadata
      t.string :environment, null: false
      t.string :request_id
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :performance_logs, :occurred_at
    add_index :performance_logs, :operation
    add_index :performance_logs, :duration_ms
    add_index :performance_logs, :environment
    add_index :performance_logs, [ :operation, :occurred_at ]
    add_index :performance_logs, [ :duration_ms, :occurred_at ]
  end
end
