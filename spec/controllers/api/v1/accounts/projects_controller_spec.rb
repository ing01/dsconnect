require 'rails_helper'

RSpec.describe 'Projects API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/projects" }

  def ids_of(response)
    response.parsed_body.pluck('id')
  end

  def create_project_ticket(project, **attrs)
    create(:ticket, project: project, ticket_column: project.team.ticket_columns.first, **attrs)
  end

  describe 'GET /projects (abas do quadro)' do
    let!(:ativo) { create(:project, team: team, stage: 'onboarding') }
    let!(:finalizado) { create(:project, team: team, stage: 'finalizado') }
    let!(:cancelado) do
      create(:project, team: team, stage: 'onboarding').tap { |project| project.cancel!(reason: 'Cliente desistiu') }
    end

    it 'devolve so os ativos por padrao' do
      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ids_of(response)).to eq([ativo.id])
    end

    it 'devolve os finalizados em completed=true' do
      get base_url, params: { completed: 'true' }, headers: agent.create_new_auth_token, as: :json

      expect(ids_of(response)).to eq([finalizado.id])
    end

    # Antes o projeto cancelado sumia do quadro e nao dava para reativar.
    it 'devolve os cancelados em status=cancelled' do
      get base_url, params: { status: 'cancelled' }, headers: agent.create_new_auth_token, as: :json

      expect(ids_of(response)).to eq([cancelado.id])
      expect(response.parsed_body.first['cancellation_reason']).to eq('Cliente desistiu')
    end
  end

  describe 'GET /projects/counts' do
    it 'conta cada aba pelo servidor, respeitando os filtros' do
      other_team = create(:team, account: account)
      create(:project, team: team, stage: 'onboarding')
      create(:project, team: team, stage: 'pendente')
      create(:project, team: team, stage: 'finalizado')
      create(:project, team: team, stage: 'onboarding').cancel!(reason: 'Cliente desistiu')
      create(:project, team: other_team, stage: 'onboarding')

      get "#{base_url}/counts", params: { team_id: team.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq('active' => 2, 'completed' => 1, 'cancelled' => 1)
    end
  end

  describe 'progresso nos cartoes' do
    it 'a lista traz os numeros sem os tickets, e o cancelado nao entra na conta' do
      project = create(:project, team: team)
      create_project_ticket(project)
      create_project_ticket(project).update!(status: :resolved)
      create_project_ticket(project).update!(status: :cancelled)

      get base_url, headers: agent.create_new_auth_token, as: :json

      card = response.parsed_body.first
      expect(card).not_to have_key('tickets')
      expect(card['tickets_count']).to eq(2)
      expect(card['completed_tickets_count']).to eq(1)
      expect(card['tickets_completed']).to be(false)
    end

    it 'o detalhe traz os tickets e os mesmos numeros' do
      project = create(:project, team: team)
      create_project_ticket(project).update!(status: :resolved)
      create_project_ticket(project).update!(status: :cancelled)

      get "#{base_url}/#{project.id}", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['tickets'].size).to eq(2)
      expect(response.parsed_body['tickets_count']).to eq(1)
      expect(response.parsed_body['completed_tickets_count']).to eq(1)
      expect(response.parsed_body['tickets_completed']).to be(true)
    end
  end

  describe 'PATCH /projects/:id' do
    # Antes a tela enviava o campo, mas a API o ignorava e nao o devolvia.
    it 'salva e devolve a data de inicio de uso do sistema, mesmo para um agente' do
      project = create(:project, team: team)

      patch "#{base_url}/#{project.id}",
            params: { project: { system_started_on: '2026-10-01' } },
            headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['system_started_on']).to eq('2026-10-01')
      expect(project.reload.system_started_on).to eq(Date.new(2026, 10, 1))
    end
  end

  describe 'POST /projects (com tarefas)' do
    let(:template) { create(:project_task_template, account: account) }
    let(:tasks) { [{ task_template_id: template.id, due_date: 3.days.from_now.iso8601 }] }

    it 'cria o projeto e o ticket de cada tarefa de uma vez' do
      expect do
        post base_url,
             params: { project: { name: 'Implantação ACME', team_id: team.id }, tasks: tasks },
             headers: administrator.create_new_auth_token, as: :json
      end.to change(Project, :count).by(1).and change(Ticket, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['tickets'].size).to eq(1)
    end

    # Antes o projeto ficava criado sem tarefas, e tentar de novo criava um segundo.
    it 'nao cria nada quando as tarefas nao podem ser geradas' do
      # Modelo de tarefa de outra conta: o servico nao o encontra e nao gera o ticket.
      foreign_tasks = [{ task_template_id: create(:project_task_template).id }]

      expect do
        post base_url,
             params: { project: { name: 'Implantação ACME', team_id: team.id }, tasks: foreign_tasks },
             headers: administrator.create_new_auth_token, as: :json
      end.to not_change(Project, :count).and not_change(Ticket, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'continua criando so o projeto quando nao ha tarefas' do
      expect do
        post base_url,
             params: { project: { name: 'Sem módulo', team_id: team.id } },
             headers: administrator.create_new_auth_token, as: :json
      end.to change(Project, :count).by(1).and not_change(Ticket, :count)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /projects/:id/generate_tickets' do
    it 'nao duplica a tarefa se for gerada de novo' do
      template = create(:project_task_template, account: account)
      project = create(:project, team: team)
      params = { tasks: [{ task_template_id: template.id }] }

      post "#{base_url}/#{project.id}/generate_tickets", params: params, headers: agent.create_new_auth_token, as: :json
      post "#{base_url}/#{project.id}/generate_tickets", params: params, headers: agent.create_new_auth_token, as: :json

      expect(project.tickets.count).to eq(1)
    end
  end

  describe 'POST /projects/:id/cancel e /reactivate' do
    it 'cancela com motivo e reativa' do
      project = create(:project, team: team, stage: 'onboarding')

      post "#{base_url}/#{project.id}/cancel", params: { reason: 'Cliente desistiu' },
                                               headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['status']).to eq('cancelled')

      post "#{base_url}/#{project.id}/reactivate", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['status']).to eq('active')
    end

    it 'recusa cancelar um projeto finalizado' do
      project = create(:project, team: team, stage: 'finalizado')

      post "#{base_url}/#{project.id}/cancel", params: { reason: 'x' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /projects/:id' do
    it 'so o administrador exclui' do
      project = create(:project, team: team)

      delete "#{base_url}/#{project.id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(Project.exists?(project.id)).to be(true)

      delete "#{base_url}/#{project.id}", headers: administrator.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      expect(Project.exists?(project.id)).to be(false)
    end
  end
end
