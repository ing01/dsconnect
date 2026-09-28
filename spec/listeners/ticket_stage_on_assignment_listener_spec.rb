require 'rails_helper'

describe TicketStageOnAssignmentListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:normal_column) { create(:ticket_column, team: team, kind: 'normal', name: 'Aguardando') }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, assignee: nil) }

  let(:ticket) { create(:ticket, ticket_column: normal_column) }

  before do
    team.add_members([agent.id])
    create(:ticket_conversation, ticket: ticket, conversation: conversation, account: account)
  end

  def dispatch_assignee_changed
    event = Events::Base.new(:'conversation.assignee_changed', Time.zone.now, conversation: conversation)
    listener.assignee_changed(event)
  end

  context 'when the team has an in_progress column configured' do
    let!(:in_progress_column) { create(:ticket_column, team: team, kind: 'in_progress', name: 'Em atendimento') }

    it 'moves the linked ticket into it once the conversation is assigned' do
      conversation.update!(assignee: agent)

      dispatch_assignee_changed

      expect(ticket.reload.ticket_column_id).to eq(in_progress_column.id)
    end

    it 'does nothing when the conversation has no assignee' do
      dispatch_assignee_changed

      expect(ticket.reload.ticket_column_id).to eq(normal_column.id)
    end

    it 'does not move a ticket that is already resolved' do
      ticket.update!(status: :resolved)
      conversation.update!(assignee: agent)

      dispatch_assignee_changed

      expect(ticket.reload.ticket_column_id).to eq(normal_column.id)
    end

    it 'does not move a ticket still pending triage' do
      ticket.update!(pending_triage: true)
      conversation.update!(assignee: agent)

      dispatch_assignee_changed

      expect(ticket.reload.ticket_column_id).to eq(normal_column.id)
    end

    it 'does not raise and does not move the ticket when the target column has unmet rules' do
      in_progress_column.update!(require_assignee: true)
      conversation.update!(assignee: agent)
      expect(ticket.assignee_id).to be_nil

      expect { dispatch_assignee_changed }.not_to raise_error
      expect(ticket.reload.ticket_column_id).to eq(normal_column.id)
    end
  end

  context 'when the team has no in_progress column configured' do
    it 'leaves the ticket where it is' do
      conversation.update!(assignee: agent)

      dispatch_assignee_changed

      expect(ticket.reload.ticket_column_id).to eq(normal_column.id)
    end
  end
end
