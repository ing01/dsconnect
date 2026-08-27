# Liga o Chat ao SLA de atendimento do Ticket.
#
# Uma resposta do atendente ao cliente numa Conversation vinculada cumpre o
# prazo de atendimento do Ticket, do mesmo jeito que a aba "Comunicacao com
# cliente" cumpre. Nao ha SLA proprio de Conversation sendo tocado aqui: o
# AppliedSla continua seguindo suas proprias regras, e este listener so lê o
# mesmo evento para alimentar o relogio do Ticket.
class TicketSlaListener < BaseListener
  def message_created(event)
    message, = extract_message_and_account(event)
    return unless customer_facing?(message)

    tickets_for(message.conversation).each { |ticket| fulfil(ticket, message) }
  end

  private

  # O que conta como falar com o cliente: mensagem de saida, publica, de gente.
  #
  # Ficam de fora nota interna e chat interno entre funcionarios (`private`),
  # mensagens recebidas do proprio cliente (`incoming`) e as de sistema
  # (`activity`/`template`), que ninguem escreveu.
  def customer_facing?(message)
    message.outgoing? && !message.private? && message.content.present?
  end

  # Um Ticket pode ter varias Conversations, e a mesma Conversation pode estar
  # em mais de um Ticket - a relacao e `ticket_conversations`, nunca um
  # `conversation_id` unico no ticket.
  def tickets_for(conversation)
    return Ticket.none if conversation.blank?

    conversation.tickets.operational
  end

  def fulfil(ticket, message)
    Tickets::Sla::ManagerService.new(ticket: ticket).customer_communicated(
      user: message.sender.is_a?(User) ? message.sender : nil,
      source: TicketSlaEvent::SOURCE_CONVERSATION_MESSAGE,
      meta: { conversation_id: message.conversation_id, message_id: message.id }
    )
  end
end
