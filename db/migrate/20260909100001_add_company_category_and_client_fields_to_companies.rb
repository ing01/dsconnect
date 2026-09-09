class AddCompanyCategoryAndClientFieldsToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_reference :companies, :company_category, foreign_key: true, index: true
    add_column :companies, :client_level, :integer, default: 0, null: false
    add_column :companies, :campaign_opt_in, :boolean, default: false, null: false
  end
end
