class CreateCompanyCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :company_credentials do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :company, null: false, foreign_key: true, index: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }

      t.string :label

      t.string :db_type
      t.string :db_name
      t.string :db_host
      t.integer :db_port
      t.string :db_username
      t.text :db_password

      t.string :anydesk_id
      t.text :anydesk_password

      t.string :rdp_address
      t.string :rdp_username
      t.text :rdp_password

      t.text :notes

      t.timestamps
    end
  end
end
