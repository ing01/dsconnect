class AddCategoryToTickets < ActiveRecord::Migration[7.2]
  def change
    # Nullable in the database on purpose: every ticket that already exists was
    # opened before categories did, and they must stay editable. The model
    # requires one `on: :create`, so new tickets always carry it.
    add_reference :tickets, :ticket_category, foreign_key: { on_delete: :nullify }, null: true
  end
end
