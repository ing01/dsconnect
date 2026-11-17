# Fecha a triagem da Dua no Portal do Cliente: cria o chamado ja com Mesa,
# Estagio, Categoria e Prioridade decididos na conversa, direto no Kanban da
# equipe - igual um chamado criado manualmente por um agente, sem passar pela
# fila de Triagem (essa fila e' so para quando NAO houve uma classificacao
# confiavel, que nao e' o caso aqui). Deixa uma nota privada resumindo o
# porque da prioridade. So funciona em conversas do Portal do Cliente - em
# qualquer outro canal, a tool se recusa.
class Captain::Tools::CreateTicketFromTriageTool < Captain::Tools::BasePublicTool
  description 'Create the support ticket once the triage is complete. ' \
              'Only call this after you already asked enough questions to understand the problem and its impact - ' \
              'never to start the conversation, and never to try to solve the issue yourself.'
  param :title, type: 'string', desc: 'Short subject for the ticket (a few words) summarizing the problem', required: true
  param :description, type: 'string',
        desc: 'Summary of what the customer reported, written for a human agent to read (not a transcript)', required: true
  param :category_name, type: 'string',
        desc: 'The ticket category name that best matches the problem, exactly as given in your instructions'
  param :priority, type: 'string', desc: 'low, medium, high or urgent', required: true
  param :customer_impact, type: 'string',
        desc: 'One sentence on whether and how this problem directly affects the customer right now - the justification for the priority chosen',
        required: true

  def perform(tool_context, title:, description:, priority:, customer_impact:, category_name: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation
    return 'This tool is only available for Client Portal conversations' unless conversation.inbox&.client_portal?
    return "A ticket was already created for this conversation (##{conversation.tickets.first.display_id})" if conversation.tickets.exists?

    normalized_priority = priority.to_s.downcase
    return "Invalid priority. Valid options: #{Ticket.priorities.keys.join(', ')}" unless Ticket.priorities.key?(normalized_priority)

    ticket = build_ticket(conversation, title, description, category_name, normalized_priority, customer_impact)
    return 'No active team is set up to receive Client Portal tickets for this customer yet' if ticket.team.blank? || ticket.ticket_column.blank?

    unless ticket.save
      log_tool_usage('create_ticket_from_triage_failed', conversation_id: conversation.id, errors: ticket.errors.full_messages)
      return "Could not create the ticket: #{ticket.errors.full_messages.join(', ')}"
    end

    ticket.ticket_conversations.create!(conversation: conversation)
    add_private_note(conversation, ticket, customer_impact)

    log_tool_usage('create_ticket_from_triage', conversation_id: conversation.id, ticket_id: ticket.id)
    "Ticket ##{ticket.display_id} created on the board (category: #{ticket.ticket_category&.name || 'n/a'}, priority: #{ticket.priority})."
  rescue StandardError => e
    Rails.logger.error("[CreateTicketFromTriageTool] #{e.class}: #{e.message}")
    'Could not create the ticket due to an unexpected error. A human agent will need to create it manually.'
  end

  private

  def build_ticket(conversation, title, description, category_name, priority, customer_impact)
    contact = conversation.contact
    company_id = contact&.company_id || contact&.client_company_ids&.first
    category = find_category(category_name)
    resolved = Tickets::PortalRoutingService.new(account: @assistant.account, company_id: company_id, category: category).resolve

    ticket = @assistant.account.tickets.new(title: title.presence, description: description)
    ticket.team = resolved[:team]
    ticket.ticket_column = resolved[:ticket_column]
    ticket.ticket_category = resolved[:ticket_category]
    ticket.priority = priority
    ticket.company_id = company_id
    ticket.contact_id = contact&.id
    ticket.origin = 'client_area'
    # Direto no Kanban: a Dua ja fez a classificacao (equivalente a um agente
    # escolhendo Mesa/Estagio/Categoria na criacao manual), entao nao faz
    # sentido empilhar de novo na fila de Triagem.
    ticket.pending_triage = false
    ticket
  end

  def find_category(category_name)
    return nil if category_name.blank?

    ::TicketCategory.client_visible
                     .joins(:team)
                     .where(teams: { account_id: @assistant.account_id, active: true, visible_in_portal: true })
                     .find_by('LOWER(ticket_categories.name) = ?', category_name.to_s.downcase.strip)
  end

  def add_private_note(conversation, ticket, customer_impact)
    conversation.messages.create!(
      account: @assistant.account,
      inbox: conversation.inbox,
      sender: @assistant,
      message_type: :outgoing,
      private: true,
      content: "Chamado ##{ticket.display_id} criado pela Dua a partir desta conversa, direto no Kanban.\nImpacto no cliente: #{customer_impact}"
    )
  end

  def permissions
    []
  end
end
