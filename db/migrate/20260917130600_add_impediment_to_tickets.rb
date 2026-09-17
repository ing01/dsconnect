# Impedimento de ticket: o trabalho parou por algo externo, mas o ticket
# continua aberto.
#
# Tres colunas na propria tabela, e nao uma tabela nova, porque e exatamente o
# formato que o projeto ja usa para os outros estados do ticket - `closed_at`,
# `cancelled_at`, `close_reason` moram aqui do mesmo jeito. Uma tabela separada
# so se justificaria para guardar o HISTORICO de impedimentos, e esse historico
# ja existe: cada colocar/retirar deixa uma TicketActivity e um comentario
# interno.
#
# `blocked_at` presente E o estado impedido. Nao ha booleano ao lado porque dois
# campos para um estado so divergem: basta um update esquecer o outro.
#
# Tickets existentes nascem com as tres colunas nulas, ou seja, nao impedidos -
# nenhum dado precisa ser migrado.
class AddImpedimentToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :blocked_at, :datetime
    add_column :tickets, :blocked_reason, :text
    add_reference :tickets, :blocked_by, foreign_key: { to_table: :users }, null: true, index: false

    # A listagem "Tickets impedidos" filtra por conta + impedidos. O indice
    # parcial cobre so as linhas que interessam, que sao a minoria.
    add_index :tickets, [:account_id, :blocked_at],
              where: 'blocked_at IS NOT NULL',
              name: 'index_tickets_on_account_and_blocked'
    add_index :tickets, :blocked_by_id, where: 'blocked_by_id IS NOT NULL'
  end
end
