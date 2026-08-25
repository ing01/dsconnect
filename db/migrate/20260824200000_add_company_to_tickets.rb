class AddCompanyToTickets < ActiveRecord::Migration[7.2]
  def up
    add_reference :tickets, :company, null: true, foreign_key: true, index: true

    backfill_company_from_linked_conversations
  end

  def down
    remove_reference :tickets, :company, foreign_key: true
  end

  private

  # Until now a ticket only knew its Empresa through whichever Conversation was
  # linked to it (ticket_conversations -> conversations -> contacts -> companies),
  # which is also what Company#tickets and the Busca detalhada filters relied on.
  # Seeding the new column from that same path keeps every existing ticket showing
  # the Empresa it already showed.
  #
  # DISTINCT ON picks the earliest linked conversation, matching the "first
  # conversation" convention the serializer used.
  def backfill_company_from_linked_conversations
    execute(<<~SQL.squish)
      UPDATE tickets
      SET company_id = earliest_link.company_id
      FROM (
        SELECT DISTINCT ON (ticket_conversations.ticket_id)
               ticket_conversations.ticket_id,
               contacts.company_id
        FROM ticket_conversations
        JOIN conversations ON conversations.id = ticket_conversations.conversation_id
        JOIN contacts ON contacts.id = conversations.contact_id
        WHERE contacts.company_id IS NOT NULL
        ORDER BY ticket_conversations.ticket_id, ticket_conversations.id
      ) AS earliest_link
      WHERE tickets.id = earliest_link.ticket_id
    SQL
  end
end
