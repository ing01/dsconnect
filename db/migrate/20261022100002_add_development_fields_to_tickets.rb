# `sprint_id` nulo = Backlog (ou ticket de uma Mesa sem o modulo de
# desenvolvimento, que nunca tera esta coluna preenchida).
class AddDevelopmentFieldsToTickets < ActiveRecord::Migration[7.1]
  def change
    add_reference :tickets, :sprint, foreign_key: true
    add_column :tickets, :development_type, :integer # nullable: bug/task
  end
end
