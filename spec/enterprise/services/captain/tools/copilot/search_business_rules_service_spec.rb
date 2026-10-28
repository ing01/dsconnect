require 'rails_helper'

RSpec.describe Captain::Tools::Copilot::SearchBusinessRulesService do
  let(:account) { create(:account) }
  let(:user) { create(:user, :administrator, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:service) { described_class.new(assistant, user: user) }

  describe '#name' do
    it 'returns the correct service name' do
      expect(service.name).to eq('search_business_rules')
    end
  end

  describe '#active?' do
    it 'is off while DueRules is not configured' do
      allow(Duerules::Client).to receive(:configured?).and_return(false)

      expect(service.active?).to be(false)
    end

    it 'is on for an agent once DueRules is configured' do
      allow(Duerules::Client).to receive(:configured?).and_return(true)

      expect(service.active?).to be(true)
    end
  end

  describe '#execute' do
    let(:client) { instance_double(Duerules::Client) }

    before { allow(Duerules::Client).to receive(:new).and_return(client) }

    it 'asks the base and returns what it answered' do
      allow(client).to receive(:call_tool).with('buscar_regras', pergunta: 'nota', cliente: nil, limite: nil)
                                          .and_return('{"regras":[]}')

      expect(service.execute(question: 'nota')).to eq('{"regras":[]}')
    end

    it 'tells the copilot not to invent the rule when the base is out of reach' do
      allow(client).to receive(:call_tool).and_raise(Duerules::Client::Error, 'sem rede')

      expect(service.execute(question: 'nota')).to include('nao invente')
    end
  end
end
