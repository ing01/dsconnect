class AddObservationToTickets < ActiveRecord::Migration[7.2]
  # Observacao livre do ticket (qualquer Mesa), escrita como a descricao. Coluna
  # anulavel e sem default: nao reescreve a tabela.
  def change
    add_column :tickets, :observation, :text
  end
end
