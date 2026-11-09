require 'rails_helper'

# Os dois recursos de DESCOBERTA da API de Integracao de Tickets: `GET /users` (de
# onde sai o `assignee_id`) e `GET /sprints` (de onde sai o `sprint_id`). Ambos
# valem so' para a conta da chave - o que vem de outra conta nunca aparece, e um
# id de outra conta e' 404.
RSpec.describe 'Ticket Integration API - users and sprints', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }

  let(:other_account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: other_account) }

  describe 'GET /api/v1/integrations/users' do
    let!(:ana) { create(:user, account: account, role: :agent, name: 'Ana', email: 'ana@exemplo.com.br') }
    let!(:estranho) { create(:user, account: other_account, role: :agent, name: 'Estranho') }

    it 'rejects a request without a key' do
      get '/api/v1/integrations/users'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists id, name, email and role of the users of the key\'s account' do
      get '/api/v1/integrations/users', headers: headers

      expect(response).to have_http_status(:success)
      usuario = response.parsed_body.find { |user| user['id'] == ana.id }
      expect(usuario).to include('name' => 'Ana', 'email' => 'ana@exemplo.com.br', 'role' => 'agent')
    end

    it 'never lists a user from another account' do
      get '/api/v1/integrations/users', headers: headers

      expect(response.parsed_body.pluck('id')).not_to include(estranho.id)
    end

    it 'lists only the members of a Mesa when team_id is given' do
      create(:team_member, team: team, user: ana)
      outro = create(:user, account: account, role: :agent)

      get '/api/v1/integrations/users', params: { team_id: team.id }, headers: headers

      ids = response.parsed_body.pluck('id')
      expect(ids).to include(ana.id)
      expect(ids).not_to include(outro.id)
    end

    it '404s for a team of another account' do
      get '/api/v1/integrations/users', params: { team_id: other_team.id }, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it '404s for a team that does not exist' do
      get '/api/v1/integrations/users', params: { team_id: 0 }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/integrations/users/:id' do
    it 'shows a user of the account' do
      usuario = create(:user, account: account, role: :agent)

      get "/api/v1/integrations/users/#{usuario.id}", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('id' => usuario.id, 'email' => usuario.email)
    end

    it '404s for a user of another account' do
      estranho = create(:user, account: other_account, role: :agent)

      get "/api/v1/integrations/users/#{estranho.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it '404s for an id that is not valid' do
      get '/api/v1/integrations/users/abc', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/integrations/sprints' do
    let!(:ativo) { create(:sprint, account: account, team: team).tap(&:activate!) }
    let!(:proximo) do
      create(:sprint, account: account, team: team, starts_on: Date.current + 8, ends_on: Date.current + 14)
    end
    let!(:de_outra_conta) { create(:sprint, account: other_account, team: other_team) }

    it 'rejects a request without a key' do
      get '/api/v1/integrations/sprints'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the sprints of the account and flags the active one' do
      get '/api/v1/integrations/sprints', headers: headers

      expect(response).to have_http_status(:success)
      por_id = response.parsed_body.index_by { |sprint| sprint['id'] }
      expect(por_id[ativo.id]).to include('active' => true, 'status' => 'active', 'team_id' => team.id)
      expect(por_id[proximo.id]).to include('active' => false, 'status' => 'upcoming')
    end

    it 'never lists a sprint from another account' do
      get '/api/v1/integrations/sprints', headers: headers

      expect(response.parsed_body.pluck('id')).not_to include(de_outra_conta.id)
    end

    it 'filters by team_id and by status' do
      get '/api/v1/integrations/sprints', params: { team_id: team.id, status: 'active' }, headers: headers

      expect(response.parsed_body.pluck('id')).to eq([ativo.id])
    end

    it '404s for a team of another account' do
      get '/api/v1/integrations/sprints', params: { team_id: other_team.id }, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a status that does not exist instead of answering an empty list' do
      get '/api/v1/integrations/sprints', params: { status: 'ativo' }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('upcoming', 'active', 'completed')
    end
  end

  describe 'GET /api/v1/integrations/tickets?sprint_id=' do
    let(:column) { create(:ticket_column, team: team) }
    let(:sprint) { create(:sprint, account: account, team: team) }
    let!(:no_sprint) { create(:ticket, ticket_column: column, sprint: sprint) }
    let!(:no_backlog) { create(:ticket, ticket_column: column) }

    it 'lists only the tickets of that sprint, exposing sprint_id' do
      get '/api/v1/integrations/tickets', params: { sprint_id: sprint.id }, headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([no_sprint.id])
      expect(response.parsed_body['payload'].first['sprint_id']).to eq(sprint.id)
    end

    # O filtro e' de igualdade, como os outros desta lista: a conta da chave limita
    # a consulta, entao o sprint de outra conta (ou inexistente) so' nao acha nada.
    it 'finds nothing for a sprint of another account' do
      alheio = create(:sprint, account: other_account, team: other_team)

      get '/api/v1/integrations/tickets', params: { sprint_id: alheio.id }, headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to eq([])
    end

    it 'finds nothing for a sprint that does not exist' do
      get '/api/v1/integrations/tickets', params: { sprint_id: 0 }, headers: headers

      expect(response.parsed_body['payload']).to eq([])
    end
  end
end
