class RemoveLicenseExpiresOnFromCompanies < ActiveRecord::Migration[7.2]
  def change
    remove_column :companies, :license_expires_on, :date
  end
end
