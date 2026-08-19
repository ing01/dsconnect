require 'rails_helper'

RSpec.describe 'Ticket Columns API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:ticket_board) { create(:ticket_board, account: account) }

  describe 'POST .../ticket_boards/:ticket_board_id/ticket_columns' do
    it 'is forbidden for an agent' do
      post "/api/v1/accounts/#{account.id}/ticket_boards/#{ticket_board.id}/ticket_columns",
           params: { ticket_column: { name: 'Aberto' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a column for an administrator' do
      post "/api/v1/accounts/#{account.id}/ticket_boards/#{ticket_board.id}/ticket_columns",
           params: { ticket_column: { name: 'Aberto' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Aberto')
    end
  end

  describe 'PATCH .../ticket_columns/reorder' do
    it 'persists the new column order' do
      first = create(:ticket_column, ticket_board: ticket_board, position: 0)
      second = create(:ticket_column, ticket_board: ticket_board, position: 1)

      patch "/api/v1/accounts/#{account.id}/ticket_boards/#{ticket_board.id}/ticket_columns/reorder",
            params: { column_ids: [second.id, first.id] },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(second.reload.position).to eq(0)
      expect(first.reload.position).to eq(1)
    end
  end

  describe 'DELETE .../ticket_columns/:id' do
    it 'is restricted while the column still has tickets' do
      column = create(:ticket_column, ticket_board: ticket_board)
      create(:ticket, ticket_column: column, account: account)

      delete "/api/v1/accounts/#{account.id}/ticket_boards/#{ticket_board.id}/ticket_columns/#{column.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
