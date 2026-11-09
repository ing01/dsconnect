class CreateCompanyNiches < ActiveRecord::Migration[7.2]
  def change
    create_table :company_niches do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :company_niches, %i[account_id name], unique: true
  end
end
