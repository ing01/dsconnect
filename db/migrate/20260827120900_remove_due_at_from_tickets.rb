# O prazo unico do ticket virou o relogio de Solucao, com estado proprio ao lado
# dos de Atendimento e Estagio (vide MigrateTicketDueAtToResolutionSla, que rodou
# antes desta e copiou cada data). Manter a coluna deixaria dois prazos
# concorrentes na tela, que e exatamente o que os tres relogios vieram desfazer.
class RemoveDueAtFromTickets < ActiveRecord::Migration[7.0]
  def change
    remove_column :tickets, :due_at, :datetime
  end
end
