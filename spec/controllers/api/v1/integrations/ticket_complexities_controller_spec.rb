require 'rails_helper'

RSpec.describe 'Ticket Complexities Integration API', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }

  describe 'GET /api/v1/integrations/ticket_complexities' do
    it 'rejects a request without a key' do
      get '/api/v1/integrations/ticket_complexities'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists only the active complexities of the key\'s own account' do
      ativa = create(:ticket_complexity, account: account, name: 'Baixa')
      create(:ticket_complexity, account: account, name: 'Desligada', active: false)
      create(:ticket_complexity) # outra conta

      get '/api/v1/integrations/ticket_complexities', headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq([{ 'id' => ativa.id, 'name' => 'Baixa' }])
    end
  end
end
