# Triagem dos chamados abertos pelo cliente.
#
# O cliente informa o problema, nao para onde ele vai: Mesa e Estagio sao
# decisao de quem atende. O chamado entra parado numa fila de triagem, e so
# depois de aprovado passa a andar no Kanban da equipe.
class AddTriageToTickets < ActiveRecord::Migration[7.2]
  def change
    # Desligado por padrao: nada que ja existe entra em triagem, e o chamado
    # aberto pelo agente continua nascendo pronto.
    add_column :tickets, :pending_triage, :boolean, default: false, null: false
    add_column :tickets, :triaged_at, :datetime
    add_reference :tickets, :triaged_by, foreign_key: { to_table: :users }, null: true, index: false

    # Parcial: a fila de triagem e curta e a consulta que importa e "o que esta
    # esperando", nunca varrer o resto.
    add_index :tickets, [:account_id, :pending_triage],
              where: 'pending_triage', name: 'index_tickets_on_account_and_pending_triage'
    add_index :tickets, :triaged_by_id, where: 'triaged_by_id IS NOT NULL'
  end
end
