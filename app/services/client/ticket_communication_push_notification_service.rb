# Avisa o Contato que a equipe respondeu um ticket pelo Portal - mesmo
# mecanismo do Client::ChatPushNotificationService (VAPID, so browser push,
# PORTUGUES sempre), so que para `TicketCustomerCommunication` em vez de uma
# mensagem do chat do Portal.
class Client::TicketCommunicationPushNotificationService
  pattr_initialize [:communication!]

  def perform
    return if VapidService.public_key.blank?
    return if contact.blank?

    I18n.with_locale(ClientAreaLocale::LOCALE) do
      contact.client_push_subscriptions.find_each { |subscription| send_browser_push(subscription) }
    end
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

  ICON_PATH = '/android-icon-192x192.png'.freeze
  BADGE_PATH = '/favicon-badge-96x96.png'.freeze

  def push_message
    {
      title: I18n.t('client_area.ticket_communication.push_title', display_id: ticket.display_id),
      body: communication.body.to_s.truncate(160),
      tag: "client_ticket_communication_#{ticket.id}",
      url: "/app/client/tickets/#{ticket.id}",
      icon: ICON_PATH,
      badge: BADGE_PATH,
      actions: [{ action: 'open', title: I18n.t('client_area.ticket_communication.push_action_open') }]
    }
  end

  def vapid_subject
    ENV.fetch('FRONTEND_URL', 'https://www.chatwoot.com')
  end

  def send_browser_push(subscription)
    WebPush.payload_send(
      message: JSON.generate(push_message),
      endpoint: subscription.subscription_attributes['endpoint'],
      p256dh: subscription.subscription_attributes['p256dh'],
      auth: subscription.subscription_attributes['auth'],
      vapid: {
        subject: vapid_subject,
        public_key: VapidService.public_key,
        private_key: VapidService.private_key
      },
      ssl_timeout: 5,
      open_timeout: 5,
      read_timeout: 5
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
    subscription.destroy!
  rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, Socket::ResolutionError => e
    Rails.logger.error "[Client::TicketCommunicationPushNotificationService] #{e.message}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: ticket.account).capture_exception
  end
end
