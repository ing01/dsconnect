require 'rails_helper'

RSpec.describe 'Implementation Reports API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }

  describe 'GET .../implementation_reports/hours_summary' do
    it 'is accessible to an agent and returns the summed hours' do
      project = create(:project, account: account, team: team)
      ticket = create(:ticket, project: project, ticket_column: team.ticket_columns.first)
      create(:ticket_time_entry, ticket: ticket, account: account, user: agent, hours: 4)

      get "/api/v1/accounts/#{account.id}/implementation_reports/hours_summary", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['total_hours']).to eq(4.0)
    end
  end

  describe 'GET .../implementation_reports/by_module' do
    it 'returns the module breakdown' do
      create(:project, account: account, team: team)

      get "/api/v1/accounts/#{account.id}/implementation_reports/by_module", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to be_an(Array)
    end
  end
end
