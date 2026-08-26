# Closing a ticket now requires a service catalogue classification and a closing
# message that actually reached the customer. Specs whose subject is something
# else - the Kanban scope, duplication, a transfer - state that setup through
# this helper instead of repeating it, and keep exercising the real close path
# rather than bypassing the rules.
module TicketClosingHelpers
  # Gives the ticket both requirements. Returns the ticket so it can be chained.
  def make_ticket_closeable!(ticket, user: nil)
    classify_ticket!(ticket)
    record_closing_communication!(ticket, user: user)
    ticket
  end

  def classify_ticket!(ticket)
    return ticket if ticket.service_catalog_item_id.present?

    catalog = ServiceCatalog.find_by(account_id: ticket.account_id) ||
              FactoryBot.create(:service_catalog, account: ticket.account)
    area = catalog.service_catalog_areas.first ||
           FactoryBot.create(:service_catalog_area, service_catalog: catalog)
    item = area.service_catalog_items.first ||
           FactoryBot.create(:service_catalog_item, service_catalog_area: area)

    ticket.update!(service_catalog_item: item)
    ticket
  end

  # Written straight to the table on purpose: these specs are not about the
  # mailer, and going through it would make them depend on SMTP being reachable.
  def record_closing_communication!(ticket, user: nil)
    ticket.ticket_customer_communications.create!(
      account_id: ticket.account_id,
      user: user,
      contact: ticket.requester_contact,
      to_email: ticket.customer_email.presence || 'cliente@empresa.com',
      subject: 'Encerramento',
      body: 'Atendimento concluído.',
      closing: true,
      status: 'sent',
      sent_at: Time.zone.now
    )
  end
end

RSpec.configure do |config|
  config.include TicketClosingHelpers
end
