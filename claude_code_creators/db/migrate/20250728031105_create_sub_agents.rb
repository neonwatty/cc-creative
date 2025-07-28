class CreateSubAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_agents do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :agent_type, null: false
      t.string :status, default: 'pending'
      t.string :external_id
      t.json :metadata, default: {}
      
      t.timestamps
    end
    
    # Add indexes for performance
    add_index :sub_agents, :agent_type
    add_index :sub_agents, :status
    add_index :sub_agents, :external_id
    add_index :sub_agents, [:document_id, :user_id]
    add_index :sub_agents, [:document_id, :agent_type]
    add_index :sub_agents, :created_at
  end
end
