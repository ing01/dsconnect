require 'rails_helper'

RSpec.describe 'Ticket Columns API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }

  describe 'POST .../teams/:team_id/ticket_columns' do
    it 'is forbidden for an agent' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns",
           params: { ticket_column: { name: 'Aberto' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a column (Estagio) for an administrator' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns",
           params: { ticket_column: { name: 'Aberto' } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Aberto')
      expect(response.parsed_body['team_id']).to eq(team.id)
    end

    it 'honours an explicit position by reordering the Mesa' do
      post "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns",
           params: { ticket_column: { name: 'Aguardando cliente', position: 0 } },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['position']).to eq(0)
      expect(team.reload.ticket_columns.first.name).to eq('Aguardando cliente')
    end
  end

  describe 'PATCH .../teams/:team_id/ticket_columns/:id' do
    let(:destination) { create(:team, account: account) }

    it 'renames the Estagio' do
      column = create(:ticket_column, team: team)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
            params: { ticket_column: { name: 'Pendente' } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(column.reload.name).to eq('Pendente')
    end

    it 'moves an empty Estagio to another Mesa' do
      column = create(:ticket_column, team: team)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
            params: { ticket_column: { team_id: destination.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['team_id']).to eq(destination.id)
      expect(column.reload.team).to eq(destination)
    end

    it 'refuses to move an Estagio that still has tickets' do
      column = create(:ticket_column, team: team)
      create_list(:ticket, 2, ticket_column: column, team: team)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
            params: { ticket_column: { team_id: destination.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('2')
      expect(column.reload.team).to eq(team)
    end

    it 'refuses a Mesa belonging to another account' do
      column = create(:ticket_column, team: team)
      foreign_team = create(:team, account: create(:account))

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
            params: { ticket_column: { team_id: foreign_team.id } },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(column.reload.team).to eq(team)
    end
  end

  describe 'PATCH .../teams/:team_id/ticket_columns/reorder' do
    it 'persists the new column order and renders the Mesa with its Estagios' do
      team.ticket_columns.destroy_all
      first = create(:ticket_column, team: team, position: 0)
      second = create(:ticket_column, team: team, position: 1)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/reorder",
            params: { column_ids: [second.id, first.id] },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(second.reload.position).to eq(0)
      expect(first.reload.position).to eq(1)
      expect(response.parsed_body['ticket_columns'].pluck('id')).to eq([second.id, first.id])
    end
  end

  describe 'DELETE .../teams/:team_id/ticket_columns/:id' do
    it 'is restricted while the column still has tickets' do
      column = create(:ticket_column, team: team)
      create(:ticket, ticket_column: column)

      delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'explains how many tickets are blocking the deletion' do
      column = create(:ticket_column, team: team)
      create_list(:ticket, 12, ticket_column: column, team: team)

      delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response.parsed_body['error']).to include('12')
      expect(TicketColumn.exists?(column.id)).to be(true)
    end

    it 'destroys the column for an administrator once it has no tickets' do
      column = create(:ticket_column, team: team)

      delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/ticket_columns/#{column.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(TicketColumn.exists?(column.id)).to be(false)
    end
  end
end
