class AddManagerIdAndActiveToTeams < ActiveRecord::Migration[7.2]
  def change
    add_column :teams, :active, :boolean, default: true, null: false
    add_reference :teams, :manager, foreign_key: { to_table: :users }, index: true
  end
end
