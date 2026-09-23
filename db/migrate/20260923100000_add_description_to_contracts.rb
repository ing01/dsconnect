class AddDescriptionToContracts < ActiveRecord::Migration[7.2]
  def change
    add_column :contracts, :description, :string
  end
end
