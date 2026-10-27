# Uma proposta pode valer para mais de um ticket: ela aparece na aba Valorizacao
# de todos os tickets vinculados e no portal do cliente de cada um.
#
# `ticket_proposals.ticket_id` continua existindo como o ticket onde a proposta
# foi criada; esta tabela e quem diz a quais tickets ela pertence (o de origem
# inclusive).
class CreateTicketProposalLinks < ActiveRecord::Migration[7.2]
  def up
    create_table :ticket_proposal_links do |t|
      t.references :ticket_proposal, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.timestamps
    end
    add_index :ticket_proposal_links, [:ticket_proposal_id, :ticket_id], unique: true, name: 'index_ticket_proposal_links_uniqueness'

    # As propostas que ja existem ficam vinculadas ao ticket em que foram criadas.
    execute <<~SQL.squish
      INSERT INTO ticket_proposal_links (ticket_proposal_id, ticket_id, created_at, updated_at)
      SELECT id, ticket_id, NOW(), NOW() FROM ticket_proposals
    SQL
  end

  def down
    drop_table :ticket_proposal_links
  end
end
