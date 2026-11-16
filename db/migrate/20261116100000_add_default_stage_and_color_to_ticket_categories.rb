class AddDefaultStageAndColorToTicketCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_categories, :default_ticket_column_id, :bigint
    add_column :ticket_categories, :color, :string
    add_index :ticket_categories, :default_ticket_column_id
    add_foreign_key :ticket_categories, :ticket_columns, column: :default_ticket_column_id
  end
end
