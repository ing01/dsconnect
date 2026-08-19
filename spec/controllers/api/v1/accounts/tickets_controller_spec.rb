require 'rails_helper'

RSpec.describe 'Tickets API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:ticket_board) { create(:ticket_board, account: account) }
  let(:ticket_column) { create(:ticket_column, ticket_board: ticket_board) }
  let(:another_column) { create(:ticket_column, ticket_board: ticket_board) }

  describe 'GET /api/v1/accounts/{account.id}/tickets' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/tickets"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the tickets ordered by position' do
      create(:ticket, account: account, ticket_column: ticket_column, title: 'Segundo', position: 1)
      create(:ticket, account: account, ticket_column: ticket_column, title: 'Primeiro', position: 0)

      get "/api/v1/accounts/#{account.id}/tickets",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('title')).to eq(%w[Primeiro Segundo])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/tickets' do
    it 'creates a ticket, agents included' do
      post "/api/v1/accounts/#{account.id}/tickets",
           params: { ticket: { title: 'Erro no login', priority: 'high', ticket_column_id: ticket_column.id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['title']).to eq('Erro no login')
      expect(response.parsed_body['priority']).to eq('high')
    end

    it 'links a conversation when conversation_id is provided' do
      conversation = create(:conversation, account: account)

      post "/api/v1/accounts/#{account.id}/tickets",
           params: { ticket: { title: 'Erro no login', ticket_column_id: ticket_column.id }, conversation_id: conversation.id },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['conversation_ids']).to eq([conversation.id])
    end

    it 'rejects a column that belongs to another account' do
      other_column = create(:ticket_column)

      post "/api/v1/accounts/#{account.id}/tickets",
           params: { ticket: { title: 'Erro no login', ticket_column_id: other_column.id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/tickets/:id/move' do
    it 'moves the ticket to another column and re-indexes positions' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, position: 0)
      sibling = create(:ticket, account: account, ticket_column: ticket_column, position: 1)

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/move",
            params: { ticket_column_id: another_column.id, position: 0 },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.ticket_column_id).to eq(another_column.id)
      expect(sibling.reload.position).to eq(0)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/tickets/:id' do
    it 'destroys the ticket' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column)

      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(Ticket.count).to eq(0)
    end
  end
end
