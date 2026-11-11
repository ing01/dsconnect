require 'rails_helper'

RSpec.describe 'Company tickets API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:company) { create(:company, name: 'Acme', domain: 'acme.com', account: account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }

  before { account.enable_features!(:companies) }

  describe 'GET /api/v1/accounts/{account.id}/companies/{company.id}/tickets' do
    it 'lists the tickets from the highest display_id to the lowest' do
      older = create(:ticket, ticket_column: column, company: company, position: 3)
      middle = create(:ticket, ticket_column: column, company: company, position: 1)
      newest = create(:ticket, ticket_column: column, company: company, position: 2)

      get "/api/v1/accounts/#{account.id}/companies/#{company.id}/tickets",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('display_id'))
        .to eq([newest.display_id, middle.display_id, older.display_id])
      expect(newest.display_id).to be > middle.display_id
    end
  end
end
