class TicketActivity < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  belongs_to :user, optional: true

  enum activity_type: {
    created: 0,
    status_changed: 1,
    column_changed: 2,
    priority_changed: 3,
    assignee_changed: 4,
    team_changed: 5,
    comment_added: 6,
    resolved: 7,
    reopened: 8,
    closed: 9,
    conversation_linked: 10,
    conversation_unlinked: 11,
    # Composite operations from the "Acoes do ticket" menu. `transferred`
    # carries every before/after pair in `meta` so one entry stays fully
    # auditable instead of four disconnected ones.
    transferred: 12,
    parent_changed: 13,
    child_created: 14,
    merged_ticket: 15,
    merged_into: 16,
    duplicated: 17,
    sla_hours_added: 18,
    cancelled: 19,
    follower_added: 20,
    follower_removed: 21,
    title_changed: 22,
    company_changed: 23,
    contact_changed: 24,
    classified: 25,
    customer_communication_sent: 26,
    category_changed: 27,
    # Impedimento: o ticket travou por algo externo e continua ABERTO. Nao
    # entra em `status` por isso mesmo - ver TicketBlocking.
    blocked: 28,
    unblocked: 29,
    # Nota livre deixada por uma Automacao de Estagio (TicketColumn#automation_actions,
    # acao `post_note`) - `user` fica nulo de proposito, o autor e a automacao.
    automation_note: 30,
    # Registrado por Tickets::ImportService (Configuracoes > Tickets >
    # Importar) - guarda o numero original e quem criou no sistema anterior,
    # ja que o Ticket nao tem coluna propria pra nenhum dos dois.
    imported: 31
  }

  def push_event_data
    {
      id: id,
      ticket_id: ticket_id,
      activity_type: activity_type,
      previous_value: previous_value,
      new_value: new_value,
      meta: meta,
      user: user ? { id: user.id, name: user.name, email: user.email } : nil,
      created_at: created_at.to_i
    }
  end
end
