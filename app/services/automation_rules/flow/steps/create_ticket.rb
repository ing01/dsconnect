# Cria o Ticket com o que a triagem coletou e vincula a Conversation.
#
# Usa o Ticket como qualquer outra parte do sistema usa: mesmas Mesas, Estagios,
# Prioridades e Categorias, mesmo vinculo `ticket_conversations`. A automacao
# nao tem um ticket proprio nem um caminho paralelo de criacao.
class AutomationRules::Flow::Steps::CreateTicket < AutomationRules::Flow::Steps::Base
  include AutomationRules::Flow::Steps::Concerns::TicketBuilder

  def perform
    ticket = build_and_link_ticket!
    return handoff_on_failure(ticket) if ticket.is_a?(Hash)

    continue(result: { ticket_id: ticket.id, display_id: ticket.display_id, title: ticket.title })
  end

  private

  # Uma configuracao incompleta (Estagio/Categoria da etapa mal escolhidos,
  # por exemplo) nao pode deixar o cliente sem nenhuma resposta - avisa e
  # entrega para uma pessoa, com o motivo real gravado no historico da
  # automacao para quem for corrigir a etapa depois.
  def handoff_on_failure(ticket)
    say(I18n.t('automations.flow.create_ticket.error_message'))
    handoff(result: { error: ticket[:error] })
  end
end
