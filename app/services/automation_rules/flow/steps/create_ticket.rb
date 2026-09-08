# Cria o Ticket com o que a triagem coletou e vincula a Conversation.
#
# Usa o Ticket como qualquer outra parte do sistema usa: mesmas Mesas, Estagios,
# Prioridades e Categorias, mesmo vinculo `ticket_conversations`. A automacao
# nao tem um ticket proprio nem um caminho paralelo de criacao.
class AutomationRules::Flow::Steps::CreateTicket < AutomationRules::Flow::Steps::Base
  def perform
    ticket = account.tickets.new(attributes)
    return fail_step(ticket.errors.full_messages.to_sentence) unless ticket.save

    link_conversation(ticket)
    remember(ticket)

    continue(result: { ticket_id: ticket.id, display_id: ticket.display_id, title: ticket.title })
  end

  private

  def attributes
    {
      title: title,
      description: resolver.render(params[:description]),
      company_id: run.read_variable('empresa.id'),
      contact_id: run.read_variable('contato.id'),
      team_id: params[:team_id],
      ticket_column_id: params[:ticket_column_id],
      ticket_category_id: params[:ticket_category_id],
      priority: params[:priority].presence || 'medium'
    }.compact
  end

  # O titulo aceita variaveis, entao o padrao do produto - [EMPRESA] | [PESSOA] |
  # assunto - e configuracao do admin, e nao regra fixa aqui.
  def title
    rendered = resolver.render(params[:title])
    rendered.presence || I18n.t('automations.flow.default_ticket_title', id: conversation.display_id)
  end

  # O vinculo e o mesmo que a tela usa. `find_or_create_by` porque uma conversa
  # ja ligada aquele ticket nao pode virar duas linhas.
  def link_conversation(ticket)
    ticket.ticket_conversations.find_or_create_by!(conversation_id: conversation.id)
  end

  def remember(ticket)
    run.update!(ticket: ticket)
    run.write_variable('ticket.id', ticket.id)
    run.write_variable('ticket.numero', ticket.display_id)
    run.write_variable('ticket.titulo', ticket.title)
  end
end
