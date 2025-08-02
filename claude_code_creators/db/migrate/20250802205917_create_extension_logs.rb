class CreateExtensionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :extension_logs do |t|
      t.references :plugin, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.string :status
      t.text :error_message
      t.integer :execution_time
      t.json :resource_usage

      t.timestamps
    end
  end
end
