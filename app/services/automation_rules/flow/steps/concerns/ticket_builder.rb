# Monta e vincula o Ticket da mesma forma que `CreateTicket` sempre fez -
# extraido para ca porque o Widget precisa criar o ticket so no FINAL do
# atendimento (quando a IA resolve ou quando encaminha), e nao logo no
# comeco como o WhatsApp faz. As duas etapas usam o mesmo resultado: mesmas
# Mesas, Estagios, Prioridades e Categorias, mesmo vinculo `ticket_conversations`.
module AutomationRules::Flow::Steps::Concerns::TicketBuilder
  extend ActiveSupport::Concern

  private

  # Nao cria de novo se a execucao ja tem um ticket (por exemplo, o cliente
  # informou um numero valido antes, ou uma etapa `create_ticket` anterior ja
  # rodou) - devolve o ticket existente nesse caso.
  #
  # Em caso de falha ao salvar, devolve um Hash com `error:` em vez de um
  # Ticket - quem chama decide o que fazer (normalmente, avisar e encaminhar).
  def build_and_link_ticket!
    return run.ticket if run.ticket.present?

    ticket = account.tickets.new(ticket_attributes)
    return { error: ticket.errors.full_messages.to_sentence } unless ticket.save

    ticket.ticket_conversations.find_or_create_by!(conversation_id: conversation.id)
    remember_ticket(ticket)
    ticket
  end

  def ticket_attributes
    {
      title: ticket_title,
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
  def ticket_title
    rendered = resolver.render(params[:title])
    rendered.presence || I18n.t('automations.flow.default_ticket_title', id: conversation.display_id)
  end

  def remember_ticket(ticket)
    run.update!(ticket: ticket)
    run.write_variable('ticket.id', ticket.id)
    run.write_variable('ticket.numero', ticket.display_id)
    run.write_variable('ticket.titulo', ticket.title)
  end
end
