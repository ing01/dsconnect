class AddRemoteAccessTypeToCompanyCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :company_credentials, :remote_access_type, :string
  end
end
