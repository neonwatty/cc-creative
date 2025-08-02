class CreateDocumentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :document_versions do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :title, null: false
      t.text :content_snapshot, null: false
      t.text :description_snapshot
      t.json :tags_snapshot, default: []
      t.string :version_name
      t.text :version_notes
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.boolean :is_auto_version, default: false, null: false
      t.integer :word_count, default: 0

      t.timestamps
    end

    add_index :document_versions, [ :document_id, :version_number ], unique: true
    add_index :document_versions, [ :document_id, :created_at ]
    add_index :document_versions, :is_auto_version
  end
end
