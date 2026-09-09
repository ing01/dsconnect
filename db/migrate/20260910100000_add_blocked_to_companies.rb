class AddBlockedToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_column :companies, :blocked, :boolean, null: false, default: false
    add_index :companies, :blocked
  end
end
