require 'rails_helper'

RSpec.describe 'Ticket Comments Integration API', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, ticket_column: column) }

  describe 'GET /api/v1/integrations/tickets/:ticket_id/comments' do
    it 'rejects a request without a key' do
      get "/api/v1/integrations/tickets/#{ticket.id}/comments"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the internal notes so an external system can read what the team wrote' do
      autor = create(:user, account: account)
      comentario = create(:ticket_comment, ticket: ticket, content: 'Causa identificada', user: autor)

      get "/api/v1/integrations/tickets/#{ticket.id}/comments", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.length).to eq(1)
      expect(body.first).to include('id' => comentario.id, 'content' => 'Causa identificada', 'author_name' => autor.name)
    end

    it '404s for a ticket from another account' do
      outro = create(:ticket)
      get "/api/v1/integrations/tickets/#{outro.id}/comments", headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
