class ChangeProductGroupIdToNotNullOnProducts < ActiveRecord::Migration[7.2]
  def change
    change_column_null :products, :product_group_id, false
  end
end
