require 'rails_helper'

RSpec.describe Team do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:conversations) }
    it { is_expected.to have_many(:team_members) }
    it { is_expected.to have_many(:tickets) }
    it { is_expected.to have_many(:ticket_columns) }
  end

  describe '#provision_default_ticket_columns' do
    it 'creates the default Kanban stages (Estagios) for a newly created Mesa' do
      team = create(:team)

      expect(team.ticket_columns.order(:position).pluck(:name)).to eq(
        ['Pendente', 'Em andamento', 'Finalizado']
      )
      expect(team.ticket_columns.order(:position).pluck(:kind)).to eq(%w[pending normal completed])
    end
  end

  describe 'name normalization' do
    let(:account) { create(:account) }

    it 'capitalizes only the first letter, leaving the rest untouched' do
      team = create(:team, account: account, name: 'customer Support')
      expect(team.name).to eq('Customer Support')
    end

    it 'leaves an already-capitalized name as is' do
      team = create(:team, account: account, name: 'Suporte')
      expect(team.name).to eq('Suporte')
    end

    it 'strips control characters and surrounding whitespace' do
      team = create(:team, account: account, name: "  sales\n")
      expect(team.name).to eq('Sales')
    end

    it 'removes control characters embedded within the name' do
      team = create(:team, account: account, name: "su\npport")
      expect(team.name).to eq('Support')
    end

    it 'is invalid when the name reduces to blank after sanitization' do
      team = build(:team, account: account, name: "\t\n  ")
      expect(team).not_to be_valid
      expect(team.errors[:name]).to include(I18n.t('errors.validations.presence'))
    end

    it 'rejects a name that differs from an existing Mesa only by case' do
      create(:team, account: account, name: 'Suporte')
      duplicate = build(:team, account: account, name: 'SUPORTE')

      expect(duplicate).not_to be_valid
    end
  end

  describe '#add_members' do
    let(:team) { FactoryBot.create(:team) }

    before do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'handles adds all members and resets cache keys' do
      users = FactoryBot.create_list(:user, 3)
      team.add_members(users.map(&:id))
      expect(team.reload.team_members.size).to eq(3)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).at_least(:once)
                                                                        .with(
                                                                          'account.cache_invalidated',
                                                                          kind_of(Time),
                                                                          account: team.account,
                                                                          cache_keys: team.account.cache_keys
                                                                        )
    end
  end

  describe '#remove_members' do
    let(:team) { FactoryBot.create(:team) }
    let(:users) { FactoryBot.create_list(:user, 3) }

    before do
      team.add_members(users.map(&:id))
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'removes the members and resets cache keys' do
      expect(team.reload.team_members.size).to eq(3)

      team.remove_members(users.map(&:id))
      expect(team.reload.team_members.size).to eq(0)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).at_least(:once)
                                                                        .with(
                                                                          'account.cache_invalidated',
                                                                          kind_of(Time),
                                                                          account: team.account,
                                                                          cache_keys: team.account.cache_keys
                                                                        )
    end
  end
end
