class CreateProductGroups < ActiveRecord::Migration[7.2]
  def change
    create_table :product_groups do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :total_value_mode, null: false, default: 'auto'
      t.decimal :total_value, precision: 12, scale: 2

      t.timestamps
    end

    add_index :product_groups, %i[account_id name], unique: true
  end
end
