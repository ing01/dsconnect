class CreateTicketTimeEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_time_entries do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :ticket, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :category, null: false, default: 'implantacao'
      t.decimal :hours, precision: 6, scale: 2, null: false
      t.date :worked_on, null: false
      t.text :note

      t.timestamps
    end
  end
end
