# Cria o Ticket de toda conversa nova do WhatsApp assim que ela existe - sem
# depender de nenhuma Automacao estar configurada (ou de suas condicoes
# baterem). Qualquer provider do canal conta (Cloud API, 360dialog, AstereZap):
# o que importa e' `channel_type`, nao qual provider manda a mensagem.
class WhatsappTicketAutoCreationListener < BaseListener
  def conversation_created(event)
    conversation, = extract_conversation_and_account(event)
    return unless conversation.inbox.channel_type == 'Channel::Whatsapp'

    Tickets::WhatsappAutoCreationService.new(conversation: conversation).perform
  end
end
