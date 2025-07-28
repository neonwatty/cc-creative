class CreateCloudFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :cloud_files do |t|
      t.references :cloud_integration, null: false, foreign_key: true
      t.string :provider
      t.string :file_id
      t.string :name
      t.string :mime_type
      t.integer :size
      t.text :metadata
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end
