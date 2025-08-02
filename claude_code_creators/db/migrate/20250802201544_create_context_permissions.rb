class CreateContextPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :context_permissions do |t|
      t.references :context_item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :granted_by, null: false, foreign_key: { to_table: :users }
      t.text :permissions, null: false
      t.datetime :granted_at, null: false
      t.datetime :expires_at
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :context_permissions, [ :context_item_id, :user_id ], unique: true
    add_index :context_permissions, [ :user_id, :status ]
    add_index :context_permissions, :expires_at
  end
end
