require 'rails_helper'

RSpec.describe 'Ticket Activities API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:ticket_column) { create(:ticket_column, team: create(:team, account: account)) }
  let(:ticket) { create(:ticket, ticket_column: ticket_column) }

  describe 'GET /api/v1/accounts/{account.id}/tickets/{ticket.id}/activities' do
    it 'lists the activities most recent first' do
      ticket.resolve!(agent)
      ticket.reopen!(agent)

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/activities",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      types = response.parsed_body.pluck('activity_type')
      # created (on ticket creation) precedes resolved, which precedes reopened;
      # the endpoint orders newest first.
      expect(types.first(2)).to eq(%w[reopened resolved])
      expect(types).to include('created')
    end
  end
end
