class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :content
      t.text :description
      t.text :tags
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :documents, :created_at
  end
end
