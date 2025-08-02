class CreatePluginInstallations < ActiveRecord::Migration[8.0]
  def change
    create_table :plugin_installations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plugin, null: false, foreign_key: true
      t.json :configuration
      t.string :status
      t.datetime :installed_at
      t.datetime :last_used_at

      t.timestamps
    end
  end
end
