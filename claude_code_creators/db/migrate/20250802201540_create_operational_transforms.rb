class CreateOperationalTransforms < ActiveRecord::Migration[8.0]
  def change
    create_table :operational_transforms do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :operation_type, null: false
      t.integer :position, null: false
      t.integer :length
      t.text :content
      t.decimal :timestamp, precision: 15, scale: 6, null: false
      t.datetime :applied_at
      t.string :status, null: false, default: "pending"
      t.boolean :conflict_resolved, default: false
      t.text :conflict_resolution_data
      t.string :operation_id

      t.timestamps
    end
    add_index :operational_transforms, [:document_id, :timestamp]
    add_index :operational_transforms, [:user_id, :timestamp]
    add_index :operational_transforms, :operation_id, unique: true
    add_index :operational_transforms, [:document_id, :status]
  end
end
