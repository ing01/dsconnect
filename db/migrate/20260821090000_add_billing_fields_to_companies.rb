class AddBillingFieldsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :billing_type, :string
    add_column :companies, :billing_amount, :decimal, precision: 12, scale: 2
    add_column :companies, :implementation_fee, :decimal, precision: 12, scale: 2
    add_column :companies, :license_expires_on, :date
    add_column :companies, :system_started_on, :date
  end
end
