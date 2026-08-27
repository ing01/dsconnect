# The realtime payload a ticket puts on the wire.
#
# Deliberately narrower than the REST serializer: the store MERGES this into
# whatever it already holds rather than replacing, so a ticket arriving over the
# wire never blanks the fields only the detail endpoint sends.
module TicketBroadcastable
  extend ActiveSupport::Concern

  def push_event_data
    core_event_data.merge(lifecycle_event_data).merge(relation_event_data)
  end

  private

  def core_event_data
    {
      id: id, display_id: display_id, title: title, description: description,
      priority: priority, status: status, position: position, account_id: account_id,
      ticket_column_id: ticket_column_id, assignee_id: assignee_id, team_id: team_id,
      # Carried here too, otherwise a ticket arriving over the wire would be
      # invisible to the Kanban's Empresa search until the next board refetch.
      company_id: company_id, company_name: company&.name,
      created_at: created_at.to_i, updated_at: updated_at.to_i,
      conversation_ids: ticket_conversations.pluck(:conversation_id)
    }
  end

  def lifecycle_event_data
    {
      resolved_at: resolved_at&.to_i, closed_at: closed_at&.to_i,
      cancelled_at: cancelled_at&.to_i, close_reason: close_reason
    }
  end

  # So a Kanban card can badge a child or a grouped ticket without refetching.
  #
  # Os tres relogios de SLA viajam junto porque comunicacao enviada, mudanca de
  # estagio, fechamento, vencimento e horas adicionadas precisam refletir sem F5 -
  # e o `due_at` unico que existia aqui nao representava tres estados.
  def relation_event_data
    {
      parent_id: parent_id, merged_into_id: merged_into_id,
      slas: current_slas.map(&:push_event_data)
    }
  end
end
