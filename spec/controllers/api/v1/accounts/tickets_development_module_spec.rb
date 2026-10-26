require 'rails_helper'

# Fase 1 do Modulo de Desenvolvimento (Backlog + Sprints): o que se prova
# aqui e' que os campos novos (sprint_id, development_type, custom_attributes)
# e o checklist automatico funcionam - e que uma Mesa SEM o modulo ativado
# continua se comportando exatamente como antes (nada de novo aparece sozinho).
RSpec.describe 'Tickets API - Modulo de Desenvolvimento', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:ticket_column) { create(:ticket_column, team: team) }

  def creation_params(extra = {})
    { title: 'DM-1 Corrige X', description: 'detalhes', priority: 'medium',
      ticket_column_id: ticket_column.id,
      ticket_category_id: team.ticket_categories.first.id }.merge(extra)
  end

  def criar_ticket(extra = {})
    post "/api/v1/accounts/#{account.id}/tickets",
         params: { ticket: creation_params(extra) },
         headers: agent.create_new_auth_token, as: :json
  end

  describe 'campos novos no ticket' do
    it 'aceita sprint_id e development_type na criacao' do
      sprint = create(:sprint, account: account, team: team)

      criar_ticket(sprint_id: sprint.id, development_type: 'bug')

      expect(response).to have_http_status(:success)
      ticket = Ticket.find(response.parsed_body['id'])
      expect(ticket.sprint_id).to eq(sprint.id)
      expect(ticket.development_type).to eq('bug')
    end

    it 'aceita custom_attributes e devolve no payload' do
      criar_ticket(custom_attributes: { 'resolucao' => 'Definitiva', 'retrabalho' => false })

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['custom_attributes']).to eq(
        'resolucao' => 'Definitiva', 'retrabalho' => false
      )
    end

    it 'um ticket sem sprint (Backlog) devolve sprint_id e sprint_name nulos' do
      criar_ticket
      expect(response.parsed_body['sprint_id']).to be_nil
      expect(response.parsed_body['sprint_name']).to be_nil
    end
  end

  describe 'checklist automatico (Team#default_checklist)' do
    it 'anexa o checklist padrao da Mesa a todo ticket novo' do
      checklist = create(:checklist, account: account,
                                     items: [{ 'title' => 'Debug em toda a area', 'type' => 'checkbox' },
                                             { 'title' => 'Teste do caminho feliz', 'type' => 'checkbox' }])
      team.update!(default_checklist: checklist)

      criar_ticket

      ticket = Ticket.find(response.parsed_body['id'])
      expect(ticket.ticket_checklist_items.pluck(:title)).to eq(
        ['Debug em toda a area', 'Teste do caminho feliz']
      )
    end

    it 'nao anexa nada quando a Mesa nao tem checklist padrao (comportamento de hoje)' do
      criar_ticket
      ticket = Ticket.find(response.parsed_body['id'])
      expect(ticket.ticket_checklist_items).to be_empty
    end
  end

  describe 'Backlog - listagem de tickets por sprint' do
    it 'filtra por sprint_id' do
      sprint = create(:sprint, account: account, team: team)
      criar_ticket(sprint_id: sprint.id)
      criar_ticket

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { sprint_id: sprint.id },
          headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('sprint_id')).to eq([sprint.id])
    end

    it 'filtra o Backlog (sem sprint) com without_sprint' do
      sprint = create(:sprint, account: account, team: team)
      criar_ticket(sprint_id: sprint.id)
      criar_ticket

      get "/api/v1/accounts/#{account.id}/tickets",
          params: { team_id: team.id, without_sprint: true },
          headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('sprint_id')).to eq([nil])
    end
  end

  describe 'Mesa sem o modulo ativado continua igual' do
    it 'development_module_enabled comeca desligado por padrao' do
      expect(team.development_module_enabled).to be(false)
    end

    it 'o payload do time inclui o flag, desligado por padrao' do
      get "/api/v1/accounts/#{account.id}/teams/#{team.id}",
          headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['development_module_enabled']).to be(false)
      expect(response.parsed_body['default_checklist_id']).to be_nil
    end
  end

  describe 'PATCH configuracao da Mesa' do
    it 'admin liga o modulo e define o checklist padrao' do
      administrator = create(:user, account: account, role: :administrator)
      checklist = create(:checklist, account: account)

      patch "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: { team: { development_module_enabled: true, default_checklist_id: checklist.id } },
            headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(team.reload.development_module_enabled).to be(true)
      expect(team.default_checklist_id).to eq(checklist.id)
    end
  end
end
