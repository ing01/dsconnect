require 'rails_helper'

RSpec.describe Captain::Llm::ProblemClarityClassifierService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:service) { described_class.new(conversation: conversation) }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }

  def mock_response(payload)
    instance_double(RubyLLM::Message, content: payload.to_json)
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:with_params).and_return(mock_chat)
    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
  end

  describe '#classify' do
    it 'classifica como nao claro um pedido generico de ajuda' do
      allow(mock_chat).to receive(:ask).and_return(mock_response('claro' => false))

      result = service.classify(transcript: 'Cliente: preciso de ajuda')

      expect(result['claro']).to be false
    end

    it 'classifica como nao claro quando so cita o nome de um modulo' do
      allow(mock_chat).to receive(:ask).and_return(mock_response('claro' => false))

      result = service.classify(transcript: 'Cliente: financeiro')

      expect(result['claro']).to be false
    end

    it 'classifica como claro uma descricao curta mas especifica' do
      allow(mock_chat).to receive(:ask).and_return(mock_response('claro' => true))

      result = service.classify(transcript: 'Cliente: o sistema caiu')

      expect(result['claro']).to be true
    end

    it 'nunca estoura excecao quando a IA responde fora do formato esperado' do
      allow(mock_chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: 'nao e json'))

      result = service.classify(transcript: 'Cliente: algo')

      expect(result['claro']).to be_nil
    end
  end
end
