require 'rails_helper'

# Nichos e sub-nichos por agente: consulta, edicao (so' administrador) e a carga inicial dos analistas.
RSpec.describe 'Nichos por agente', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Admin') }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ingrid') }
  let!(:retail) { account.company_niches.create!(name: 'Variedades') }
  let!(:food) { account.company_niches.create!(name: 'Indústria de alimentos') }
  let!(:shop) { account.company_sub_niches.create!(name: 'Varejo') }
  let!(:bakery) { account.company_sub_niches.create!(name: 'Padaria') }
  let(:url) { "/api/v1/accounts/#{account.id}/agent_niches" }

  def update(user_id, params, as: admin)
    put "#{url}/#{user_id}", params: params, headers: as.create_new_auth_token, as: :json
  end

  describe 'GET /agent_niches' do
    it 'lists the agents with their links and the available niches and sub-niches' do
      UserCompanyNiche.create!(account: account, user: agent, company_niche: retail)
      UserCompanySubNiche.create!(account: account, user: agent, company_sub_niche: shop)

      get url, headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body['agents'].find { |a| a['id'] == agent.id }).to include('niche_ids' => [retail.id], 'sub_niche_ids' => [shop.id])
      expect(body['niches'].pluck('name')).to contain_exactly('Variedades', 'Indústria de alimentos')
      expect(body['sub_niches'].pluck('name')).to contain_exactly('Varejo', 'Padaria')
    end

    it 'requires authentication' do
      get url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not show niches or agents of another account' do
      other = create(:account)
      other.company_niches.create!(name: 'Outra conta')

      get url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['niches'].pluck('name')).not_to include('Outra conta')
    end
  end

  describe 'PUT /agent_niches/:id' do
    it 'replaces the niches and sub-niches of the agent' do
      UserCompanyNiche.create!(account: account, user: agent, company_niche: retail)

      update(agent.id, { niche_ids: [food.id], sub_niche_ids: [shop.id, bakery.id] })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('niche_ids' => [food.id], 'sub_niche_ids' => contain_exactly(shop.id, bakery.id))
      expect(UserCompanyNiche.where(user_id: agent.id).pluck(:company_niche_id)).to eq([food.id])
    end

    it 'clears everything when empty lists are sent' do
      UserCompanyNiche.create!(account: account, user: agent, company_niche: retail)

      update(agent.id, { niche_ids: [], sub_niche_ids: [] })

      expect(UserCompanyNiche.where(user_id: agent.id)).to be_empty
    end

    it 'leaves a list alone when it is not sent' do
      UserCompanySubNiche.create!(account: account, user: agent, company_sub_niche: shop)

      update(agent.id, { niche_ids: [food.id] })

      expect(UserCompanySubNiche.where(user_id: agent.id).pluck(:company_sub_niche_id)).to eq([shop.id])
    end

    it 'ignores niches of another account' do
      foreign = create(:account).company_niches.create!(name: 'Estranho')

      update(agent.id, { niche_ids: [foreign.id, retail.id] })

      expect(UserCompanyNiche.where(user_id: agent.id).pluck(:company_niche_id)).to eq([retail.id])
    end

    it 'is only for administrators' do
      update(agent.id, { niche_ids: [retail.id] }, as: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(UserCompanyNiche.count).to eq(0)
    end

    it 'answers 404 for a user of another account' do
      stranger = create(:user, account: create(:account))

      update(stranger.id, { niche_ids: [retail.id] })

      expect(response).to have_http_status(:not_found)
    end

    it 'two agents can share the same niche' do
      other = create(:user, account: account, role: :agent, name: 'Lucas Oliveira')

      update(agent.id, { sub_niche_ids: [shop.id] })
      update(other.id, { sub_niche_ids: [shop.id] })

      expect(UserCompanySubNiche.where(company_sub_niche_id: shop.id).count).to eq(2)
    end
  end

  describe CompanyNiches::AgentLinker do
    let(:links) do
      { 'Ingrid' => { niches: ['Variedades', 'Conveniência e Mercado'], sub_niches: ['Varejo', 'Varejo piscinas'] },
        'Fulana Inexistente' => { niches: ['Nao deve criar'], sub_niches: [] } }
    end

    before { agent }

    it 'links the agent, reusing what exists and creating what is missing' do
      report = described_class.new(account, links: links).perform

      expect(report).to have_attributes(linked_agents: ['Ingrid'], missing_agents: ['Fulana Inexistente'],
                                        created_niches: 1, created_sub_niches: 1, links: 4)
      expect(UserCompanyNiche.where(user_id: agent.id).count).to eq(2)
      expect(account.company_niches.pluck(:name)).to include('Conveniência e Mercado')
      expect(account.company_niches.pluck(:name)).not_to include('Nao deve criar')
    end

    it 'matches names ignoring case and accents, without duplicating a niche' do
      described_class.new(account, links: { 'ingrid' => { niches: ['VARIEDADES', 'industria de alimentos'], sub_niches: [] } }).perform

      expect(account.company_niches.count).to eq(2)
      expect(UserCompanyNiche.where(user_id: agent.id).count).to eq(2)
    end

    it 'is idempotent' do
      described_class.new(account, links: links).perform
      report = described_class.new(account, links: links).perform

      expect(report).to have_attributes(links: 0, created_niches: 0, created_sub_niches: 0)
      expect(UserCompanyNiche.count).to eq(2)
    end

    it 'does nothing when there are two agents with the same name' do
      create(:user, account: account, role: :agent, name: 'Ingrid')

      report = described_class.new(account, links: links).perform

      expect(report.linked_agents).to be_empty
      expect(UserCompanyNiche.count).to eq(0)
    end

    it 'has the five analysts of the team in the real list' do
      expect(described_class::LINKS.keys).to eq(['Guilherme Vasconcelos', 'Ingrid', 'João Vitor', 'Lucas Oliveira', 'Ludmila'])
      expect(described_class::LINKS['Lucas Oliveira'][:niches]).to include('Indústria farmacêutica')
      expect(described_class::LINKS.values.all? { |l| l[:niches].any? && l[:sub_niches].any? }).to be(true)
    end
  end
end
