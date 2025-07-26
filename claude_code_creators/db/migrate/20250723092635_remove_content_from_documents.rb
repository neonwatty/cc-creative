class RemoveContentFromDocuments < ActiveRecord::Migration[8.0]
  def change
    remove_column :documents, :content, :text
  end
end
