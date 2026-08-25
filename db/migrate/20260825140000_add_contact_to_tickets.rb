class AddContactToTickets < ActiveRecord::Migration[7.2]
  def up
    # The Solicitante had no FK: it was derived from the earliest linked
    # Conversation's contact, which made it unchangeable on its own. Nullable
    # because a ticket can be opened before the requester is identified.
    add_reference :tickets, :contact, foreign_key: { on_delete: :nullify }, null: true

    # Backfill from the path the value used to come from, so existing tickets
    # keep the requester they already showed.
    execute <<~SQL.squish
      UPDATE tickets SET contact_id = source.contact_id
      FROM (
        SELECT DISTINCT ON (ticket_conversations.ticket_id)
               ticket_conversations.ticket_id, conversations.contact_id
        FROM ticket_conversations
        JOIN conversations ON conversations.id = ticket_conversations.conversation_id
        WHERE conversations.contact_id IS NOT NULL
        ORDER BY ticket_conversations.ticket_id, conversations.id
      ) AS source
      WHERE tickets.id = source.ticket_id
    SQL
  end

  def down
    remove_reference :tickets, :contact
  end
end
