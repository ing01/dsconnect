# Avisa o Contato quando a equipe fala no chat do Portal - so quando a
# mensagem e' de fato do chat do Portal (o Inbox marcado por
# `Inboxes::EnsureClientPortalInboxService`). Mensagens de qualquer outro
# canal (WhatsApp, e-mail...) nao tem Contato nenhum esperando notificacao de
# navegador, entao ficam de fora aqui.
#
# Push: TODA mensagem notifica (confirmado com a Ingrid - o cliente quer
# saber sempre que chegou mensagem nova, nao so' na primeira da sessao).
# E-mail: continua so' na PRIMEIRA mensagem de cada sessao - um e-mail por
# linha de conversa seria spam; o push ja cobre o aviso em tempo real.
class ClientPortalChatListener < BaseListener
  def message_created(event)
    message, = extract_message_and_account(event)
    return unless relevant?(message)

    Client::ChatPushNotificationService.new(message: message).perform
    ClientChatMailer.new_message(message).deliver_later if first_outgoing_message?(message)
  end

  private

  def relevant?(message)
    return false unless message.outgoing?
    return false if message.private?

    client_portal_conversation?(message.conversation)
  end

  def client_portal_conversation?(conversation)
    channel = conversation.inbox.channel
    channel.is_a?(Channel::Api) && channel.additional_attributes[Inboxes::EnsureClientPortalInboxService::MARKER_KEY] == true
  end

  def first_outgoing_message?(message)
    !message.conversation.messages.outgoing.where.not(id: message.id).where('created_at < ?', message.created_at).exists?
  end
end

ClientPortalChatListener.prepend_mod_with('ClientPortalChatListener')
