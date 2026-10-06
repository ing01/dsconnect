# Em segundo plano: quem respondeu pelo Portal nao deve esperar a bandeja de
# cada seguidor/responsavel ser escrita para receber o 201 (mesmo motivo do
# Tickets::TriageNotificationJob).
class Tickets::CustomerCommunicationNotificationJob < ApplicationJob
  queue_as :low

  def perform(communication_id)
    communication = TicketCustomerCommunication.find_by(id: communication_id)
    return if communication.blank?

    Tickets::CustomerCommunicationNotificationBuilder.new(communication: communication).perform
  end
end
