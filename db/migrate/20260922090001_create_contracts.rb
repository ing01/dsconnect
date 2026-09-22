class CreateContracts < ActiveRecord::Migration[7.2]
  def change
    create_table :contracts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :responsible_contact, foreign_key: { to_table: :contacts }
      t.string :contract_type
      t.string :total_value_mode, null: false, default: 'auto'
      t.decimal :total_value, precision: 12, scale: 2

      t.timestamps
    end
  end
end
