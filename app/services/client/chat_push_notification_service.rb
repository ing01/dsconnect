# Avisa o Contato (fora da aba do Portal) que a equipe respondeu no chat -
# por navegador (VAPID) ou pelo app mobile (FCM), conforme a inscricao (ver
# Client::PushNotificationDeliverable).
class Client::ChatPushNotificationService
  include Client::PushNotificationDeliverable
  pattr_initialize [:message!]

  def perform
    deliver_push!
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
      url: '/app/client/chat',
      # O botao do aviso. O rotulo vem daqui porque o service worker nao tem
      # acesso as traducoes - ele so repassa o que o servidor mandou.
      actions: [{ action: 'open', title: I18n.t('client_area.chat.push_action_open') }]
    }
  end

  def push_account
    message.account
  end
end
