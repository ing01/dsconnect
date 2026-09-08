require 'rails_helper'

RSpec.describe 'Checklists API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'POST .../checklists' do
    it 'is forbidden for an agent' do
      post "/api/v1/accounts/#{account.id}/checklists",
           params: { checklist: { name: 'Onboarding' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a checklist with its items for an administrator' do
      post "/api/v1/accounts/#{account.id}/checklists",
           params: { checklist: { name: 'Onboarding', items: [{ title: 'Confirmar dados' }, { title: 'Instalar sistema' }] } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Onboarding')
      expect(response.parsed_body['items'].pluck('title')).to eq(['Confirmar dados', 'Instalar sistema'])
    end
  end

  describe 'GET .../checklists' do
    it 'lists the account checklists, ordered by name' do
      create(:checklist, account: account, name: 'Zeta')
      create(:checklist, account: account, name: 'Alfa')

      get "/api/v1/accounts/#{account.id}/checklists", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('name')).to eq(%w[Alfa Zeta])
    end
  end

  describe 'PATCH .../checklists/:id' do
    it 'updates the items' do
      checklist = create(:checklist, account: account, items: [{ 'title' => 'Antigo' }])

      patch "/api/v1/accounts/#{account.id}/checklists/#{checklist.id}",
            params: { checklist: { items: [{ title: 'Novo item' }] } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(checklist.reload.items).to eq([{ 'title' => 'Novo item' }])
    end
  end
end
