class CreatePlugins < ActiveRecord::Migration[8.0]
  def change
    create_table :plugins do |t|
      t.string :name
      t.string :version
      t.text :description
      t.string :author
      t.string :category
      t.string :status
      t.json :metadata
      t.json :permissions
      t.json :sandbox_config
      t.datetime :installed_at

      t.timestamps
    end
  end
end
