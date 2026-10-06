# Sends a message to the ticket's customer and records what actually happened.
#
# `notify_customer: false` registra a mensagem sem enviar e-mail nenhum. A
# mensagem continua existindo para o cliente - ela aparece na Area do Cliente
# como qualquer outra -, e serve para quando a equipe ja falou com ele por
# telefone ou WhatsApp e quer registrar isso no chamado.
#
# Delivery is synchronous on purpose. Chatwoot's own outgoing e-mail path
# (Email::SendOnEmailService) does the same, for the same reason: a background
# job cannot tell the caller whether the message went out, and closing a ticket
# depends on that answer. `raise_delivery_errors` is on and the mailer only
# swallows Net::SMTPSyntaxError, so a real failure reaches us here.
class Tickets::CustomerCommunicationService
  # ApplicationMailer returns early (a NullMail) when there is no SMTP
  # configured outside development. Without this the service would mark the
  # message sent even though nothing left the building - the exact false
  # positive the closing rule must not have.
  class NotDelivered < StandardError; end

  pattr_initialize [:ticket!, :user!, :body!, :closing!, :notify_customer]

  def perform
    communication = build_communication
    notify_customer? ? deliver(communication) : register_only(communication)
    communication
  end

  private

  # Ausente quer dizer enviar - e o que sempre aconteceu, e o que quem chama a
  # API sem conhecer o campo espera. So um `false` explicito deixa de enviar.
  def notify_customer?
    notify_customer.nil? || notify_customer
  end

  def contact
    @contact ||= ticket.requester_contact
  end

  def build_communication
    ticket.ticket_customer_communications.create!(
      account_id: ticket.account_id, user: user, contact: contact,
      # Always the ticket header, closing notice included: the customer
      # recognises the thread from the subject alone, and no agent has to type
      # it.
      to_email: ticket.customer_email, subject: ticket.display_subject, body: body,
      closing: closing, status: 'pending', notify_customer: notify_customer?
    )
  end

  # Sem e-mail: a mensagem passa a existir do mesmo jeito - fica no chamado e
  # aparece na Area do Cliente -, so nao sai pelo correio. Vale para o
  # fechamento e cumpre o SLA de atendimento pelo mesmo motivo: o cliente TEM o
  # que ler. O que nunca acontece aqui e uma entrega, e por isso o status e
  # `skipped` e nao `sent`.
  def register_only(communication)
    communication.mark_skipped!
    log_activity(communication)
    fulfil_response_sla(communication)
  rescue StandardError => e
    communication.mark_failed!(e.message)
    raise
  end

  # The record is written first and only marked `sent` once the delivery
  # returned, so a message is never reported as sent because a button was
  # clicked. A failure is kept with its reason and re-raised, leaving the ticket
  # untouched.
  def deliver(communication)
    # Two distinct messages: ordinary correspondence and the closing notice.
    # Sending one and later closing the ticket produces two different e-mails.
    action = closing ? :closing_communication : :customer_message
    delivered = TicketCustomerMailer.with(account: ticket.account)
                                    .public_send(action, communication)
                                    .deliver_now
    raise NotDelivered, I18n.t('tickets.communication.not_delivered') unless delivered?(delivered)

    communication.mark_sent!
    log_activity(communication)
    fulfil_response_sla(communication)
    notify_customer_by_push(communication)
  rescue StandardError => e
    communication.mark_failed!(e.message)
    raise
  end

  # So' no caminho que de fato avisa o cliente (`deliver`, nunca
  # `register_only`) - a mesma regra que ja vale pro e-mail: quando o agente
  # marca "nao notificar", nada sai por nenhum canal.
  def notify_customer_by_push(communication)
    Client::TicketCommunicationPushNotificationJob.perform_later(communication.id)
  end

  # A real delivery produces a message with a recipient. A NullMail - which is
  # what an early return yields - has neither.
  def delivered?(mail)
    mail.present? && !mail.is_a?(ActionMailer::Base::NullMail) && mail.to.present?
  end

  # Uma comunicacao que saiu de fato cumpre o SLA de atendimento. Fica depois do
  # `mark_sent!` de proposito: o prazo so e cumprido pelo que o cliente recebeu,
  # nunca pelo que o agente clicou.
  def fulfil_response_sla(communication)
    Tickets::Sla::ManagerService.new(ticket: ticket).customer_communicated(
      user: user,
      source: TicketSlaEvent::SOURCE_TICKET_COMMUNICATION,
      meta: { ticket_customer_communication_id: communication.id, to_email: communication.to_email }
    )
  end

  def log_activity(communication)
    ticket.ticket_activities.create!(
      account_id: ticket.account_id, user: user,
      activity_type: :customer_communication_sent,
      new_value: communication.to_email,
      # `notify_customer` distingue, no Historico, o que saiu por e-mail do que
      # foi apenas registrado - as duas coisas produzem a mesma atividade.
      meta: { subject: communication.subject, closing: communication.closing,
              notify_customer: communication.notify_customer }
    )
  end
end
