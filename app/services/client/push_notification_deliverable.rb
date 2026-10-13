# Compartilhado por quem avisa um Contato por push (chat do Portal, resposta
# de ticket - ver Client::ChatPushNotificationService e
# Client::TicketCommunicationPushNotificationService): decide sozinho se
# cada inscricao e' de navegador (VAPID) ou de app mobile (FCM) e manda pelo
# canal certo, numa unica chamada (`deliver_push!`).
#
# Quem inclui so' precisa definir tres metodos: `contact` (quem recebe),
# `push_message` (hash com `title`/`body`/`tag`/`url`/`actions`) e
# `push_account` (pra onde relatar um erro inesperado de envio).
module Client::PushNotificationDeliverable
  extend ActiveSupport::Concern

  ICON_PATH = '/android-icon-192x192.png'.freeze
  BADGE_PATH = '/favicon-badge-96x96.png'.freeze

  def deliver_push!
    return if contact.blank?

    # PORTUGUES, sempre - a mesma regra do e-mail (`ForcedPortugueseLocale`) e
    # da Area do Cliente (`ClientAreaLocale`). O push e montado num job de
    # segundo plano, fora do pedido do cliente, entao nada define o idioma
    # sozinho - sem isto o aviso saia em INGLES (o `I18n.default_locale` da
    # instalacao).
    I18n.with_locale(ClientAreaLocale::LOCALE) do
      contact.client_push_subscriptions.find_each { |subscription| deliver_to(subscription) }
    end
  end

  private

  def deliver_to(subscription)
    if subscription.browser_push?
      send_browser_push(subscription)
    elsif subscription.fcm?
      send_fcm_push(subscription)
    end
  end

  def vapid_subject
    ENV.fetch('FRONTEND_URL', 'https://www.chatwoot.com')
  end

  # Caminhos relativos de proposito: quem resolve o host e o service worker,
  # contra a propria origem (ver `absoluteUrl` em `public/sw.js`). Um host
  # vindo do servidor envelheceria a cada troca de endereco.
  def send_browser_push(subscription)
    return if VapidService.public_key.blank?

    WebPush.payload_send(
      message: JSON.generate(push_message.merge(icon: ICON_PATH, badge: BADGE_PATH)),
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
    Rails.logger.error "[Client::PushNotificationDeliverable] #{e.message}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: push_account).capture_exception
  end

  # Mesmas credenciais globais (`FIREBASE_PROJECT_ID`/`FIREBASE_CREDENTIALS`)
  # que o push do app do colaborador ja usa (`Notification::PushNotificationService`)
  # - uma unica configuracao de Firebase serve os dois apps.
  def send_fcm_push(subscription)
    return unless firebase_credentials_present?

    fcm_service = Notification::FcmService.new(
      GlobalConfigService.load('FIREBASE_PROJECT_ID', nil), GlobalConfigService.load('FIREBASE_CREDENTIALS', nil)
    )
    response = fcm_service.fcm_client.send_v1(fcm_options(subscription))
    subscription.destroy! if JSON.parse(response[:body])['results']&.first&.keys&.include?('error')
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: push_account).capture_exception
  end

  def firebase_credentials_present?
    GlobalConfigService.load('FIREBASE_PROJECT_ID', nil) && GlobalConfigService.load('FIREBASE_CREDENTIALS', nil)
  end

  # Mesmo envelope que `Notification::PushNotificationService#fcm_options`
  # usa pro app do colaborador - o app Flutter trata os dois com o mesmo
  # codigo, so' o conteudo de `data.payload` muda.
  def fcm_options(subscription)
    {
      'token': subscription.subscription_attributes['push_token'],
      'data': { payload: push_message.except(:title, :body).to_json },
      'notification': { title: push_message[:title], body: push_message[:body] },
      'android': { priority: 'high' },
      'apns': { payload: { aps: { sound: 'default', category: Time.zone.now.to_i.to_s } } },
      'fcm_options': { analytics_label: 'Label' }
    }
  end
end
