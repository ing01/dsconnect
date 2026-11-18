require 'rails_helper'

# O Mural de Avisos do Portal do Cliente. O que se prova aqui: so' aparece o aviso
# ativo e dentro do periodo, a segmentacao por Empresa/Nicho/Prioridade recorta o
# publico, urgente vem primeiro, e a fronteira entre contas e entre contatos.
RSpec.describe 'Client announcements', type: :request do
  let(:account) { create(:account) }
  let(:nicho) { CompanyNiche.create!(account: account, name: 'Varejo') }
  let(:empresa) { create(:company, account: account, company_niche: nicho) }

  let(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br', company: empresa)
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  def entrar
    post '/api/v1/client/session', params: { email: 'cliente@exemplo.com.br', password: 'SenhaDoCliente@01' }, as: :json
    response.parsed_body['api_access_token']
  end

  def listar
    cliente
    get '/api/v1/client/announcements', headers: { api_access_token: entrar }, as: :json
    response.parsed_body['announcements'].pluck('title')
  end

  def aviso(attrs = {})
    create(:client_announcement, { account: account }.merge(attrs))
  end

  it 'requires a client session' do
    get '/api/v1/client/announcements', as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'period and status' do
    it 'lists an active announcement with no dates' do
      aviso(title: 'Sem datas')

      expect(listar).to eq(['Sem datas'])
    end

    it 'lists an announcement inside its period' do
      aviso(title: 'Em vigor', starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

      expect(listar).to eq(['Em vigor'])
    end

    it 'hides an announcement that has not started' do
      aviso(title: 'Futuro', starts_at: 1.hour.from_now)

      expect(listar).to be_empty
    end

    it 'hides an expired announcement' do
      aviso(title: 'Vencido', starts_at: 2.days.ago, ends_at: 1.hour.ago)

      expect(listar).to be_empty
    end

    it 'hides an inactive announcement' do
      aviso(title: 'Desligado', active: false)

      expect(listar).to be_empty
    end

    it 'puts urgent first, then follows the admin order' do
      aviso(title: 'Info', position: 0)
      aviso(title: 'Urgente', kind: 'urgent', position: 5)

      expect(listar).to eq(%w[Urgente Info])
    end
  end

  describe 'segmentation' do
    it 'shows a segmented announcement to a listed company' do
      aviso(title: 'Da empresa', audience: 'segmented', company_ids: [empresa.id])

      expect(listar).to eq(['Da empresa'])
    end

    it 'hides it from a company that is not listed' do
      aviso(title: 'De outra', audience: 'segmented', company_ids: [create(:company, account: account).id])

      expect(listar).to be_empty
    end

    it 'filters by niche' do
      aviso(title: 'Do nicho', audience: 'segmented', company_niche_ids: [nicho.id])
      aviso(title: 'Outro nicho', audience: 'segmented', company_niche_ids: [CompanyNiche.create!(account: account, name: 'Outro').id])

      expect(listar).to eq(['Do nicho'])
    end

    it 'filters by client level' do
      aviso(title: 'Do nivel', audience: 'segmented', client_levels: [empresa.client_level])
      aviso(title: 'Outro nivel', audience: 'segmented', client_levels: [empresa.client_level + 1])

      expect(listar).to eq(['Do nivel'])
    end

    it 'requires every filled filter to match (AND between filters)' do
      aviso(title: 'Nicho certo, nivel errado', audience: 'segmented',
            company_niche_ids: [nicho.id], client_levels: [empresa.client_level + 1])

      expect(listar).to be_empty
    end
  end

  it 'never shows announcements from another account' do
    aviso(title: 'De outra conta', account: create(:account))

    expect(listar).to be_empty
  end
end
