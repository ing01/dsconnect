# Os dados do "Resumo do cliente" na tela da conversa: quem e' o contato, qual a
# empresa e o que aconteceu nos ultimos atendimentos. Tudo direto do banco, sem
# IA. Credenciais e valores de contrato da empresa ficam de fora de proposito.
class CustomerBriefing::FactsBuilder
  SNIPPET_LENGTH = 200

  pattr_initialize [:conversation!, :user!, { company_id: nil }]

  def perform
    {
      contact: contact_data,
      companies: sources.companies.map { |item| { id: item.id, name: item.name } },
      company: company && company_data,
      tickets: sources.tickets.map { |ticket| ticket_data(ticket) },
      contact_conversations: conversations_data(sources.contact_conversations),
      company_conversations: conversations_data(sources.colleague_conversations)
    }
  end

  private

  delegate :contact, to: :conversation
  delegate :company, to: :sources

  def sources
    @sources ||= CustomerBriefing::Sources.new(conversation: conversation, user: user, company_id: company_id)
  end

  def contact_data
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      previous_conversations_count: sources.previous_conversations.where(contact_id: contact.id).count,
      notes: notes_data
    }
  end

  def notes_data
    sources.notes.map do |note|
      { content: note.content.to_s.truncate(SNIPPET_LENGTH), author: note.user&.name, created_at: note.created_at.to_i }
    end
  end

  def company_data
    {
      id: company.id,
      name: company.name,
      status: company.status,
      blocked: company.blocked,
      **company_profile,
      tickets_count: company.tickets.count,
      open_tickets_count: company.tickets.open.count
    }
  end

  def company_profile
    {
      classification_level: company.classification_level,
      category: company.company_category&.name,
      specialist: company.specialist&.name,
      system_modules: company.system_modules.map(&:name).sort,
      system_started_on: company.system_started_on
    }
  end

  def ticket_data(ticket)
    {
      id: ticket.id,
      display_id: ticket.display_id,
      title: ticket.title,
      status: ticket.status,
      priority: ticket.priority,
      team: ticket.team&.name,
      assignee: ticket.assignee&.name,
      contact: ticket.contact&.name,
      created_at: ticket.created_at.to_i
    }
  end

  def conversations_data(list)
    list.map { |item| conversation_data(item) }
  end

  def conversation_data(item)
    {
      display_id: item.display_id,
      status: item.status,
      contact: item.contact&.name,
      assignee: item.assignee&.name,
      inbox: item.inbox&.name,
      last_activity_at: item.last_activity_at.to_i,
      last_message: last_message(item)
    }
  end

  # A ultima coisa dita ao cliente ou por ele - nota privada e aviso do sistema
  # nao entram.
  def last_message(item)
    item.messages
        .where(message_type: [:incoming, :outgoing], private: false)
        .where.not(content: [nil, ''])
        .reorder(created_at: :desc, id: :desc)
        .pick(:content)
        &.truncate(SNIPPET_LENGTH)
  end
end
