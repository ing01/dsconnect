class CreateContractProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :contract_products do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :unit_value, precision: 12, scale: 2, null: false, default: 0
      t.integer :licenses_qty, null: false, default: 1
      t.decimal :implementation_fee, precision: 12, scale: 2

      t.timestamps
    end
  end
end
