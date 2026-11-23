# Quando um impedimento e removido (ou concluido), o responsavel pelo ticket FILHO
# precisa saber: era ele quem estava parado esperando.
#
# Quem recebe:
#   - o ticket que e' FILHO e teve o PROPRIO impedimento removido: o responsavel dele;
#   - o ticket PAI que teve o impedimento removido:
#       * se o impedimento do pai veio de um filho (`blocked_by_child`), so' o responsavel
#         daquele filho - os outros filhos nada tem a ver com isso;
#       * se era um impedimento proprio do pai (ex.: aguardando o cliente), o responsavel de
#         cada filho ainda aberto;
#   - quando o pai foi liberado EM CASCATA por um filho (`cascaded`), ninguem alem do proprio
#     filho que o liberou: ele mesmo ja' foi avisado pelo seu proprio movimento.
#
# Quem removeu o impedimento nunca avisa a si mesmo, e filho ja' encerrado ou cancelado nao
# precisa de aviso. O aviso abre o ticket FILHO; o ticket que foi liberado vai como ator
# secundario, para o texto dizer de qual impedimento se trata.
class Tickets::ImpedimentReleasedNotificationBuilder
  NOTIFICATION_TYPE = 'ticket_impediment_released'.freeze

  pattr_initialize [:ticket!, :user, :origin_child, { cascaded: false }]

  def perform
    notified = []
    children_to_notify.each do |child|
      assignee = child.assignee
      next if assignee.blank? || assignee == user || notified.include?(assignee.id)

      notified << assignee.id
      assignee.notifications.create!(
        notification_type: NOTIFICATION_TYPE,
        account: child.account,
        primary_actor: child,
        secondary_actor: ticket
      )
    end
  end

  private

  def children_to_notify
    list = []
    list << ticket if ticket.parent_id.present?
    list.concat(open_children) unless cascaded
    list.reject(&:finalized?).uniq
  end

  def open_children
    return [origin_child].compact if origin_child.present?

    ticket.children.to_a
  end
end
