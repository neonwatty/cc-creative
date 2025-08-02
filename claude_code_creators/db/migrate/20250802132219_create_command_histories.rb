class CreateCommandHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :command_histories do |t|
      t.string :command, null: false
      t.text :parameters
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.datetime :executed_at, null: false
      t.decimal :execution_time, precision: 8, scale: 4
      t.string :status, null: false
      t.text :result_data
      t.text :error_message

      t.timestamps
    end

    add_index :command_histories, [:user_id, :executed_at]
    add_index :command_histories, [:document_id, :executed_at]
    add_index :command_histories, [:command, :status]
  end
end
