require 'rails_helper'

RSpec.describe 'Service Catalog Items Integration API', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }

  describe 'GET /api/v1/integrations/service_catalog_items' do
    it 'rejects a request without a key' do
      get '/api/v1/integrations/service_catalog_items'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the 3-level tree (catalog > area > item), active only' do
      catalogo = create(:service_catalog, account: account, name: 'DS Comercial')
      area = create(:service_catalog_area, service_catalog: catalogo, name: 'Movimentações')
      item = create(:service_catalog_item, service_catalog_area: area, name: 'Notas Fiscais')
      area_desligada = create(:service_catalog_area, service_catalog: catalogo, name: 'Antiga', active: false)
      create(:service_catalog_item, service_catalog_area: area_desligada, name: 'Fora')

      get '/api/v1/integrations/service_catalog_items', headers: headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.length).to eq(1)
      expect(body.first['name']).to eq('DS Comercial')
      expect(body.first['areas'].length).to eq(1)
      expect(body.first['areas'].first['name']).to eq('Movimentações')
      expect(body.first['areas'].first['items']).to eq([{ 'id' => item.id, 'name' => 'Notas Fiscais' }])
    end
  end
end
