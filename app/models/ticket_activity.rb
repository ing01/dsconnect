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
    imported: 31,
    # Chamado aberto pelo cliente, aprovado na triagem e encaminhado.
    #
    # 32, e nao 30: os dois lados deste merge reivindicaram o 30, e o numero
    # fica GRAVADO na linha. Quem cedeu foi a triagem, porque `automation_note`
    # e `imported` ja rodaram em producao e tem linhas com 30 e 31; a triagem so
    # existia em banco de desenvolvimento, onde o remanejamento e uma linha de
    # UPDATE.
    triaged: 32,
    # Campos que ate aqui mudavam sem deixar rastro. Numeros novos no fim: o
    # valor fica GRAVADO na linha, nunca se renumera o que ja existe.
    due_date_changed: 33,
    scheduled_at_changed: 34,
    description_changed: 35,
    complexity_changed: 36,
    # Responsavel dos Niveis 2 a 5 (`meta.level`); o Nivel 1 e `assignee_changed`.
    assignee_level_changed: 37,
    attachment_added: 38,
    attachment_removed: 39,
    time_entry_added: 40,
    time_entry_removed: 41,
    checklist_item_completed: 42,
    checklist_item_reopened: 43,
    # A Resolucao do ticket (o que foi feito para resolver), registrada ao fechar.
    resolution_changed: 44
  }

  # Mudancas de Mesa que o cliente ve como notificacao (ver
  # Api::V1::Client::NotificationsController).
  CLIENT_MOVE_TYPES = %w[triaged team_changed transferred].freeze

  after_create_commit :ping_client, if: -> { CLIENT_MOVE_TYPES.include?(activity_type) }

  def push_event_data
    labels = Tickets::ActivityLabeler.new([self]).labels_for(self)
    {
      id: id,
      ticket_id: ticket_id,
      activity_type: activity_type,
      previous_value: previous_value,
      new_value: new_value,
      previous_label: labels[:previous_label],
      new_label: labels[:new_label],
      details: labels[:details],
      meta: meta,
      user: user ? { id: user.id, name: user.name, email: user.email } : nil,
      created_at: created_at.to_i
    }
  end

  private

  def ping_client
    ClientNotificationsChannel.ping(ticket.requester_contact)
  end
end
