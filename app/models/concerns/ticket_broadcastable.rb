# The realtime payload a ticket puts on the wire.
#
# Deliberately narrower than the REST serializer: the store MERGES this into
# whatever it already holds rather than replacing, so a ticket arriving over the
# wire never blanks the fields only the detail endpoint sends.
module TicketBroadcastable
  extend ActiveSupport::Concern
  # Os nomes dos eventos (TICKET_UPDATED e companhia) vem daqui. Sem este
  # include eles so resolviam dentro do Ticket, e os metodos de despacho
  # deixaram de enxerga-los ao mudar de arquivo.
  include Events::Types

  def push_event_data
    core_event_data.merge(display_event_data).merge(lifecycle_event_data).merge(relation_event_data)
  end

  private

  # Qual evento cada mudanca produz. Fica aqui, e nao no model, porque e a mesma
  # responsabilidade do payload acima: o que este ticket poe no ar.

  def dispatch_ticket_created_event
    dispatcher_dispatch(TICKET_CREATED)
  end

  def dispatch_ticket_updated_event
    dispatcher_dispatch(ticket_update_event_name)
  end

  def ticket_update_event_name
    return TICKET_MOVED if saved_change_to_attribute?('ticket_column_id')
    return status_event_name if saved_change_to_attribute?('status')

    TICKET_UPDATED
  end

  def status_event_name
    case status
    when 'resolved' then TICKET_RESOLVED
    when 'closed' then TICKET_CLOSED
    when 'cancelled' then TICKET_CANCELLED
    else TICKET_REOPENED
    end
  end

  # O ticket ja nao existe, entao o payload e so o que a tela precisa para tirar
  # o card da lista.
  def dispatch_ticket_deleted_event
    Rails.configuration.dispatcher.dispatch(
      TICKET_DELETED, Time.zone.now, ticket: self, ticket_id: id, account_id: account_id
    )
  end

  def dispatcher_dispatch(event_name)
    Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, ticket: self)
  end

  def core_event_data
    {
      id: id, display_id: display_id, title: title, description: description,
      priority: priority, status: status, position: position, account_id: account_id,
      ticket_column_id: ticket_column_id, assignee_id: assignee_id, team_id: team_id,
      # Carried here too, otherwise a ticket arriving over the wire would be
      # invisible to the Kanban's Empresa search until the next board refetch.
      company_id: company_id, contact_id: contact_id,
      ticket_category_id: ticket_category_id,
      # Vai junto para o contador da Triagem no menu lateral saber que a fila
      # mudou sem ter de perguntar ao servidor a cada evento de ticket.
      pending_triage: pending_triage,
      project_id: project_id,
      due_date: due_date&.iso8601, scheduled_at: scheduled_at&.iso8601,
      next_project_stage: next_project_stage,
      created_at: created_at.to_i, updated_at: updated_at.to_i
    }
  end

  # Os nomes viajam junto dos ids. Sem eles a Lista mostra o nome ANTIGO depois
  # de uma troca - o id muda, o nome nao, e a mesclagem preserva o que ja estava
  # -, e um ticket criado por outra pessoa chega sem nome nenhum, porque nao ha
  # registro anterior com que mesclar.
  # Cada nome vem da associacao correspondente. Tabela em vez de sete linhas
  # iguais: acrescentar um nome e uma entrada, e nao mais uma ramificacao.
  NAME_SOURCES = {
    company_name: :company, assignee_name: :assignee, team_name: :team,
    ticket_column_name: :ticket_column, requester_name: :requester_contact,
    ticket_category_name: :ticket_category, project_name: :project
  }.freeze

  def display_event_data
    NAME_SOURCES.transform_values { |association| public_send(association)&.name }
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
      conversation_ids: ticket_conversations.pluck(:conversation_id),
      slas: current_slas.map(&:push_event_data)
    }
  end
end
