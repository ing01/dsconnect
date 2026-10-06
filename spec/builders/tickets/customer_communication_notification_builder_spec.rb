require 'rails_helper'

RSpec.describe Tickets::CustomerCommunicationNotificationBuilder do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:assignee) { create(:user, account: account, role: :agent) }
  let(:follower) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team, assignee: assignee) }
  let(:communication) { create(:ticket_customer_communication, ticket: ticket, direction: 'inbound') }

  def perform
    described_class.new(communication: communication).perform
  end

  it 'avisa o responsavel pelo ticket' do
    expect { perform }.to change { assignee.notifications.count }.by(1)

    aviso = assignee.notifications.last
    expect(aviso.notification_type).to eq('ticket_customer_communication_received')
    expect(aviso.primary_actor).to eq(ticket)
    expect(aviso.secondary_actor).to eq(communication)
  end

  it 'avisa quem segue o ticket' do
    create(:ticket_follower, ticket: ticket, user: follower)

    expect { perform }.to change { follower.notifications.count }.by(1)
  end

  it 'nao avisa quem nao e responsavel nem segue o ticket' do
    create(:ticket_follower, ticket: ticket, user: follower)

    expect { perform }.not_to(change { outsider.notifications.count })
  end

  it 'nao duplica aviso para quem e responsavel E segue' do
    create(:ticket_follower, ticket: ticket, user: assignee)

    expect { perform }.to change { assignee.notifications.count }.by(1)
  end

  it 'nao quebra quando o ticket nao tem responsavel nem seguidor' do
    ticket.update!(assignee: nil)

    expect { perform }.not_to raise_error
  end
end
