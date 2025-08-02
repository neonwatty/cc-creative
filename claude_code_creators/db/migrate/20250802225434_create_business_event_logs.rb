class CreateBusinessEventLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :business_event_logs do |t|
      t.string :event_name, null: false
      t.json :event_data
      t.string :environment, null: false
      t.string :request_id
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :business_event_logs, :occurred_at
    add_index :business_event_logs, :event_name
    add_index :business_event_logs, :environment
    add_index :business_event_logs, [ :event_name, :occurred_at ]
    add_index :business_event_logs, [ :environment, :occurred_at ]
  end
end
