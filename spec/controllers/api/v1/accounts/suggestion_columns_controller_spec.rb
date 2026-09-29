require 'rails_helper'

RSpec.describe 'Suggestion Columns API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v1/accounts/{account.id}/suggestion_columns' do
    it 'provisions the default columns on first load' do
      get "/api/v1/accounts/#{account.id}/suggestion_columns", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(5)
    end

    it 'is idempotent - does not duplicate columns on a second load' do
      get "/api/v1/accounts/#{account.id}/suggestion_columns", headers: agent.create_new_auth_token, as: :json
      get "/api/v1/accounts/#{account.id}/suggestion_columns", headers: agent.create_new_auth_token, as: :json

      expect(account.suggestion_columns.count).to eq(5)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/suggestion_columns' do
    it 'forbids a plain agent from creating a column' do
      post "/api/v1/accounts/#{account.id}/suggestion_columns",
           params: { suggestion_column: { name: 'Nova coluna' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator create a column' do
      post "/api/v1/accounts/#{account.id}/suggestion_columns",
           params: { suggestion_column: { name: 'Nova coluna' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Nova coluna')
    end

    it 'lets an administrator mark the column as the completion column' do
      post "/api/v1/accounts/#{account.id}/suggestion_columns",
           params: { suggestion_column: { name: 'Concluído', completed: true } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['completed']).to be(true)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/suggestion_columns/:id' do
    it 'is blocked while the column still has suggestions' do
      column = create(:suggestion_column, account: account)
      create(:suggestion, suggestion_column: column, account: account)

      delete "/api/v1/accounts/#{account.id}/suggestion_columns/#{column.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(SuggestionColumn.exists?(column.id)).to be(true)
    end
  end
end
