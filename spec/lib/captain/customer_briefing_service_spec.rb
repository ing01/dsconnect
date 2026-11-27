require 'rails_helper'

RSpec.describe Captain::CustomerBriefingService do
  let(:account) { create(:account) }
  let(:service) { described_class.new(account: account, material: 'Contato atendido: Maria') }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:mock_context) { instance_double(RubyLLM::Context, chat: mock_chat) }
  let(:answer) do
    { 'overview' => 'Cliente com erro de nota.', 'recent_topics' => ['NFS-e'], 'pending_items' => ['#1 aberto'],
      'attention_points' => [] }
  end

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    allow(Llm::Config).to receive(:with_api_key).and_yield(mock_context)
    allow(mock_chat).to receive(:with_instructions)
    allow(mock_chat).to receive(:with_schema)
    allow(account).to receive(:feature_enabled?).and_call_original
    allow(account).to receive(:feature_enabled?).with('captain_tasks').and_return(true)
  end

  def reply_with(content)
    response = instance_double(RubyLLM::Message, content: content, input_tokens: 10, output_tokens: 5)
    allow(mock_chat).to receive(:ask).and_return(response)
    service.perform
  end

  it 'sends the prompt, the material and the strict schema' do
    reply_with(answer)

    expect(mock_chat).to have_received(:with_instructions).with(a_string_including('Reply in Brazilian Portuguese'))
    expect(mock_chat).to have_received(:with_schema).with(described_class::SCHEMA)
    expect(mock_chat).to have_received(:ask).with('Contato atendido: Maria')
  end

  it 'asks for every field and no other, as the provider requires' do
    expect(described_class::SCHEMA[:required]).to match_array(described_class::SCHEMA[:properties].keys.map(&:to_s))
    expect(described_class::SCHEMA[:additionalProperties]).to be(false)
  end

  it 'accepts a structured answer' do
    expect(reply_with(answer)[:message]).to eq(answer)
  end

  it 'accepts an answer in JSON text, even inside a code block' do
    expect(reply_with("```json\n#{answer.to_json}\n```")[:message]).to eq(answer)
  end

  it 'drops blank and non text items and limits the size of each list' do
    result = reply_with(answer.merge('recent_topics' => [' a ', '', nil, 3, *('b'..'j')], 'pending_items' => 'solto'))

    expect(result[:message]['recent_topics']).to eq(%w[a b c d e f])
    expect(result[:message]['pending_items']).to eq(['solto'])
  end

  it 'rejects an answer that is not JSON' do
    expect(reply_with('não sei')).to eq(error: 'invalid_ai_response')
  end

  it 'rejects an empty answer' do
    empty = { 'overview' => ' ', 'recent_topics' => [], 'pending_items' => [], 'attention_points' => [] }

    expect(reply_with(empty)).to eq(error: 'invalid_ai_response')
  end

  it 'returns the provider failure' do
    allow(mock_chat).to receive(:ask).and_raise(StandardError, 'rate limit')

    expect(service.perform[:error]).to eq('rate limit')
  end
end
