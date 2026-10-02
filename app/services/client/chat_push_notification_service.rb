# Avisa o Contato (fora da aba do Portal) que a equipe respondeu no chat -
# mesmo mecanismo VAPID que `Notification::PushNotificationService` usa para
# o painel interno, mas dirigido a `ClientPushSubscription` (dono = Contact).
#
# So FCM/Chatwoot Hub ficam de fora: aqueles servem o app mobile do atendente,
# que o Portal do Cliente nao tem.
class Client::ChatPushNotificationService
  pattr_initialize [:message!]

  def perform
    return if VapidService.public_key.blank?
    return if contact.blank?

    # PORTUGUES, sempre - a mesma regra do e-mail (`ForcedPortugueseLocale`) e da
    # Area do Cliente (`ClientAreaLocale::LOCALE`), na mesma definicao unica.
    #
    # Sem isto o aviso saia em INGLES: o push e montado num job de segundo plano,
    # fora do pedido do cliente, e ali nada tinha definido o idioma - sobrava o
    # `I18n.default_locale` da instalacao, que e `en`.
    I18n.with_locale(ClientAreaLocale::LOCALE) do
      contact.client_push_subscriptions.find_each { |subscription| send_browser_push(subscription) }
    end
  end

  private

  def conversation
    @conversation ||= message.conversation
  end

  def contact
    @contact ||= conversation.contact
  end

  # O icone e a LOGO do sistema - o mesmo arquivo que o Portal usa como icone do
  # app instalado (`public/client-manifest.json`), para o aviso ser reconhecido
  # como vindo dali. O `badge` e a versao monocromatica pequena, que o Android
  # mostra na barra de status.
  #
  # Caminhos relativos de proposito: quem resolve o host e o service worker,
  # contra a propria origem (ver `absoluteUrl` em `public/sw.js`). Um host vindo
  # do servidor envelheceria a cada troca de endereco.
  ICON_PATH = '/android-icon-192x192.png'.freeze
  BADGE_PATH = '/favicon-badge-96x96.png'.freeze

  def push_message
    {
      title: I18n.t('client_area.chat.push_title'),
      body: message.content.to_s.truncate(160).presence || I18n.t('client_area.chat.push_body_fallback'),
      tag: "client_chat_#{conversation.id}",
      url: '/app/client/chat',
      icon: ICON_PATH,
      badge: BADGE_PATH,
      # O botao do aviso. O rotulo vem daqui porque o service worker nao tem
      # acesso as traducoes - ele so repassa o que o servidor mandou.
      actions: [{ action: 'open', title: I18n.t('client_area.chat.push_action_open') }]
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
    Rails.logger.error "[Client::ChatPushNotificationService] #{e.message}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
  end
end
