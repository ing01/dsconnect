require 'rails_helper'

RSpec.describe Duerules::Client do
  let(:url) { 'https://duerules.test:8090/mcp' }
  let(:client) { described_class.new }

  def sse(text, extra = {})
    body = { result: { content: [{ type: 'text', text: text }] }.merge(extra), jsonrpc: '2.0', id: 1 }.to_json
    "event: message\ndata: #{body}\n\n"
  end

  context 'when it is not configured' do
    before do
      allow(GlobalConfigService).to receive(:load).and_call_original
      allow(GlobalConfigService).to receive(:load).with('DUERULES_URL', nil).and_return(nil)
      allow(GlobalConfigService).to receive(:load).with('DUERULES_TOKEN', nil).and_return(nil)
    end

    it 'reports it and refuses to call' do
      expect(client.configured?).to be(false)
      expect { client.call_tool('buscar_regras', pergunta: 'x') }.to raise_error(Duerules::Client::Error)
    end
  end

  context 'when it is configured' do
    before do
      allow(GlobalConfigService).to receive(:load).and_call_original
      allow(GlobalConfigService).to receive(:load).with('DUERULES_URL', nil).and_return(url)
      allow(GlobalConfigService).to receive(:load).with('DUERULES_TOKEN', nil).and_return('dsrag_teste')
    end

    it 'calls a tool with the token and returns the text from the SSE answer' do
      stub = stub_request(:post, url)
             .with(headers: { 'Authorization' => 'Bearer dsrag_teste' })
             .to_return(status: 200, body: sse('{"regras":[]}'), headers: { 'Content-Type' => 'text/event-stream' })

      expect(client.call_tool('buscar_regras', pergunta: 'nota fiscal', cliente: nil)).to eq('{"regras":[]}')
      expect(stub).to have_been_requested
    end

    it 'does not send empty arguments' do
      stub_request(:post, url)
        .with { |req| JSON.parse(req.body).dig('params', 'arguments') == { 'pergunta' => 'oi' } }
        .to_return(status: 200, body: sse('ok'))

      expect(client.call_tool('buscar_regras', pergunta: 'oi', cliente: nil)).to eq('ok')
    end

    it 'uses the support token by default and the service token for the atendimento profile' do
      allow(GlobalConfigService).to receive(:load).with('DUERULES_TOKEN_ATENDIMENTO', nil).and_return('dsrag_cliente')
      support = stub_request(:post, url).with(headers: { 'Authorization' => 'Bearer dsrag_teste' })
                                        .to_return(status: 200, body: sse('suporte'))
      service = stub_request(:post, url).with(headers: { 'Authorization' => 'Bearer dsrag_cliente' })
                                        .to_return(status: 200, body: sse('atendimento'))

      expect(client.call_tool('perfil_da_empresa')).to eq('suporte')
      expect(described_class.new(profile: :atendimento).call_tool('perfil_da_empresa')).to eq('atendimento')
      expect(support).to have_been_requested.once
      expect(service).to have_been_requested.once
    end

    it 'is not configured for a profile whose token is empty' do
      allow(GlobalConfigService).to receive(:load).with('DUERULES_TOKEN_ATENDIMENTO', nil).and_return(nil)

      expect(described_class.configured?).to be(true)
      expect(described_class.configured?(profile: :atendimento)).to be(false)
    end

    it 'rejects an unknown profile' do
      expect { described_class.new(profile: :outro) }.to raise_error(ArgumentError)
    end

    it 'turns a refused token into an error' do
      stub_request(:post, url).to_return(status: 401, body: '')

      expect { client.call_tool('perfil_da_empresa') }.to raise_error(Duerules::Client::Error, /Token/)
    end

    it 'turns a tool error into an error' do
      stub_request(:post, url).to_return(status: 200, body: sse('falhou', isError: true))

      expect { client.call_tool('perfil_da_empresa') }.to raise_error(Duerules::Client::Error, 'falhou')
    end

    it 'turns a network failure into an error' do
      stub_request(:post, url).to_timeout

      expect { client.call_tool('perfil_da_empresa') }.to raise_error(Duerules::Client::Error)
    end
  end
end
