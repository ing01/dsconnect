# Avisa o Contato que a equipe respondeu um ticket pelo Portal - por
# navegador (VAPID) ou pelo app mobile (FCM), conforme a inscricao (ver
# Client::PushNotificationDeliverable). Mesma ideia do
# Client::ChatPushNotificationService, so' que para `TicketCustomerCommunication`
# em vez de uma mensagem do chat do Portal.
class Client::TicketCommunicationPushNotificationService
  include Client::PushNotificationDeliverable
  pattr_initialize [:communication!]

  def perform
    deliver_push!
  end

  private

  def ticket
    communication.ticket
  end

  # A comunicacao sempre tem um contato gravado quando e' do cliente
  # respondendo (`inbound`); aqui e' o caminho contrario (`outbound`, o
  # agente escrevendo), que nao preenche esse campo - por isso cai no
  # solicitante do proprio ticket.
  def contact
    @contact ||= communication.contact || ticket.requester_contact
  end

  def push_message
    {
      title: I18n.t('client_area.ticket_communication.push_title', display_id: ticket.display_id),
      body: communication.body.to_s.truncate(160),
      tag: "client_ticket_communication_#{ticket.id}",
      url: "/app/client/tickets/#{ticket.id}",
      actions: [{ action: 'open', title: I18n.t('client_area.ticket_communication.push_action_open') }]
    }
  end

  def push_account
    ticket.account
  end
end
