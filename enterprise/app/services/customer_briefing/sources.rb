# O que entra no "Resumo do cliente" de uma conversa. Usado pela ficha (dados na
# tela) e pelo texto da IA, para os dois olharem exatamente as mesmas coisas.
class CustomerBriefing::Sources
  CONVERSATIONS_LIMIT = 5
  TICKETS_LIMIT = 10
  NOTES_LIMIT = 3

  pattr_initialize [:conversation!, :user!, { company_id: nil }]
  # O texto da IA tambem precisa saber qual e a conversa aberta.
  public :conversation

  delegate :account, :contact, to: :conversation

  # As empresas do contato e a do ticket vinculado. Vazio quando a conta nao usa
  # o cadastro de Empresas.
  def companies
    @companies ||= if account.feature_enabled?('companies')
                     ids = [linked_ticket_company_id, contact.company_id, *contact.company_ids].compact.uniq
                     account.companies.where(id: ids).sort_by { |item| ids.index(item.id) }
                   else
                     []
                   end
  end

  # A pedida na tela; sem pedido, a do ticket vinculado e depois a principal.
  def company
    @company ||= companies.find { |item| item.id == company_id.to_i } || companies.first
  end

  def notes
    contact.notes.latest.includes(:user).limit(NOTES_LIMIT)
  end

  # Da empresa (ou, sem empresa, do contato): os abertos primeiro, do mais novo
  # para o mais antigo.
  def tickets
    scope = company ? company.tickets : account.tickets.where(contact_id: contact.id)
    scope.includes(:team, :assignee, :contact)
         .order(Arel.sql("CASE WHEN tickets.status = #{Ticket.statuses[:open]} THEN 0 ELSE 1 END"),
                created_at: :desc, id: :desc)
         .limit(TICKETS_LIMIT)
  end

  # So' as conversas que esta pessoa pode ver, fora a que esta aberta.
  def previous_conversations
    Conversations::PermissionFilterService.new(
      account.conversations.where.not(id: conversation.id), user, account
    ).perform
  end

  def contact_conversations
    latest(previous_conversations.where(contact_id: contact.id))
  end

  # Conversas de outros contatos da mesma empresa.
  def colleague_conversations
    return [] unless company

    colleague_ids = account.contacts
                           .where(id: company.company_contacts.select(:contact_id))
                           .or(account.contacts.where(company_id: company.id))
                           .where.not(id: contact.id)
                           .select(:id)
    latest(previous_conversations.where(contact_id: colleague_ids))
  end

  private

  def latest(scope)
    scope.includes(:contact, :assignee, :inbox)
         .reorder(last_activity_at: :desc, id: :desc)
         .limit(CONVERSATIONS_LIMIT)
         .to_a
  end

  def linked_ticket_company_id
    conversation.tickets.where.not(company_id: nil).reorder(created_at: :desc).pick(:company_id)
  end
end
