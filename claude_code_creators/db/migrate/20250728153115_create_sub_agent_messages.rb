class CreateSubAgentMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_agent_messages do |t|
      t.references :sub_agent, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role
      t.text :content

      t.timestamps
    end
  end
end
