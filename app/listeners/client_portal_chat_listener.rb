# Avisa o Contato quando a equipe FALA PRIMEIRO no chat do Portal - so na
# PRIMEIRA mensagem de uma sessao (nova ou reaberta depois de resolvida), e
# so quando a mensagem e' de fato do chat do Portal (o Inbox marcado por
# `Inboxes::EnsureClientPortalInboxService`). Mensagens de qualquer outro
# canal (WhatsApp, e-mail...) nao tem Contato nenhum esperando notificacao de
# navegador, entao ficam de fora aqui.
#
# So a PRIMEIRA: um va-e-volta longo dentro da MESMA sessao nao manda push e
# e-mail a cada resposta - o cliente ja esta olhando a tela (ou acabou de
# ser avisado); o aviso existe pra quando a equipe chama do nada, nao pra
# cada linha de uma conversa em andamento.
class ClientPortalChatListener < BaseListener
  def message_created(event)
    message, = extract_message_and_account(event)
    return unless relevant?(message)
    return unless first_outgoing_message?(message)

    Client::ChatPushNotificationService.new(message: message).perform
    ClientChatMailer.new_message(message).deliver_later
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
