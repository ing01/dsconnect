require 'rails_helper'

# O limite de chamadas da API de Integracao de Tickets: 120 requisicoes por minuto
# POR CHAVE (RATE_LIMIT_INTEGRATIONS_API altera). Passou disso, 429 com JSON e o
# cabecalho Retry-After. O Rack::Attack fica desligado nos testes; aqui ele e'
# ligado, com um cache proprio para nao vazar contagem entre exemplos.
RSpec.describe 'Ticket Integration API - rate limit', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }

  around do |example|
    enabled = Rack::Attack.enabled
    store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.enabled = enabled
    Rack::Attack.cache.store = store
  end

  def exceed_the_limit
    120.times { get '/api/v1/integrations/teams', headers: headers }
    get '/api/v1/integrations/teams', headers: headers
  end

  it 'answers normally up to 120 requests in the minute' do
    120.times do
      get '/api/v1/integrations/teams', headers: headers
      expect(response).to have_http_status(:success)
    end
  end

  it 'answers 429 with a JSON body and Retry-After on the 121st request' do
    exceed_the_limit

    expect(response).to have_http_status(:too_many_requests)
    expect(response.media_type).to eq('application/json')
    expect(response.parsed_body).to include('error' => 'rate_limit_exceeded', 'limit' => 120, 'period_seconds' => 60)
    expect(response.parsed_body['retry_after']).to be_between(0, 60)
    expect(response.headers['Retry-After'].to_i).to eq(response.parsed_body['retry_after'])
  end

  # O limite e' por CHAVE: uma conta estourando o dela nao tira a outra do ar.
  it 'counts each key separately' do
    exceed_the_limit
    outra = create(:ticket_api_key, account: create(:account))

    get '/api/v1/integrations/teams', headers: { 'X-Ticket-Api-Key' => outra.token }

    expect(response).to have_http_status(:success)
  end
end
