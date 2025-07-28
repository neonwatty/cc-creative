class AddContextAndSystemPromptToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agents, :context, :json, default: {}
    add_column :sub_agents, :system_prompt, :text
    
    # Also update the status column to have the correct default
    change_column_default :sub_agents, :status, from: 'pending', to: 'active'
  end
end
