# As novidades dos chamados do cliente.
#
# Nao ha tabela de notificacao para contato, e inventar uma so para listar isto
# seria construir estrutura antes de haver o que guardar: o que interessa ao
# cliente hoje e o que a EQUIPE escreveu nos chamados dele, e isso ja existe em
# `ticket_customer_communications`.
#
# Quando houver estado de lido/nao lido, e aqui que ele entra.
class Api::V1::Client::NotificationsController < Api::V1::Client::BaseController
  LIMIT = 50

  def index
    @communications = TicketCustomerCommunication
                      .where(ticket_id: visible_tickets.select(:id))
                      # So o que a equipe enviou: a propria resposta do cliente
                      # nao e novidade para ele.
                      .outbound
                      .includes(:user, :ticket)
                      .order(created_at: :desc)
                      .limit(LIMIT)
  end
end
