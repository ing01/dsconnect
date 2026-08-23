require 'rails_helper'

RSpec.describe 'Tickets API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:ticket_column) { create(:ticket_column, team: team) }
  let(:another_column) { create(:ticket_column, team: team) }

  describe 'GET /api/v1/accounts/{account.id}/tickets' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/tickets"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the tickets of a column ordered by position' do
      # Positions are left to the model's default auto-increment-on-create
      # (rather than passed explicitly): `Ticket#set_default_position` can't
      # tell an explicit `position: 0` apart from the column's own DB
      # default, so creation order is what determines position here.
      create(:ticket, account: account, ticket_column: ticket_column, title: 'Primeiro')
      create(:ticket, account: account, ticket_column: ticket_column, title: 'Segundo')

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { ticket_column_id: ticket_column.id },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('title')).to eq(%w[Primeiro Segundo])
    end

    it 'paginates the flat list when no ticket_column_id is given' do
      create_list(:ticket, 3, account: account, ticket_column: ticket_column)

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { per_page: 2, page: 1 },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].size).to eq(2)
      expect(response.parsed_body['meta']['count']).to eq(3)
    end

    it 'filters by status' do
      open_ticket = create(:ticket, account: account, ticket_column: ticket_column, status: 'open')
      create(:ticket, account: account, ticket_column: ticket_column, status: 'resolved')

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { status: 'open' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([open_ticket.id])
    end

    it 'filters by mine' do
      mine = create(:ticket, account: account, ticket_column: ticket_column, assignee: agent)
      create(:ticket, account: account, ticket_column: ticket_column)

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { mine: true },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([mine.id])
    end

    it 'filters by display_id (Busca detalhada - Numero do Ticket)' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column)
      create(:ticket, account: account, ticket_column: ticket_column)

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { display_id: ticket.display_id },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([ticket.id])
    end

    it 'filters by the linked conversation contact and company (Busca detalhada - Solicitante/Cliente)' do
      company = create(:company, account: account, name: 'Acme Ltda')
      contact = create(:contact, account: account, company: company, name: 'Fulano de Tal')
      conversation = create(:conversation, account: account, contact: contact)
      matching = create(:ticket, account: account, ticket_column: ticket_column)
      create(:ticket_conversation, ticket: matching, conversation: conversation)
      create(:ticket, account: account, ticket_column: ticket_column)

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { contact_query: 'Fulano', company_query: 'Acme' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([matching.id])
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
    it 'moves the ticket to another column and re-indexes positions when the requester is the assignee' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, position: 0, assignee: agent)
      sibling = create(:ticket, account: account, ticket_column: ticket_column, position: 1)

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/move",
            params: { ticket_column_id: another_column.id, position: 0 },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.ticket_column_id).to eq(another_column.id)
      expect(sibling.reload.position).to eq(0)
    end

    it 'forbids moving a ticket the requester is not assigned to and is not an administrator' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, position: 0)

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/move",
            params: { ticket_column_id: another_column.id, position: 0 },
            headers: agent.create_new_auth_token,
            as: :json

      # This app's Pundit::NotAuthorizedError handler renders 401, not 403
      # (see RequestExceptionHandler#render_unauthorized) - matching the
      # convention already used by every other policy-guarded endpoint.
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH resolve/reopen/close' do
    it 'resolves, then reopens a ticket and records activity' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, assignee: agent)

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/resolve",
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('resolved')
      expect(ticket.ticket_activities.where(activity_type: :resolved)).to be_present

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/reopen",
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('open')
    end

    it 'closes a resolved ticket' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column, assignee: agent, status: 'resolved')

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/close",
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('closed')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/tickets/:id' do
    it 'destroys the ticket when the requester is an administrator' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column)

      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(Ticket.exists?(ticket.id)).to be(false)
    end

    it 'forbids a non-administrator agent from destroying the ticket' do
      ticket = create(:ticket, account: account, ticket_column: ticket_column)

      delete "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Ticket.exists?(ticket.id)).to be(true)
    end
  end
end
