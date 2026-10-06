# Em segundo plano, mesmo motivo de Tickets::CustomerCommunicationNotificationJob
# - a resposta do agente nao deve esperar o envio do push pro cliente.
class Client::TicketCommunicationPushNotificationJob < ApplicationJob
  queue_as :low

  def perform(communication_id)
    communication = TicketCustomerCommunication.find_by(id: communication_id)
    return if communication.blank?

    Client::TicketCommunicationPushNotificationService.new(communication: communication).perform
  end
end
