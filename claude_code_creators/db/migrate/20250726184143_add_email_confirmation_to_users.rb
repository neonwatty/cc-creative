class AddEmailConfirmationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_confirmed, :boolean, default: false, null: false
    add_column :users, :email_confirmed_at, :datetime
  end
end
