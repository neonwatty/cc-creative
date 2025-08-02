class CreateWorkflowTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_tasks do |t|
      t.references :document, null: false, foreign_key: true
      t.references :assigned_to, null: false, foreign_key: { to_table: :users }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.string :priority, null: false, default: "medium"
      t.string :status, null: false, default: "pending"
      t.string :category
      t.decimal :estimated_hours, precision: 8, scale: 2
      t.decimal :time_spent, precision: 8, scale: 2, default: 0
      t.integer :progress_percentage, default: 0
      t.datetime :due_date
      t.datetime :completed_at
      t.text :acceptance_criteria
      t.text :tags
      t.string :git_branch
      t.text :dependencies

      t.timestamps
    end
    add_index :workflow_tasks, [:document_id, :status]
    add_index :workflow_tasks, [:assigned_to_id, :status]
    add_index :workflow_tasks, [:created_by_id, :created_at]
    add_index :workflow_tasks, :due_date
    add_index :workflow_tasks, :priority
  end
end
