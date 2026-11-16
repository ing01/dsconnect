# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoodEntryPolicy, type: :policy do
  subject(:mood_entry_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:manager) { create(:user, account: account) }

  let(:administrator_context) do
    { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) }
  end
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }
  let(:manager_context) { { user: manager, account: account, account_user: manager.account_users.find_by(account: account) } }

  before do
    role = create(:custom_role, account: account, permissions: ['mood_checkin_manage'])
    manager.account_users.find_by(account: account).update!(custom_role: role)
  end

  permissions :index? do
    it { expect(mood_entry_policy).to permit(administrator_context, :mood_entry) }
    it { expect(mood_entry_policy).to permit(manager_context, :mood_entry) }
    it { expect(mood_entry_policy).not_to permit(agent_context, :mood_entry) }
  end

  permissions :create?, :today? do
    it { expect(mood_entry_policy).to permit(agent_context, :mood_entry) }
  end
end
