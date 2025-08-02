class CreateContextItems < ActiveRecord::Migration[8.0]
  def change
    create_table :context_items do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.string :item_type
      t.string :title
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :context_items, :item_type
    add_index :context_items, [ :document_id, :user_id ]
    add_index :context_items, :created_at
  end
end
