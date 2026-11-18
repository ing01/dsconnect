# Em segundo plano: mover o ticket nao pode esperar o envio do e-mail. Sem
# retentativa de proposito - repetir depois de um envio parcial mandaria a mesma
# mensagem duas vezes ao cliente.
class Tickets::CustomerNoticeJob < ApplicationJob
  queue_as :low

  discard_on StandardError do |job, error|
    Rails.logger.error("[Tickets::CustomerNoticeJob] #{job.arguments.inspect}: #{error.class} #{error.message}")
  end

  def perform(ticket_id, column_id, from_team_id = nil, to_team_id = nil)
    ticket = Ticket.find_by(id: ticket_id)
    return if ticket.blank?

    Tickets::CustomerNoticeService.new(
      ticket: ticket, column_id: column_id, from_team_id: from_team_id, to_team_id: to_team_id
    ).perform
  end
end
