class AddContractToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_reference :companies, :contract, foreign_key: true, index: true
  end
end
