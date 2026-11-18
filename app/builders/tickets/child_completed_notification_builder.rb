# Quando um ticket FILHO e concluido, deixa o ticket PAI saber:
#   - uma nota no Historico do pai ("Ticket filho #123 foi concluido"), que fica
#     como registro mesmo que ninguem veja o aviso na hora;
#   - uma notificacao para o RESPONSAVEL do pai, que abre o pai ao clicar;
#   - o selo "filho concluido" no cartao do pai, no Kanban.
#
# Pai ja encerrado ou cancelado nao precisa de aviso: ninguem esta esperando
# o filho.
class Tickets::ChildCompletedNotificationBuilder
  pattr_initialize [:ticket!]

  def perform
    parent = ticket.parent
    return if parent.blank? || parent.closed? || parent.cancelled?

    mark_parent(parent)
    record_note(parent)
    notify_assignee(parent)
  end

  private

  # O selo do cartao do Kanban: quem acompanha o quadro ve na hora que o filho
  # terminou. Fica ate o analista dar o visto (ver TicketsController#acknowledge_child_completed).
  def mark_parent(parent)
    parent.update!(child_completed_at: Time.current, child_completed_display_id: ticket.display_id)
  end

  def record_note(parent)
    parent.ticket_activities.create!(
      account_id: parent.account_id, user: nil, activity_type: :automation_note,
      new_value: "Ticket filho ##{ticket.display_id} (#{ticket.title}) foi concluído."
    )
  end

  def notify_assignee(parent)
    assignee = parent.assignee
    return if assignee.blank?

    assignee.notifications.create!(
      notification_type: 'ticket_child_completed',
      account: parent.account,
      primary_actor: parent,
      secondary_actor: ticket
    )
  end
end
