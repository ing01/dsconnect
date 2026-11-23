require 'rails_helper'

RSpec.describe CustomRole, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:account_users).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'ticket_cancel permission' do
    it 'is a valid permission for a role' do
      role = build(:custom_role, account: create(:account), permissions: %w[ticket_manage ticket_cancel])

      expect(role).to be_valid
    end
  end

  describe 'notification_view permission' do
    let(:account) { create(:account) }

    it 'is a valid permission for a role' do
      role = build(:custom_role, account: account, permissions: %w[ticket_manage notification_view])

      expect(role).to be_valid
    end

    it 'reaches the frontend through the account user permissions' do
      user = create(:user, account: account, role: :agent)
      role = create(:custom_role, account: account, permissions: %w[ticket_manage notification_view])
      account_user = account.account_users.find_by(user_id: user.id)
      account_user.update!(custom_role: role)

      expect(account_user.permissions).to include('notification_view', 'custom_role')
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_manage']) }
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:invalidator) { instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, users_visibility_changed!: true) }

    before do
      create(:account_user, account: account, user: user, custom_role: custom_role)
      create(:account_user, account: account, user: other_user, custom_role: custom_role)
      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).with(account).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'invalidates filtered counts for assigned users when permissions change' do
      custom_role.update!(permissions: ['conversation_participating_manage'])

      expect(invalidator).to have_received(:users_visibility_changed!).with(user_ids: contain_exactly(user.id, other_user.id))
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'does not invalidate filtered counts when permissions are unchanged' do
      custom_role.update!(name: 'Support manager')

      expect(invalidator).not_to have_received(:users_visibility_changed!)
    end

    it 'invalidates filtered counts for assigned users when the role is deleted' do
      custom_role.destroy!

      expect(invalidator).to have_received(:users_visibility_changed!).with(user_ids: contain_exactly(user.id, other_user.id))
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end
  end
end
