class AddPositionToContextItems < ActiveRecord::Migration[8.0]
  def change
    add_column :context_items, :position, :integer
    add_index :context_items, [ :document_id, :item_type, :position ]
  end
end
