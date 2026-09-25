require 'rails_helper'

RSpec.describe Captain::Llm::TriagePriorityClassifierService do
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
    # Cenario 1: sistema fora do ar - prioridade alta.
    it 'classifica como alta quando o problema tem impacto critico' do
      allow(mock_chat).to receive(:ask).and_return(
        mock_response('prioridade' => 'alta', 'resumo_problema' => 'Sistema fora do ar', 'acao_sugerida' => 'Verificar servidor')
      )

      result = service.classify(transcript: 'Cliente: o sistema caiu, ninguém consegue trabalhar')

      expect(result).to include('prioridade' => 'alta', 'resumo_problema' => 'Sistema fora do ar')
    end

    # Cenario 2: funcionalidade especifica com alternativa - prioridade media.
    it 'classifica como media quando o problema afeta parte da operacao mas tem contorno' do
      allow(mock_chat).to receive(:ask).and_return(
        mock_response('prioridade' => 'media', 'resumo_problema' => 'Relatório de vendas não carrega', 'acao_sugerida' => 'Checar filtro de data')
      )

      result = service.classify(transcript: 'Cliente: o relatório de vendas não abre, mas consigo ver pelo financeiro')

      expect(result['prioridade']).to eq('media')
    end

    # Cenario 3: duvida de uso - prioridade baixa.
    it 'classifica como baixa quando e uma duvida sem impacto critico' do
      allow(mock_chat).to receive(:ask).and_return(
        mock_response('prioridade' => 'baixa', 'resumo_problema' => 'Dúvida sobre cadastro de produto', 'acao_sugerida' => 'Orientar o cliente')
      )

      result = service.classify(transcript: 'Cliente: como eu cadastro um produto novo?')

      expect(result['prioridade']).to eq('baixa')
    end

    # Cenario 8: descricao longa - so passa o transcript adiante, sem mudar
    # a logica de classificacao.
    it 'classifica normalmente com uma descricao longa do problema' do
      transcript = "Cliente: #{'o sistema trava toda vez que eu tento emitir uma nota fiscal e isso já aconteceu ' * 5}"
      allow(mock_chat).to receive(:ask) do |prompt|
        expect(prompt).to eq(transcript)
        mock_response('prioridade' => 'alta', 'resumo_problema' => 'Emissão fiscal bloqueada', 'acao_sugerida' => 'Escalar para o time fiscal')
      end

      result = service.classify(transcript: transcript)

      expect(result['prioridade']).to eq('alta')
    end

    # Cenario 9: descricao curta - a IA ainda classifica direto, sem pedir
    # mais detalhes (o prompt instrui a nao perguntar mais nada).
    it 'classifica normalmente com uma descricao curta do problema' do
      allow(mock_chat).to receive(:ask).and_return(
        mock_response('prioridade' => 'baixa', 'resumo_problema' => 'Solicitação de melhoria', 'acao_sugerida' => 'Registrar sugestão')
      )

      result = service.classify(transcript: 'Cliente: sugestão de melhoria')

      expect(result['prioridade']).to eq('baixa')
    end

    it 'nunca estoura excecao quando a IA responde fora do formato esperado' do
      allow(mock_chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: 'isso não é json'))

      result = service.classify(transcript: 'Cliente: algo aconteceu')

      expect(result['error']).to be_present
      expect(result['prioridade']).to be_nil
    end

    it 'nunca estoura excecao quando a IA responde com uma prioridade invalida' do
      allow(mock_chat).to receive(:ask).and_return(mock_response('prioridade' => 'urgentissima'))

      result = service.classify(transcript: 'Cliente: algo aconteceu')

      expect(result['error']).to eq('invalid_classifier_response')
    end
  end
end
