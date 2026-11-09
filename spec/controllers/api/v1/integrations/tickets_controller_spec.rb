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

    it 'filters by ticket_column_id, ticket_category_id, company_id, assignee_id and updated_after' do
      categoria = create(:ticket_category, team: team)
      empresa = create(:company, account: account)
      agente = create(:user, account: account)
      alvo = create(:ticket, ticket_column: column, ticket_category: categoria, company: empresa, assignee: agente)
      create(:ticket, ticket_column: column) # outro ticket, nao deve aparecer nos filtros abaixo

      get '/api/v1/integrations/tickets', params: { ticket_column_id: column.id, ticket_category_id: categoria.id,
                                                    company_id: empresa.id, assignee_id: agente.id },
                                          headers: headers, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([alvo.id])
    end

    it 'filters by updated_after' do
      antigo = create(:ticket, ticket_column: column, updated_at: 2.days.ago)
      recente = create(:ticket, ticket_column: column, updated_at: 1.hour.ago)

      get '/api/v1/integrations/tickets', params: { updated_after: 1.day.ago }, headers: headers, as: :json

      ids = response.parsed_body['payload'].pluck('id')
      expect(ids).to include(recente.id)
      expect(ids).not_to include(antigo.id)
    end

    it 'includes the stage, category, company and assignee of each ticket' do
      categoria = create(:ticket_category, team: team)
      agente = create(:user, account: account)
      alvo = create(:ticket, ticket_column: column, ticket_category: categoria, assignee: agente)

      get '/api/v1/integrations/tickets', headers: headers, as: :json

      item = response.parsed_body['payload'].find { |t| t['id'] == alvo.id }
      expect(item['ticket_column_id']).to eq(column.id)
      expect(item['ticket_category_id']).to eq(categoria.id)
      expect(item['assignee_id']).to eq(agente.id)
      expect(item['assignee_name']).to eq(agente.name)
    end
  end

  # O numero do chamado ("#35369" na tela) nao e' o `id` do banco (o da URL): o filtro `display_id`
  # acha o ticket por ele, sem depender da Mesa.
  describe 'GET /api/v1/integrations/tickets?display_id=' do
    let!(:wanted) { create(:ticket, ticket_column: column) }
    let!(:other_team_ticket) { create(:ticket, ticket_column: create(:ticket_column, team: create(:team, account: account))) }

    it 'finds the ticket by its number, whatever the Mesa, exposing display_id' do
      get '/api/v1/integrations/tickets', params: { display_id: other_team_ticket.display_id }, headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([other_team_ticket.id])
      expect(response.parsed_body['payload'].first['display_id']).to eq(other_team_ticket.display_id)
    end

    it 'finds nothing for a number that does not exist' do
      get '/api/v1/integrations/tickets', params: { display_id: 999_999_999 }, headers: headers

      expect(response.parsed_body['payload']).to eq([])
    end

    it 'does not find the number of a ticket from another account' do
      foreign = create(:ticket)
      foreign.update_column(:display_id, wanted.display_id) # rubocop:disable Rails/SkipsModelValidations

      get '/api/v1/integrations/tickets', params: { display_id: wanted.display_id }, headers: headers

      expect(response.parsed_body['payload'].pluck('id')).to eq([wanted.id])
    end
  end

  describe 'GET /api/v1/integrations/tickets (campos do Jira)' do
    it 'lists the Jira card fields on each item' do
      ticket = create(:ticket, ticket_column: column, custom_attributes: { 'analise' => 'Texto' })
      get '/api/v1/integrations/tickets', headers: headers
      item = response.parsed_body['payload'].find { |t| t['id'] == ticket.id }
      expect(item).to include('analise' => 'Texto', 'observacoes_dev' => nil)
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

    it 'returns custom_attributes and the assignee' do
      agente = create(:user, account: account)
      ticket.update!(assignee: agente, custom_attributes: { 'analysis' => 'Causa raiz: timeout no gateway' })

      get "/api/v1/integrations/tickets/#{ticket.id}", headers: headers, as: :json

      body = response.parsed_body
      expect(body['custom_attributes']).to eq('analysis' => 'Causa raiz: timeout no gateway')
      expect(body['assignee']).to include('id' => agente.id, 'name' => agente.name)
    end
  end

  describe 'POST /api/v1/integrations/tickets' do
    # title, description, priority e ticket_category sao obrigatorios na
    # CRIACAO em qualquer caminho (TicketOpening, `validates ..., on: :create`)
    # - a API de integracao nao abre excecao nenhuma a essa regra.
    let(:categoria) { create(:ticket_category, team: team) }
    let(:required_fields) do
      { title: 'Erro ao gerar NFe', description: 'Descricao do problema', priority: 'high',
        ticket_column_id: column.id, ticket_category_id: categoria.id }
    end

    it 'creates a ticket with the required fields' do
      post '/api/v1/integrations/tickets', params: { ticket: required_fields }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      created = Ticket.find(response.parsed_body['id'])
      expect(created.title).to eq('Erro ao gerar NFe')
      expect(created.team_id).to eq(team.id)
      activity = created.ticket_activities.find_by(activity_type: :created)
      expect(activity.meta['origin']).to eq('integration_api')
    end

    it 'accepts company, contact, complexity, assignee and custom_attributes' do
      empresa = create(:company, account: account)
      contato = create(:contact, account: account, company_id: empresa.id)
      complexidade = create(:ticket_complexity, account: account, teams: [team])
      agente = create(:user, account: account)
      create(:team_member, user: agente, team: team)

      post '/api/v1/integrations/tickets',
           params: { ticket: required_fields.merge(
             company_id: empresa.id, contact_id: contato.id, ticket_complexity_id: complexidade.id,
             assignee_id: agente.id, custom_attributes: { 'analysis' => 'Nota fiscal rejeitada' }
           ) },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      created = Ticket.find(response.parsed_body['id'])
      expect(created.company_id).to eq(empresa.id)
      expect(created.assignee_id).to eq(agente.id)
      expect(created.custom_attributes).to eq('analysis' => 'Nota fiscal rejeitada')
    end

    it 'accepts the Jira card fields as top-level keys and exposes them' do
      post '/api/v1/integrations/tickets',
           params: { ticket: required_fields.merge(analise: 'Causa raiz', documentacao: 'Link') },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body).to include('analise' => 'Causa raiz', 'documentacao' => 'Link', 'observacoes_dev' => nil)
      expect(Ticket.find(body['id']).custom_attributes).to eq('analise' => 'Causa raiz', 'documentacao' => 'Link')
    end

    it '422s without a title' do
      post '/api/v1/integrations/tickets', params: { ticket: required_fields.except(:title) },
                                           headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a ticket_column_id from another account' do
      outro_column = create(:ticket_column)
      post '/api/v1/integrations/tickets', params: { ticket: { title: 'X', ticket_column_id: outro_column.id } },
                                           headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
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

    it 'updates the priority' do
      patch "/api/v1/integrations/tickets/#{ticket.id}/route", params: { priority: 'urgent' }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.priority).to eq('urgent')
    end

    it '422s for an invalid priority instead of a 500' do
      patch "/api/v1/integrations/tickets/#{ticket.id}/route", params: { priority: 'nao-existe' }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'sets the assignee, scoped to the key\'s own account' do
      agente = create(:user, account: account)

      patch "/api/v1/integrations/tickets/#{ticket.id}/route", params: { assignee_id: agente.id }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.assignee_id).to eq(agente.id)
    end

    it '404s for an assignee from another account' do
      agente_de_outra_conta = create(:user)

      patch "/api/v1/integrations/tickets/#{ticket.id}/route", params: { assignee_id: agente_de_outra_conta.id },
                                                               headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'accepts long text in the Jira card fields, but keeps the 1500 cap on any other key' do
      longo = 'a' * 5000

      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { custom_attributes: { analise: longo, observacoes_dev: longo } },
            headers: headers, as: :json
      expect(response).to have_http_status(:success)
      expect(ticket.reload.custom_attributes['analise'].length).to eq(5000)

      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { custom_attributes: { outra_chave: longo } },
            headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'merges custom_attributes instead of replacing the whole jsonb' do
      ticket.update!(custom_attributes: { 'feature' => ['Vendas'] })

      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { custom_attributes: { 'analysis' => 'Causa raiz identificada' } },
            headers: headers, as: :json

      expect(response).to have_http_status(:success)
      ticket.reload
      expect(ticket.custom_attributes).to eq('feature' => ['Vendas'], 'analysis' => 'Causa raiz identificada')
    end

    it 'accepts the Jira card fields top-level, on route and on PATCH /tickets/:id' do
      ticket.update!(custom_attributes: { 'feature' => ['Vendas'] })

      patch "/api/v1/integrations/tickets/#{ticket.id}/route",
            params: { observacoes_dev: 'Obs dev' }, headers: headers, as: :json
      patch "/api/v1/integrations/tickets/#{ticket.id}",
            params: { observacoes_teste: 'Obs teste', instrucoes: 'Passo a passo' }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('observacoes_dev' => 'Obs dev', 'observacoes_teste' => 'Obs teste')
      expect(ticket.reload.custom_attributes).to eq(
        'feature' => ['Vendas'], 'observacoes_dev' => 'Obs dev', 'observacoes_teste' => 'Obs teste',
        'instrucoes' => 'Passo a passo'
      )
    end
  end
end
