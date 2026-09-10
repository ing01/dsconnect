class Notification::PushNotificationService
  include Rails.application.routes.url_helpers

  pattr_initialize [:notification!]

  def perform
    return unless user_subscribed_to_notification?

    notification_subscriptions.each do |subscription|
      send_browser_push(subscription)
      send_fcm_push(subscription)
      send_push_via_chatwoot_hub(subscription)
    end
  end

  private

  delegate :user, to: :notification
  delegate :notification_subscriptions, to: :user
  delegate :notification_settings, to: :user

  def user_subscribed_to_notification?
    notification_setting = notification_settings.find_by(account_id: notification.account.id)
    return true if notification_setting.public_send("push_#{notification.notification_type}?")

    false
  end

  def conversation
    @conversation ||= notification.conversation
  end

  def push_message
    {
      title: notification.push_message_title,
      # O que o cliente precisa para marcar como lida sem consultar a API.
      id: notification.id,
      primary_actor_type: notification.primary_actor_type,
      primary_actor_id: notification.primary_actor_id,
      tag: notification.push_group_tag,
      # Caminho relativo: o service worker resolve contra a origem em uso,
      # entao o clique sempre cai no endereco que a pessoa realmente abriu.
      url: notification.push_target_path
    }
  end

  # Para onde o clique leva. Sai do proprio ator, e nao da Conversation: o
  # `PRIMARY_ACTORS` ja aceita Project - e agora tambem o Chat Interno -, e
  # montar a URL de conversa para todos quebrava com
  # `undefined method 'display_id'` no envio.
  def push_url
    notification.push_target_url
  end

  # Identificacao de quem envia, exigida pelo VAPID como URL absoluta ou
  # mailto. Nao e o destino do clique - por isso nao acompanha o caminho
  # relativo - e um FRONTEND_URL vazio nao pode derrubar o envio.
  def vapid_subject
    notification.frontend_base_url.presence || 'https://www.chatwoot.com'
  end

  def can_send_browser_push?(subscription)
    VapidService.public_key && subscription.browser_push?
  end

  def browser_push_payload(subscription)
    {
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
    }
  end

  def send_browser_push(subscription)
    return unless can_send_browser_push?(subscription)

    WebPush.payload_send(**browser_push_payload(subscription))
    Rails.logger.info("Browser push sent to #{user.email} with title #{push_message[:title]}")
  rescue StandardError => e
    handle_browser_push_error(e, subscription)
  end

  def handle_browser_push_error(error, subscription)
    case error
    when WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
      Rails.logger.info "WebPush subscription expired: #{error.message}"
      subscription.destroy!
    when WebPush::TooManyRequests
      Rails.logger.warn "WebPush rate limited for #{user.email} on account #{notification.account.id}: #{error.message}"
    when Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout, Socket::ResolutionError
      Rails.logger.error "WebPush operation error: #{error.message}"
    else
      ChatwootExceptionTracker.new(error, account: notification.account).capture_exception
      true
    end
  end

  def send_fcm_push(subscription)
    return unless firebase_credentials_present?
    return unless subscription.fcm?

    fcm_service = Notification::FcmService.new(
      GlobalConfigService.load('FIREBASE_PROJECT_ID', nil), GlobalConfigService.load('FIREBASE_CREDENTIALS', nil)
    )
    fcm = fcm_service.fcm_client
    response = fcm.send_v1(fcm_options(subscription))
    remove_subscription_if_error(subscription, response)
  end

  def send_push_via_chatwoot_hub(subscription)
    return if firebase_credentials_present?
    return unless chatwoot_hub_enabled?
    return unless subscription.fcm?

    ChatwootHub.send_push(fcm_options(subscription))
  end

  def firebase_credentials_present?
    GlobalConfigService.load('FIREBASE_PROJECT_ID', nil) && GlobalConfigService.load('FIREBASE_CREDENTIALS', nil)
  end

  def chatwoot_hub_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_PUSH_RELAY_SERVER', true))
  end

  def remove_subscription_if_error(subscription, response)
    if JSON.parse(response[:body])['results']&.first&.keys&.include?('error')
      subscription.destroy!
    else
      Rails.logger.info("FCM push sent to #{user.email} with title #{push_message[:title]}")
    end
  end

  def fcm_options(subscription)
    {
      'token': subscription.subscription_attributes['push_token'],
      'data': fcm_data,
      'notification': fcm_notification,
      'android': fcm_android_options,
      'apns': fcm_apns_options,
      'fcm_options': {
        analytics_label: 'Label'
      }
    }
  end

  def fcm_data
    {
      payload: {
        data: {
          notification: notification.fcm_push_data
        }
      }.to_json
    }
  end

  def fcm_notification
    {
      title: notification.push_message_title,
      body: notification.push_message_body
    }
  end

  def fcm_android_options
    {
      priority: 'high'
    }
  end

  def fcm_apns_options
    {
      payload: {
        aps: {
          sound: 'default',
          category: Time.zone.now.to_i.to_s
        }
      }
    }
  end
end
