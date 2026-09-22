class AddProductGroupToContractProducts < ActiveRecord::Migration[7.2]
  def change
    add_reference :contract_products, :product_group, foreign_key: true, index: true
  end
end
