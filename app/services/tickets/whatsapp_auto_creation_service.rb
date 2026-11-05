# Garante um Ticket para toda conversa nova do canal WhatsApp, independente de
# qualquer Automacao configurada - o WhatsApp nao tem outro lugar onde o
# atendimento fique registrado, e uma conta sem regra (ou cuja regra nao bate)
# nao pode simplesmente deixar a conversa sem Ticket.
#
# So' atua se a conversa ainda nao tiver nenhum Ticket vinculado - se uma
# Automacao (fluxo de IA, por exemplo) ja criou e vinculou um antes deste
# listener rodar, este servico nao cria um segundo.
class Tickets::WhatsappAutoCreationService
  pattr_initialize [:conversation!]

  def perform
    return if conversation.ticket_conversations.exists?

    ticket = account.tickets.new(ticket_attributes)
    return unless ticket.save

    ticket.ticket_conversations.create!(conversation: conversation)
    ticket
  end

  private

  def account
    conversation.account
  end

  def contact
    conversation.contact
  end

  def team
    @team ||= Tickets::DefaultMesaBuilder.new(account: account).perform
  end

  # Mesmo destino que `Projects::CreateTicketsService` usa para tickets criados
  # fora do fluxo manual: o Estagio `pending` da Mesa, ou o primeiro da lista
  # quando a Mesa nao tiver um.
  def ticket_column
    @ticket_column ||= team.ticket_columns.find_by(kind: 'pending') ||
                        team.ticket_columns.order(:position).first
  end

  def ticket_attributes
    {
      title: ticket_title,
      team_id: team.id,
      ticket_column_id: ticket_column.id,
      contact_id: contact&.id,
      company_id: contact&.company_id
    }.compact
  end

  def ticket_title
    name = contact&.name.presence
    return I18n.t('tickets.auto_creation.whatsapp_title_named', name: name) if name

    I18n.t('tickets.auto_creation.whatsapp_title', id: conversation.display_id)
  end
end
