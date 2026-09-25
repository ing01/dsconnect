class AddSignedOnToContracts < ActiveRecord::Migration[7.2]
  def change
    add_column :contracts, :signed_on, :date
  end
end
