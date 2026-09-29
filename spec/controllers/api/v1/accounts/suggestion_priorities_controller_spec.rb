require 'rails_helper'

RSpec.describe 'Suggestion Priorities API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v1/accounts/{account.id}/suggestion_priorities' do
    it 'lists priorities for a plain agent (board is open to everyone)' do
      create(:suggestion_priority, account: account)

      get "/api/v1/accounts/#{account.id}/suggestion_priorities", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/suggestion_priorities' do
    it 'forbids a plain agent from creating a priority' do
      post "/api/v1/accounts/#{account.id}/suggestion_priorities",
           params: { suggestion_priority: { name: 'Alta' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator create a priority with a color' do
      post "/api/v1/accounts/#{account.id}/suggestion_priorities",
           params: { suggestion_priority: { name: 'Alta', color: 'ruby' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Alta')
      expect(response.parsed_body['color']).to eq('ruby')
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/suggestion_priorities/:id' do
    it 'lets an administrator rename and recolor a priority' do
      priority = create(:suggestion_priority, account: account, name: 'Baixa', color: 'slate')

      patch "/api/v1/accounts/#{account.id}/suggestion_priorities/#{priority.id}",
            params: { suggestion_priority: { name: 'Baixíssima', color: 'teal' } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(priority.reload.name).to eq('Baixíssima')
      expect(priority.color).to eq('teal')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/suggestion_priorities/:id' do
    it 'is allowed even while suggestions still use it (they are just unset)' do
      priority = create(:suggestion_priority, account: account)
      column = create(:suggestion_column, account: account)
      suggestion = create(:suggestion, priority: priority, account: account, suggestion_column: column)

      delete "/api/v1/accounts/#{account.id}/suggestion_priorities/#{priority.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(SuggestionPriority.exists?(priority.id)).to be(false)
      expect(suggestion.reload.priority_id).to be_nil
    end
  end
end
