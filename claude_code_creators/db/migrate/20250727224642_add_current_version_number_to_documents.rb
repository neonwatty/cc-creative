class AddCurrentVersionNumberToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :current_version_number, :integer, default: 0
    add_index :documents, :current_version_number
  end
end
