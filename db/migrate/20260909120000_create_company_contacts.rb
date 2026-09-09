class CreateCompanyContacts < ActiveRecord::Migration[7.2]
  def up
    create_table :company_contacts do |t|
      t.references :contact, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.timestamps
    end
    add_index :company_contacts, %i[contact_id company_id], unique: true

    # Backfill so every contact's existing (single) company shows up as a
    # membership too - the join table is now the source of truth for "which
    # companies", contacts.company_id stays only as the backward-compatible
    # primary/first one.
    execute <<~SQL.squish
      INSERT INTO company_contacts (contact_id, company_id, created_at, updated_at)
      SELECT id, company_id, NOW(), NOW() FROM contacts WHERE company_id IS NOT NULL
    SQL
  end

  def down
    drop_table :company_contacts
  end
end
