class AddFiscalFieldsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :legal_name, :string
    add_column :companies, :cnpj, :string
    add_column :companies, :ie, :string
    add_column :companies, :im, :string
    add_column :companies, :address_zip_code, :string
    add_column :companies, :address_street, :string
    add_column :companies, :address_number, :string
    add_column :companies, :address_complement, :string
    add_column :companies, :address_neighborhood, :string
    add_column :companies, :address_city, :string
    add_column :companies, :address_state, :string

    add_index :companies, [:account_id, :cnpj], unique: true, where: 'cnpj IS NOT NULL', name: 'index_companies_on_account_and_cnpj'
  end
end
