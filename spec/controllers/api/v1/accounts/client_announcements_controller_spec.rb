require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::ClientAnnouncements', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/client_announcements" }

  describe 'authorization' do
    it 'rejects an unauthenticated request' do
      get base, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'forbids an agent' do
      get base, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET index' do
    it 'lists the account announcements with their status' do
      create(:client_announcement, account: account, title: 'Aviso')
      create(:client_announcement, account: create(:account), title: 'Outra conta')

      get base, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('title')).to eq(['Aviso'])
      expect(response.parsed_body.first['status']).to eq('live')
    end
  end

  describe 'POST create' do
    it 'creates an announcement for everyone, recording the author' do
      post base, params: { client_announcement: { title: 'Manutencao', body: "Linha 1\nLinha 2", kind: 'warning' } },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      created = account.client_announcements.last
      expect(created).to have_attributes(title: 'Manutencao', kind: 'warning', audience: 'all', created_by: admin)
    end

    it 'creates a segmented announcement' do
      post base, params: { client_announcement: { title: 'Segmentado', audience: 'segmented', client_levels: [3] } },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(account.client_announcements.last.client_levels).to eq([3])
    end

    it 'rejects a segmented announcement without any filter' do
      post base, params: { client_announcement: { title: 'Vazio', audience: 'segmented' } },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an end before the start' do
      post base, params: { client_announcement: { title: 'Datas', starts_at: 2.days.from_now, ends_at: 1.day.from_now } },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a non-http link' do
      post base, params: { client_announcement: { title: 'Link', link_url: 'javascript:alert(1)' } },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH update' do
    it 'updates and can clear the segmentation back to everyone' do
      announcement = create(:client_announcement, account: account, audience: 'segmented', client_levels: [1])

      patch "#{base}/#{announcement.id}",
            params: { client_announcement: { audience: 'all', client_levels: [] } },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(announcement.reload).to have_attributes(audience: 'all', client_levels: [])
    end

    it 'does not touch another account announcement' do
      other = create(:client_announcement, account: create(:account))

      patch "#{base}/#{other.id}", params: { client_announcement: { title: 'X' } },
                                   headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy' do
    it 'deletes the announcement' do
      announcement = create(:client_announcement, account: account)

      delete "#{base}/#{announcement.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(ClientAnnouncement.exists?(announcement.id)).to be(false)
    end
  end
end
