require 'rails_helper'

RSpec.describe Tickets::DefaultMesaBuilder do
  let(:account) { create(:account) }

  describe '#perform' do
    context 'when the account has no Mesa' do
      it 'provisions a Mesa named suporte' do
        expect { described_class.new(account: account).perform }.to change(account.teams, :count).by(1)
        expect(account.teams.last.name).to eq('suporte')
      end

      it 'provisions the default Estagios in order' do
        mesa = described_class.new(account: account).perform

        expect(mesa.ticket_columns.pluck(:name)).to eq(['A fazer', 'Em andamento', 'Concluído'])
        expect(mesa.ticket_columns.pluck(:position)).to eq([0, 1, 2])
      end
    end

    context 'when the account already has a Mesa' do
      let!(:existing_mesa) { create(:team, account: account, name: 'implantação') }

      it 'returns the existing Mesa without creating another' do
        expect { described_class.new(account: account).perform }.not_to change(account.teams, :count)
        expect(described_class.new(account: account).perform).to eq(existing_mesa)
      end

      it 'does not rename the existing Mesa' do
        described_class.new(account: account).perform

        expect(existing_mesa.reload.name).to eq('implantação')
        expect(account.teams.pluck(:name)).not_to include('suporte')
      end
    end

    it 'is idempotent across repeated calls' do
      expect do
        2.times { described_class.new(account: account).perform }
      end.to change(Team, :count).by(1)
    end

    it 'scopes the default Mesa per account' do
      other_account = create(:account)

      described_class.new(account: account).perform
      described_class.new(account: other_account).perform

      expect(account.teams.pluck(:name)).to eq(['suporte'])
      expect(other_account.teams.pluck(:name)).to eq(['suporte'])
    end

    it 'recovers when another request wins the race to create the Mesa' do
      winner = nil
      # Stands in for a concurrent request that inserted the row between our
      # emptiness check and our own INSERT, which Postgres then rejects.
      allow(account.teams).to receive(:create!) do
        winner = Team.create!(account: account, name: 'suporte')
        raise ActiveRecord::RecordNotUnique
      end

      expect(described_class.new(account: account).perform).to eq(winner)
    end
  end
end
