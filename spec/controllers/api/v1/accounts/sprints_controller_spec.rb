require 'rails_helper'

# Fase 2 do Modulo de Desenvolvimento: CRUD de Sprints, aninhado na Mesa como
# Estagio/Categoria. Quem organiza o Backlog e' a propria Mesa (admin ou
# membro) - diferente de Estagio, que e' configuracao admin-only.
RSpec.describe 'Sprints API', type: :request do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }

  before { create(:team_member, team: team, user: member) }

  describe 'GET .../teams/:team_id/sprints' do
    it 'lists sprints that are not completed, ordered by start date' do
      later = create(:sprint, team: team, account: account, starts_on: Date.current + 14.days, ends_on: Date.current + 18.days)
      sooner = create(:sprint, team: team, account: account, starts_on: Date.current, ends_on: Date.current + 4.days)
      create(:sprint, team: team, account: account, status: :completed)

      get "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints",
          headers: member.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([sooner.id, later.id])
    end
  end

  describe 'POST .../teams/:team_id/sprints' do
    it 'is forbidden for an agent outside the Mesa' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints",
           params: { sprint: { name: 'OUT26 S1', starts_on: Date.current, ends_on: Date.current + 4.days } },
           headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a sprint for a member of the Mesa' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints",
           params: { sprint: { name: 'OUT26 S1', starts_on: Date.current, ends_on: Date.current + 4.days } },
           headers: member.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('OUT26 S1')
      expect(response.parsed_body['status']).to eq('upcoming')
      expect(team.sprints.count).to eq(1)
    end

    it 'creates a sprint for an administrator even without being a member' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints",
           params: { sprint: { name: 'OUT26 S1', starts_on: Date.current, ends_on: Date.current + 4.days } },
           headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'rejects an end date before the start date' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints",
           params: { sprint: { name: 'OUT26 S1', starts_on: Date.current, ends_on: Date.current - 1.day } },
           headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH .../teams/:team_id/sprints/:id' do
    it 'renames the sprint for a member of the Mesa' do
      sprint = create(:sprint, team: team, account: account)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}",
            params: { sprint: { name: 'OUT26 S2' } },
            headers: member.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(sprint.reload.name).to eq('OUT26 S2')
    end

    it 'is forbidden for an agent outside the Mesa' do
      sprint = create(:sprint, team: team, account: account)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}",
            params: { sprint: { name: 'OUT26 S2' } },
            headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'ignores a status sent in the body' do
      sprint = create(:sprint, team: team, account: account)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}",
            params: { sprint: { status: 'completed' } },
            headers: member.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(sprint.reload).to be_upcoming
    end
  end

  describe 'POST .../sprints/:id/activate' do
    it 'activates the sprint for a member of the Mesa' do
      sprint = create(:sprint, team: team, account: account)

      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}/activate",
           headers: member.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(sprint.reload).to be_active
    end

    it 'is forbidden for an agent outside the Mesa' do
      sprint = create(:sprint, team: team, account: account)

      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}/activate",
           headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST .../sprints/:id/conclude' do
    it 'concludes the sprint and reassigns pending tickets to the next one' do
      sprint = create(:sprint, team: team, account: account, status: :active)
      next_sprint = create(:sprint, team: team, account: account,
                                    starts_on: sprint.ends_on + 1.day, ends_on: sprint.ends_on + 5.days)
      ticket = create(:ticket, ticket_column: create(:ticket_column, team: team, kind: 'normal'), sprint: sprint)

      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}/conclude",
           headers: member.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(sprint.reload).to be_completed
      expect(ticket.reload.sprint_id).to eq(next_sprint.id)
      expect(next_sprint.reload).to be_active
    end

    it 'is forbidden for an agent outside the Mesa' do
      sprint = create(:sprint, team: team, account: account)

      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/sprints/#{sprint.id}/conclude",
           headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
