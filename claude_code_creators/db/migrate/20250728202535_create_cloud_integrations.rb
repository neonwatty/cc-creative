class CreateCloudIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :cloud_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.text :settings

      t.timestamps
    end
  end
end
