# Permite ocultar qualquer Estagio do quadro Kanban (Configuracoes >
# Estagios) - antes disso, so o Estagio "Finalizado" (kind: completed) ficava
# escondido, de forma fixa e sem opcao de mudar (ver TicketBoard.vue).
class AddHiddenToTicketColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_columns, :hidden, :boolean, default: false, null: false
  end
end
