# Em segundo plano: concluir o ticket filho nao pode esperar o aviso ao pai. Sem
# retentativa de proposito - repetir depois de uma falha parcial notificaria o
# analista duas vezes.
class Tickets::ChildCompletedJob < ApplicationJob
  queue_as :low

  discard_on StandardError do |job, error|
    Rails.logger.error("[Tickets::ChildCompletedJob] #{job.arguments.inspect}: #{error.class} #{error.message}")
  end

  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    return if ticket.blank?

    Tickets::ChildCompletedNotificationBuilder.new(ticket: ticket).perform
  end
end
