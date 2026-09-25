# Em segundo plano: a conta pode ter dezenas de agentes, e quem abriu o chamado
# nao deve esperar a bandeja de todo mundo ser escrita para receber o 201.
class Tickets::TriageNotificationJob < ApplicationJob
  queue_as :low

  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    return if ticket.blank?

    Tickets::TriageNotificationBuilder.new(ticket: ticket).perform
  end
end
