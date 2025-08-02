class CreatePluginPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :plugin_permissions do |t|
      t.references :plugin, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :permission_type
      t.string :resource
      t.datetime :granted_at
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
