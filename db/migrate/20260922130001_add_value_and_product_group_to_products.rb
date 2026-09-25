class AddValueAndProductGroupToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :value, :decimal, precision: 12, scale: 2
    # Opcional nesta migration de proposito - a seguinte (backfill) preenche
    # todo produto existente com um grupo padrao antes da que torna a coluna
    # obrigatoria (`change_product_group_id_to_not_null_on_products`).
    add_reference :products, :product_group, foreign_key: true, index: true
  end
end
