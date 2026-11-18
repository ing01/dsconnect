class AddChildCompletedToTickets < ActiveRecord::Migration[7.2]
  # Selo "filho concluido" do cartao do Kanban: quando um ticket filho de
  # desenvolvimento e concluido, o PAI guarda quando e qual filho, ate o analista
  # dar o visto. Colunas anulaveis e sem default: nao reescrevem a tabela.
  def change
    add_column :tickets, :child_completed_at, :datetime
    add_column :tickets, :child_completed_display_id, :integer
  end
end
