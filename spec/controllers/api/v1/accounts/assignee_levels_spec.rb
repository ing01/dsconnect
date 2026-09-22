require 'rails_helper'

# A configuracao de niveis pela API: quantos niveis a Mesa usa, quem esta
# habilitado em cada um, e o que o ticket aceita por consequencia. E este o
# caminho que as telas de Configuracoes usam.
RSpec.describe 'Assignee levels configuration', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:outro_agente) { create(:user, account: account, role: :agent) }

  def auth(user = administrator)
    user.create_new_auth_token
  end

  describe 'PATCH /teams/:id' do
    let(:team) { create(:team, account: account) }

    it 'stores how many levels the desk uses' do
      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: { team: { name: team.name, assignee_levels_enabled: true, assignee_levels_count: 3 } },
            headers: auth, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['assignee_levels_count']).to eq(3)
      # Ja resolvidos: a tela desenha um campo por nivel sem precisar contar.
      expect(body['assignee_levels']).to eq([1, 2, 3])
      expect(team.reload.assignee_levels_count).to eq(3)
    end

    it 'refuses a count beyond what the ticket can store' do
      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: { team: { assignee_levels_enabled: true,
                              assignee_levels_count: AssigneeLeveled::MAX_LEVEL + 1 } },
            headers: auth, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(team.reload.assignee_levels_count).to eq(2)
    end
  end

  describe 'PATCH /team_members/update_levels' do
    let(:team) do
      create(:team, account: account, assignee_levels_enabled: true, assignee_levels_count: 3)
    end

    before { team.add_members([agente.id, outro_agente.id]) }

    it 'enables a member for the third level' do
      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members/update_levels",
            params: { levels: { agente.id.to_s => [1, 3] } }, headers: auth, as: :json

      expect(response).to have_http_status(:success)
      expect(team.team_members.find_by(user_id: agente.id).levels).to eq([1, 3])
    end

    # A habilitacao segue os niveis DAQUELA Mesa: numa que atende em dois, um
    # Nivel 3 guardado nunca seria oferecido na tela nem aceito pelo ticket, e
    # ficaria no banco parecendo uma permissao que nao existe.
    it 'discards a level the desk does not use' do
      team.update!(assignee_levels_count: 2)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members/update_levels",
            params: { levels: { agente.id.to_s => [1, 2, 3] } }, headers: auth, as: :json

      expect(team.team_members.find_by(user_id: agente.id).levels).to eq([1, 2])
    end

    it 'leaves members absent from the payload untouched' do
      team.team_members.find_by(user_id: outro_agente.id).update!(levels: [2])

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members/update_levels",
            params: { levels: { agente.id.to_s => [1] } }, headers: auth, as: :json

      expect(team.team_members.find_by(user_id: outro_agente.id).levels).to eq([2])
    end

    it 'reports each member with their levels on the listing' do
      team.team_members.find_by(user_id: agente.id).update!(levels: [1, 3])

      get "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
          headers: auth, as: :json

      linha = response.parsed_body.find { |member| member['id'] == agente.id }
      expect(linha['levels']).to eq([1, 3])
    end
  end

  describe 'PATCH /tickets/:id' do
    let(:team) do
      create(:team, account: account, assignee_levels_enabled: true, assignee_levels_count: 3)
    end
    let(:column) { create(:ticket_column, team: team, position: 0) }
    let(:ticket) { create(:ticket, account: account, team: team, ticket_column: column) }

    before do
      team.add_members([agente.id])
      team.team_members.find_by(user_id: agente.id).update!(levels: [3])
    end

    # O campo precisa ser permitido para chegar. Escrito a mao, esquecer de
    # acrescentar um nivel novo fazia o valor ser descartado em silencio - a tela
    # salvava, a API respondia 200 e nada mudava.
    it 'accepts the third-level assignee and answers with it' do
      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
            params: { ticket: { assignee_3_id: agente.id } }, headers: auth, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['assignee_3_id']).to eq(agente.id)
      expect(body['assignee_3_name']).to eq(agente.name)
      expect(ticket.reload.assignee_3_id).to eq(agente.id)
    end

    # O payload do Kanban inlina cada ticket de cada Estagio: campos de niveis
    # que a Mesa nao usa sao peso sem uso.
    it 'omits levels the desk does not use from the payload' do
      team.update!(assignee_levels_count: 2)

      get "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}", headers: auth, as: :json

      body = response.parsed_body
      expect(body).to have_key('assignee_2_id')
      expect(body).not_to have_key('assignee_3_id')
    end
  end
end
