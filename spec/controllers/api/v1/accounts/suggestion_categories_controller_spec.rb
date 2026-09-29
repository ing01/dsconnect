require 'rails_helper'

RSpec.describe 'Suggestion Categories API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v1/accounts/{account.id}/suggestion_categories' do
    it 'lists categories for a plain agent (board is open to everyone)' do
      create(:suggestion_category, account: account)

      get "/api/v1/accounts/#{account.id}/suggestion_categories", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/suggestion_categories' do
    it 'forbids a plain agent from creating a category' do
      post "/api/v1/accounts/#{account.id}/suggestion_categories",
           params: { suggestion_category: { name: 'Bug' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an administrator create a category with a color' do
      post "/api/v1/accounts/#{account.id}/suggestion_categories",
           params: { suggestion_category: { name: 'Bug', color: 'amber' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Bug')
      expect(response.parsed_body['color']).to eq('amber')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/suggestion_categories/:id' do
    it 'is allowed even while suggestions still use it (they are just unset)' do
      category = create(:suggestion_category, account: account)
      column = create(:suggestion_column, account: account)
      suggestion = create(:suggestion, category: category, account: account, suggestion_column: column)

      delete "/api/v1/accounts/#{account.id}/suggestion_categories/#{category.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(SuggestionCategory.exists?(category.id)).to be(false)
      expect(suggestion.reload.category_id).to be_nil
    end
  end
end
