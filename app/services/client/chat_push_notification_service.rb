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
      body: push_body,
      tag: "client_chat_#{conversation.id}",
      url: '/app/client/chat',
      # O botao do aviso. O rotulo vem daqui porque o service worker nao tem
      # acesso as traducoes - ele so repassa o que o servidor mandou.
      actions: [{ action: 'open', title: I18n.t('client_area.chat.push_action_open') }]
    }
  end

  # "Maria: o texto da resposta" - o cliente ve QUEM respondeu e O QUE foi dito
  # sem abrir o app. Mensagem so com arquivo diz que veio um arquivo; sem nada
  # disso, cai no aviso generico.
  def push_body
    text = message.content.to_s.squish.truncate(140).presence
    text ||= I18n.t('client_area.chat.push_attachment_body') if message.attachments.any?
    return I18n.t('client_area.chat.push_body_fallback') if text.blank?

    author = message.sender.is_a?(User) ? message.sender.available_name : nil
    author.present? ? "#{author}: #{text}" : text
  end

  def push_account
    message.account
  end
end
