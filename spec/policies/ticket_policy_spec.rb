require 'rails_helper'

RSpec.describe TicketPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:ticket_column) { create(:ticket_column, team: team) }

  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }
  let(:other_agent_context) { { user: other_agent, account: account, account_user: other_agent.account_users.find_by(account: account) } }

  let(:ticket) { create(:ticket, ticket_column: ticket_column) }

  permissions :index?, :show?, :create? do
    it 'allows any agent of the account' do
      expect(subject).to permit(agent_context, ticket)
    end
  end

  permissions :update?, :move?, :assign?, :resolve?, :reopen?, :close? do
    context 'when user is an administrator' do
      it 'allows' do
        expect(subject).to permit(administrator_context, ticket)
      end
    end

    context 'when user is the ticket assignee' do
      let(:ticket) { create(:ticket, ticket_column: ticket_column, assignee: agent) }

      it 'allows' do
        expect(subject).to permit(agent_context, ticket)
      end
    end

    context 'when user is a member of the ticket team' do
      let(:ticket) { create(:ticket, ticket_column: ticket_column, team: team) }

      before { create(:team_member, team: team, user: agent) }

      it 'allows' do
        expect(subject).to permit(agent_context, ticket)
      end
    end

    context 'when user is neither administrator, assignee nor team member' do
      it 'denies' do
        expect(subject).not_to permit(other_agent_context, ticket)
      end
    end
  end

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows' do
        expect(subject).to permit(administrator_context, ticket)
      end
    end

    context 'when user is a regular agent' do
      it 'denies' do
        expect(subject).not_to permit(agent_context, ticket)
      end
    end
  end
end
