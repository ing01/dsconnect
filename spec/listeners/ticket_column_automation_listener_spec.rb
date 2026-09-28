require 'rails_helper'

describe TicketColumnAutomationListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) do
    create(:ticket_column, team: team, automations_enabled: true,
                            automation_actions: [{ 'type' => 'post_note', 'value' => 'oi' }])
  end
  let(:ticket) { create(:ticket, ticket_column: column) }

  before { Thread.current[:ticket_column_automation_depth] = nil }
  after { Thread.current[:ticket_column_automation_depth] = nil }

  def event_for(ticket)
    Events::Base.new(:'ticket.moved', Time.zone.now, ticket: ticket)
  end

  it 'runs the column automation service for a normal move' do
    expect(Tickets::ColumnAutomationService).to receive(:new)
      .with(ticket: ticket, ticket_column: column).and_call_original

    listener.ticket_moved(event_for(ticket))
  end

  it 'does nothing when the column has no automation configured' do
    plain_column = create(:ticket_column, team: team)
    plain_ticket = create(:ticket, ticket_column: plain_column)

    expect(Tickets::ColumnAutomationService).not_to receive(:new)

    listener.ticket_moved(event_for(plain_ticket))
  end

  it 'stops a runaway automation chain instead of recursing forever' do
    call_count = 0

    # Simulates `move_parent_to_column` re-entering the listener synchronously,
    # over and over - exactly what a misconfigured pair of Estagios would do.
    service = instance_double(Tickets::ColumnAutomationService)
    allow(Tickets::ColumnAutomationService).to receive(:new).and_return(service)
    allow(service).to receive(:perform) do
      call_count += 1
      listener.ticket_moved(event_for(ticket))
    end

    expect(ChatwootExceptionTracker).to receive(:new).once.and_call_original

    listener.ticket_moved(event_for(ticket))

    expect(call_count).to eq(TicketColumnAutomationListener::MAX_AUTOMATION_CHAIN_DEPTH)
  end

  it 'resets the depth counter after the chain finishes, so the next unrelated move starts fresh' do
    listener.ticket_moved(event_for(ticket))

    expect(Thread.current[:ticket_column_automation_depth]).to eq(0)
  end
end
