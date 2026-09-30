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

    contact.client_push_subscriptions.find_each { |subscription| send_browser_push(subscription) }
  end

  private

  def conversation
    @conversation ||= message.conversation
  end

  def contact
    @contact ||= conversation.contact
  end

  def push_message
    {
      title: I18n.t('client_area.chat.push_title'),
      body: message.content.to_s.truncate(160).presence || I18n.t('client_area.chat.push_body_fallback'),
      tag: "client_chat_#{conversation.id}",
      url: '/app/client/chat'
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
