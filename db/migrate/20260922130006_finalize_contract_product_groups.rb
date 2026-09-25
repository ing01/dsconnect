class FinalizeContractProductGroups < ActiveRecord::Migration[7.2]
  def change
    remove_reference :contract_products, :product, foreign_key: true, index: true
    change_column_null :contract_products, :product_group_id, false
    rename_table :contract_products, :contract_product_groups
  end
end
