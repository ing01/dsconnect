# A proposta passa de "uma descricao e um valor" para um resumo mais uma lista de
# itens (titulo, descricao e valor de cada um), como no modelo comercial da
# Duesoft. `amount` continua existindo, agora como o TOTAL dos itens.
class AddSummaryAndItemsToTicketProposals < ActiveRecord::Migration[7.2]
  def up
    add_column :ticket_proposals, :summary, :string
    add_column :ticket_proposals, :items, :jsonb, null: false, default: []

    # Propostas ja criadas viram uma proposta de um item so, sem perder o texto.
    execute <<~SQL.squish
      UPDATE ticket_proposals
      SET summary = tickets.title,
          items = jsonb_build_array(jsonb_build_object(
            'title', CONCAT(tickets.display_id, ' - ', tickets.title),
            'description', ticket_proposals.description,
            'amount', ticket_proposals.amount::text))
      FROM tickets
      WHERE tickets.id = ticket_proposals.ticket_id
    SQL

    remove_column :ticket_proposals, :description
  end

  def down
    add_column :ticket_proposals, :description, :text
    execute "UPDATE ticket_proposals SET description = COALESCE(items -> 0 ->> 'description', '')"
    change_column_null :ticket_proposals, :description, false

    remove_column :ticket_proposals, :items
    remove_column :ticket_proposals, :summary
  end
end
