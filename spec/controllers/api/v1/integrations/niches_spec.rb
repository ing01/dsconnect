require 'rails_helper'

# Nicho e Sub-nicho nas empresas (GET /companies) e nos agentes (GET /users): e' o par que a IA
# usa para decidir quem atende um ticket.
RSpec.describe 'Ticket Integration API - nichos', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }

  let!(:varejo) { CompanyNiche.create!(account: account, name: 'Varejo') }
  let!(:industria) { CompanyNiche.create!(account: account, name: 'Indústria') }
  let!(:padaria) { CompanySubNiche.create!(account: account, name: 'Padaria') }
  let!(:ana) { create(:user, account: account, role: :agent, name: 'Ana') }
  let!(:bia) { create(:user, account: account, role: :agent, name: 'Bia') }

  before do
    UserCompanyNiche.create!(account: account, user: ana, company_niche: varejo)
    UserCompanySubNiche.create!(account: account, user: ana, company_sub_niche: padaria)
    UserCompanyNiche.create!(account: account, user: bia, company_niche: industria)
  end

  describe 'GET /companies' do
    let!(:alfa) { create(:company, account: account, name: 'Alfa', company_niche: varejo, company_sub_niche: padaria) }
    let!(:beta) { create(:company, account: account, name: 'Beta') }

    it 'brings the niche and sub-niche of each company, null when missing' do
      get '/api/v1/integrations/companies', headers: headers

      payload = response.parsed_body['payload']
      expect(payload.find { |c| c['id'] == alfa.id }).to include(
        'niche' => { 'id' => varejo.id, 'name' => 'Varejo' },
        'sub_niche' => { 'id' => padaria.id, 'name' => 'Padaria' }
      )
      expect(payload.find { |c| c['id'] == beta.id }).to include('niche' => nil, 'sub_niche' => nil)
    end

    it 'brings them on a single company too' do
      get "/api/v1/integrations/companies/#{alfa.id}", headers: headers

      expect(response.parsed_body['niche']).to eq('id' => varejo.id, 'name' => 'Varejo')
    end

    it 'filters by niche_id and sub_niche_id' do
      get '/api/v1/integrations/companies', params: { niche_id: varejo.id }, headers: headers
      expect(response.parsed_body['payload'].pluck('id')).to eq([alfa.id])

      get '/api/v1/integrations/companies', params: { sub_niche_id: padaria.id }, headers: headers
      expect(response.parsed_body['payload'].pluck('id')).to eq([alfa.id])
    end
  end

  describe 'GET /users' do
    it 'brings the niches and sub-niches each user covers' do
      get '/api/v1/integrations/users', headers: headers

      users = response.parsed_body
      expect(users.find { |u| u['id'] == ana.id }).to include(
        'niches' => [{ 'id' => varejo.id, 'name' => 'Varejo' }],
        'sub_niches' => [{ 'id' => padaria.id, 'name' => 'Padaria' }]
      )
      expect(users.find { |u| u['id'] == bia.id }).to include('sub_niches' => [])
    end

    it 'brings them on a single user too' do
      get "/api/v1/integrations/users/#{ana.id}", headers: headers

      expect(response.parsed_body['niches'].pluck('name')).to eq(['Varejo'])
    end

    it 'filters by niche_id and sub_niche_id' do
      get '/api/v1/integrations/users', params: { niche_id: industria.id }, headers: headers
      expect(response.parsed_body.pluck('id')).to eq([bia.id])

      get '/api/v1/integrations/users', params: { sub_niche_id: padaria.id }, headers: headers
      expect(response.parsed_body.pluck('id')).to eq([ana.id])
    end

    it 'does not leak the niches of another account' do
      outra = create(:account)
      estranho = create(:user, account: outra, role: :agent)
      UserCompanyNiche.create!(account: outra, user: estranho, company_niche: CompanyNiche.create!(account: outra, name: 'Varejo'))

      get '/api/v1/integrations/users', params: { niche_id: varejo.id }, headers: headers

      expect(response.parsed_body.pluck('id')).to eq([ana.id])
    end
  end
end
