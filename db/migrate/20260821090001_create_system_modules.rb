class CreateSystemModules < ActiveRecord::Migration[7.1]
  def change
    create_table :system_modules do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :system_modules, [:account_id, :name], unique: true

    create_table :company_system_modules do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.references :system_module, null: false, foreign_key: true, index: true

      t.timestamps
    end
    add_index :company_system_modules, [:company_id, :system_module_id], unique: true, name: 'index_company_system_modules_on_company_and_module'
  end
end
