require 'rails_helper'

# The point of sending synchronously: the caller has to know whether the message
# actually left, because closing the ticket depends on it. A record is never
# marked sent because a button was clicked.
RSpec.describe Tickets::CustomerCommunicationService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:company) { create(:company, account: account) }
  let(:contact) { create(:contact, account: account, company: company, email: 'renan@empresa.com') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  let(:ticket) do
    ticket = create(:ticket, account: account, ticket_column: column, team: team,
                             company: company, contact: contact)
    ticket.ticket_conversations.create!(account_id: account.id, conversation: conversation)
    ticket
  end

  # Two things stand between this spec and a delivered message, both of them
  # properties of the repo rather than of this code:
  #   - ApplicationMailer returns a NullMail unless SMTP is set or we are in
  #     development (`smtp_config_set_or_development?`);
  #   - config/initializers/mailer.rb forces `delivery_method = :sendmail`
  #     whenever SMTP_ADDRESS is blank, overriding the test environment.
  # Both are stated here so the examples do not depend on how the machine
  # running them happens to be configured.
  def with_smtp
    allow_any_instance_of(TicketCustomerMailer) # rubocop:disable RSpec/AnyInstance
      .to receive(:smtp_config_set_or_development?).and_return(true)
    previous = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    yield
  ensure
    ActionMailer::Base.delivery_method = previous
  end

  def perform(closing: true, subject: 'Encerramento')
    described_class.new(ticket: ticket, user: user, subject: subject,
                        body: '<p>Resolvido</p>', closing: closing).perform
  end

  describe 'when there is no SMTP configured' do
    # Stated rather than inherited from the machine: whether SMTP_ADDRESS
    # happens to be set in this environment must not decide what this example
    # exercises.
    before do
      allow_any_instance_of(TicketCustomerMailer) # rubocop:disable RSpec/AnyInstance
        .to receive(:smtp_config_set_or_development?).and_return(false)
    end

    # The mailer returns a NullMail; nothing left, so nothing may be reported as
    # sent - otherwise the ticket would become closable on a message that does
    # not exist.
    it 'refuses to report the message as sent' do
      expect { perform }.to raise_error(described_class::NotDelivered)

      communication = ticket.ticket_customer_communications.last
      expect(communication.status).to eq('failed')
      expect(ticket.reload.closing_communication_sent?).to be(false)
    end
  end

  describe 'when the delivery succeeds' do
    it 'records the message as sent, with when' do
      communication = with_smtp { perform }

      expect(communication.status).to eq('sent')
      expect(communication.sent_at).to be_present
      expect(communication.error_message).to be_nil
    end

    it 'sends to the requester address without being told it' do
      communication = with_smtp { perform }

      expect(communication.to_email).to eq('renan@empresa.com')
      expect(communication.contact).to eq(contact)
    end

    it 'actually enqueues a mail' do
      expect { with_smtp { perform } }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['renan@empresa.com'])
      expect(mail.subject).to eq('Encerramento')
    end

    it 'records it in the ticket history' do
      with_smtp { perform }

      activity = ticket.ticket_activities.find_by(activity_type: :customer_communication_sent)
      expect(activity.user).to eq(user)
      expect(activity.new_value).to eq('renan@empresa.com')
    end

    it 'satisfies the closing requirement' do
      with_smtp { perform }

      expect(ticket.reload.closing_communication_sent?).to be(true)
    end

    # Ordinary correspondence is recorded but does not unlock the close.
    it 'does not satisfy it when the message is not a closing one' do
      with_smtp { perform(closing: false) }

      expect(ticket.reload.closing_communication_sent?).to be(false)
    end
  end

  # The customer should recognise the thread from the subject alone, so it is
  # the ticket header rather than whatever an agent typed.
  describe 'the subject of an ordinary message' do
    it 'is the ticket header, not what the caller sent' do
      communication = with_smtp { perform(closing: false, subject: 'qualquer coisa') }

      expect(communication.subject).to eq(ticket.display_subject)
      expect(communication.subject).not_to eq('qualquer coisa')
    end

    it 'carries the number, the Empresa, the Solicitante and the title' do
      communication = with_smtp { perform(closing: false) }

      expect(communication.subject).to eq(
        "##{ticket.display_id} - [#{company.name}] | [#{contact.name}] | [#{ticket.title}]"
      )
    end

    it 'is what the e-mail is actually titled with' do
      with_smtp { perform(closing: false) }

      expect(ActionMailer::Base.deliveries.last.subject).to eq(ticket.display_subject)
    end

    # The closing notice is a separate message and keeps its own subject.
    it 'leaves the closing notice subject alone' do
      communication = with_smtp { perform(closing: true, subject: 'Encerramento do chamado') }

      expect(communication.subject).to eq('Encerramento do chamado')
    end
  end

  describe 'when the delivery fails' do
    before do
      allow(TicketCustomerMailer).to receive(:with).and_raise(Net::SMTPServerBusy, 'mailbox unavailable')
    end

    it 'raises rather than reporting success' do
      expect { perform }.to raise_error(Net::SMTPServerBusy)
    end

    it 'keeps the attempt with its reason' do
      expect { perform }.to raise_error(Net::SMTPServerBusy)

      communication = ticket.ticket_customer_communications.last
      expect(communication.status).to eq('failed')
      expect(communication.error_message).to include('mailbox unavailable')
      expect(communication.sent_at).to be_nil
    end

    # The rule that matters: a failed message must leave the ticket closable by
    # nobody.
    it 'leaves the ticket open and still blocked' do
      ticket.update!(service_catalog_item: create(:service_catalog_item))
      expect { perform }.to raise_error(Net::SMTPServerBusy)

      expect(ticket.reload.status).to eq('open')
      expect(ticket.closeable?).to be(false)
      expect { ticket.close! }.to raise_error(TicketClosing::NotAllowed)
    end

    it 'writes no history entry for a message that never left' do
      expect { perform }.to raise_error(Net::SMTPServerBusy)

      expect(ticket.ticket_activities.where(activity_type: :customer_communication_sent)).to be_empty
    end
  end
end
