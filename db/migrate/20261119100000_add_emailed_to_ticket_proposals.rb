# O registro de que a proposta foi enviada por e-mail ao cliente (quando e para qual endereco),
# para a tela mostrar e ninguem precisar adivinhar se o e-mail saiu.
class AddEmailedToTicketProposals < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_proposals, :emailed_at, :datetime
    add_column :ticket_proposals, :emailed_to, :string
  end
end
