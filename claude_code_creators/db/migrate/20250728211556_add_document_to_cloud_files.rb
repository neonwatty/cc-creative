class AddDocumentToCloudFiles < ActiveRecord::Migration[8.0]
  def change
    add_reference :cloud_files, :document, null: true, foreign_key: true
  end
end
