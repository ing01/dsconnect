require 'rails_helper'

# A API de Integracao de Tickets: o que um sistema EXTERNO (a IA de triagem)
# consome para ler e rotear tickets. O que se prova aqui: a chave autentica
# (e uma chave errada/de outra conta nao), o payload do `show` nao inclui
# nada interno, e o `route` move/classifica de verdade com o mesmo rastro de
# auditoria que o painel usa.
RSpec.describe 'Ticket Integration API', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }

  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:ticket) { create(:ticket, ticket_column: column) }

  describe 'GET /api/v1/integrations/tickets' do
    it 'rejects a request without a key' do
      get '/api/v1/integrations/tickets'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a key from another account' do
      other_key = create(:ticket_api_key)
      get '/api/v1/integrations/tickets', headers: { 'X-Ticket-Api-Key' => other_key.token }
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to eq([])
    end

    it 'lists only the tickets of the key\'s own account, paginated' do
      ticket
      get '/api/v1/integrations/tickets', headers: headers, as: :json
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([ticket.id])
      expect(response.parsed_body['meta']['count']).to eq(1)
    end

    it 'filters by status and team_id' do
      ticket
      outro_team = create(:team, account: account)
      get '/api/v1/integrations/tickets', params: { team_id: outro_team.id }, headers: headers, as: :json
      expect(response.parsed_body['payload']).to be_empty
    end
  end

  describe 'GET /api/v1/integrations/tickets/:id' do
    it 'returns the rich payload for the IA to analyse' do
      comunicacao = create(:ticket_customer_communication, ticket: ticket, direction: 'outbound', body: 'Resposta da equipe')

      get "/api/v1/integrations/tickets/#{ticket.id}", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['title']).to eq(ticket.title)
      expect(body['customer_communications'].first['body']).to eq(comunicacao.body)
    end

    it 'never includes the team-internal comments' do
      get "/api/v1/integrations/tickets/#{ticket.id}", headers: headers, as: :json
      expect(response.parsed_body).not_to have_key('ticket_comments')
      expect(response.parsed_body).not_to have_key('comments')
    end

    it '404s for a ticket from another account' do
      outro = create(:ticket)
      get "/api/v1/integrations/tickets/#{outro.id}", headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/integrations/tickets/:id/route' do
    let(:destino) { create(:ticket_column, team: create(:team, account: account)) }

    it 'moves the ticket and logs it as an auditable, user-less activity' do
      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { team_id: destino.team_id, ticket_column_id: destino.id },
            headers: headers, as: :json

      expect(response).to have_http_status(:success)
      ticket.reload
      expect(ticket.ticket_column_id).to eq(destino.id)
      activity = ticket.ticket_activities.find_by(activity_type: :transferred)
      expect(activity.user).to be_nil
    end

    it 'posts the note as a user-less activity, visible on the ticket' do
      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { team_id: destino.team_id, note: 'parece um problema de rede' },
            headers: headers, as: :json

      note = ticket.ticket_activities.find_by(activity_type: :automation_note)
      expect(note.new_value).to include('parece um problema de rede')
      expect(note.user).to be_nil
    end

    it 'rejects a category that does not belong to the target team' do
      categoria_de_outra_mesa = create(:ticket_category, team: create(:team, account: account))

      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { team_id: ticket.team_id, ticket_category_id: categoria_de_outra_mesa.id },
            headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
