require 'rails_helper'

RSpec.describe 'Suggestions API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:column) { create(:suggestion_column, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/suggestions' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/suggestions"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists suggestions for a plain agent (board is open to everyone)' do
      create(:suggestion, suggestion_column: column, account: account, user: agent)

      get "/api/v1/accounts/#{account.id}/suggestions", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/suggestions' do
    it 'lets a plain agent submit a suggestion' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria', description: 'Detalhes' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['title']).to eq('Melhoria')
      expect(Suggestion.last.user).to eq(agent)
    end

    it 'creates the account default columns and lands the suggestion in the first one' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(account.suggestion_columns.count).to eq(5)
      expect(Suggestion.last.suggestion_column).to eq(account.suggestion_columns.order(:position).first)
    end

    it 'ignores assignee_id sent by a plain agent' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria', assignee_id: administrator.id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(Suggestion.last.assignee_id).to be_nil
    end

    it 'lets an administrator set the assignee on creation' do
      post "/api/v1/accounts/#{account.id}/suggestions",
           params: { suggestion: { title: 'Melhoria', assignee_id: administrator.id } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(Suggestion.last.assignee).to eq(administrator)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/suggestions/:id' do
    it 'forbids a plain agent from setting the assignee' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: administrator.id } },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator set and clear the assignee' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: administrator.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.assignee).to eq(administrator)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: '' } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.assignee_id).to be_nil
    end

    it 'rejects a plain agent as assignee' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
            params: { suggestion: { assignee_id: agent.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(suggestion.reload.assignee_id).to be_nil
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/suggestions/:id/move' do
    it 'forbids a plain agent from moving a suggestion' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)
      other_column = create(:suggestion_column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}/move",
            params: { suggestion_column_id: other_column.id, position: 0 },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator move a suggestion between columns' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)
      other_column = create(:suggestion_column, account: account)

      patch "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}/move",
            params: { suggestion_column_id: other_column.id, position: 0 },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(suggestion.reload.suggestion_column).to eq(other_column)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/suggestions/:id' do
    it 'forbids a plain agent from deleting a suggestion' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      delete "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Suggestion.exists?(suggestion.id)).to be(true)
    end

    it 'lets an administrator delete a suggestion' do
      suggestion = create(:suggestion, suggestion_column: column, account: account)

      delete "/api/v1/accounts/#{account.id}/suggestions/#{suggestion.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(Suggestion.exists?(suggestion.id)).to be(false)
    end
  end
end
