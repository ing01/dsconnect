require 'rails_helper'

RSpec.describe TicketActivityPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }
  let(:activity) { create(:ticket_activity, account: account) }

  permissions :index? do
    it 'allows any agent of the account' do
      expect(subject).to permit(agent_context, activity)
    end
  end
end
