require 'rails_helper'

RSpec.describe Tickets::CustomerNoticeService do
  let(:account) { create(:account) }
  let(:dev_team) { create(:team, account: account, name: 'desenvolvimento') }
  let(:support_team) { create(:team, account: account, name: 'suporte') }
  let(:column) { create(:ticket_column, team: dev_team, name: 'Melhoria aprovada') }
  let(:company) { create(:company, account: account) }
  let(:email) { 'renan@empresa.com' }
  let(:contact) { create(:contact, account: account, company: company, email: email) }
  let(:ticket) do
    create(:ticket, account: account, ticket_column: column, team: dev_team, company: company, contact: contact)
  end

  let(:communication_service) { instance_double(Tickets::CustomerCommunicationService, perform: true) }

  before do
    allow(Tickets::CustomerCommunicationService).to receive(:new).and_return(communication_service)
  end

  def create_rule(**attrs)
    TicketCustomerNoticeRule.create!({ account: account, kind: 'stage', name: 'Aviso',
                                       body: 'Ticket #{{numero}} em {{estagio}}', ticket_column: column }.merge(attrs))
  end

  def perform(**args)
    described_class.new(ticket: ticket, column_id: column.id, **args).perform
  end

  it 'sends the rendered message of the stage the ticket entered' do
    create_rule

    perform

    expect(Tickets::CustomerCommunicationService).to have_received(:new).with(
      ticket: ticket, user: nil, closing: false, notify_customer: true,
      body: "Ticket ##{ticket.display_id} em Melhoria aprovada"
    )
    expect(communication_service).to have_received(:perform)
  end

  it 'only registers the message when the rule does not email the customer' do
    create_rule(notify_customer: false)

    perform

    expect(Tickets::CustomerCommunicationService).to have_received(:new).with(hash_including(notify_customer: false))
  end

  it 'sends the Mesa message with the previous Mesa name' do
    create_rule(kind: 'team', ticket_column: nil, team: dev_team, body: 'Veio de {{mesa_anterior}}')

    perform(from_team_id: support_team.id, to_team_id: dev_team.id)

    expect(Tickets::CustomerCommunicationService).to have_received(:new).with(hash_including(body: 'Veio de Suporte'))
  end

  it 'does nothing when no rule matches' do
    create_rule(ticket_column: create(:ticket_column, team: dev_team))

    perform

    expect(Tickets::CustomerCommunicationService).not_to have_received(:new)
  end

  context 'when the requester has no e-mail' do
    let(:email) { nil }

    it 'sends nothing' do
      create_rule

      perform

      expect(Tickets::CustomerCommunicationService).not_to have_received(:new)
    end
  end

  it 'keeps going when one rule fails' do
    create_rule(name: 'Primeira')
    create_rule(name: 'Segunda')
    allow(communication_service).to receive(:perform).and_invoke(-> { raise StandardError, 'smtp fora' }, -> { true })
    allow(ChatwootExceptionTracker).to receive(:new).and_return(instance_double(ChatwootExceptionTracker, capture_exception: true))

    expect { perform }.not_to raise_error
    expect(Tickets::CustomerCommunicationService).to have_received(:new).twice
  end
end
