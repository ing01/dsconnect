# Sends a message to the ticket's customer and records what actually happened.
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

  pattr_initialize [:ticket!, :user!, :body!, :closing!]

  def perform
    communication = build_communication
    deliver(communication)
    communication
  end

  private

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
      closing: closing, status: 'pending'
    )
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
  rescue StandardError => e
    communication.mark_failed!(e.message)
    raise
  end

  # A real delivery produces a message with a recipient. A NullMail - which is
  # what an early return yields - has neither.
  def delivered?(mail)
    mail.present? && !mail.is_a?(ActionMailer::Base::NullMail) && mail.to.present?
  end

  def log_activity(communication)
    ticket.ticket_activities.create!(
      account_id: ticket.account_id, user: user,
      activity_type: :customer_communication_sent,
      new_value: communication.to_email,
      meta: { subject: communication.subject, closing: communication.closing }
    )
  end
end
