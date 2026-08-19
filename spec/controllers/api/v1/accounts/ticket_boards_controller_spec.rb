require 'rails_helper'

RSpec.describe 'Ticket Boards API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let!(:ticket_board) { create(:ticket_board, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/ticket_boards' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/ticket_boards"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the boards with their columns for an agent' do
      create(:ticket_column, ticket_board: ticket_board, name: 'Aberto')

      get "/api/v1/accounts/#{account.id}/ticket_boards",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first['id']).to eq(ticket_board.id)
      expect(response.parsed_body.first['ticket_columns'].first['name']).to eq('Aberto')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ticket_boards' do
    it 'is forbidden for an agent' do
      post "/api/v1/accounts/#{account.id}/ticket_boards",
           params: { ticket_board: { name: 'Suporte' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a board for an administrator' do
      post "/api/v1/accounts/#{account.id}/ticket_boards",
           params: { ticket_board: { name: 'Suporte' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Suporte')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/ticket_boards/:id' do
    it 'destroys the board for an administrator' do
      delete "/api/v1/accounts/#{account.id}/ticket_boards/#{ticket_board.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(TicketBoard.count).to eq(0)
    end
  end
end
