require 'rails_helper'

RSpec.describe TicketCommentPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }

  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }
  let(:other_agent_context) { { user: other_agent, account: account, account_user: other_agent.account_users.find_by(account: account) } }

  let(:ticket_column) { create(:ticket_column, team: create(:team, account: account)) }
  let(:ticket) { create(:ticket, ticket_column: ticket_column) }
  let(:comment) { create(:ticket_comment, account: account, ticket: ticket, user: agent) }

  permissions :index?, :create? do
    it 'allows any agent of the account' do
      expect(subject).to permit(agent_context, comment)
    end
  end

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows' do
        expect(subject).to permit(administrator_context, comment)
      end
    end

    context 'when user is the comment author' do
      it 'allows' do
        expect(subject).to permit(agent_context, comment)
      end
    end

    context 'when user is neither the author nor an administrator' do
      it 'denies' do
        expect(subject).not_to permit(other_agent_context, comment)
      end
    end
  end
end
