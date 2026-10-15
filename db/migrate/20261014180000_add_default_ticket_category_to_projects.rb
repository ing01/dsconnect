class AddDefaultTicketCategoryToProjects < ActiveRecord::Migration[7.2]
  def change
    add_reference :projects, :default_ticket_category, foreign_key: { to_table: :ticket_categories }, index: true
  end
end
