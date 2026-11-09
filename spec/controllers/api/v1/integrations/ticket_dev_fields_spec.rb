require 'rails_helper'

# Os campos do desenvolvimento e a regra de Mesa/Estagio da API de Integracao de
# Tickets: `development_type` (bug, task, story), `sprint_id`, o Estagio sem Mesa
# (que era ignorado em silencio) e a nota fora da triagem. O `create` recebe os
# campos aninhados em `ticket`; `PATCH /tickets/:id` e `route` sao a mesma acao.
RSpec.describe 'Ticket Integration API - desenvolvimento e destino', type: :request do
  let(:account) { create(:account) }
  let!(:ticket_api_key) { create(:ticket_api_key, account: account) }
  let(:headers) { { 'X-Ticket-Api-Key' => ticket_api_key.token } }
  let(:other_account) { create(:account) }

  # `create(:team)` ja provisiona Estagios e Categorias padrao.
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team) }
  let(:other_team) { create(:team, account: account) }
  let(:other_team_column) { other_team.ticket_columns.order(:position, :id).first }
  let(:foreign_team) { create(:team, account: other_account) }
  let(:foreign_column) { foreign_team.ticket_columns.order(:position, :id).first }
  let(:ticket) { create(:ticket, ticket_column: column) }

  let(:sprint) { create(:sprint, account: account, team: team) }

  let(:required_fields) do
    { title: 'Erro ao gerar NFe', description: 'Descricao do problema', priority: 'high',
      ticket_column_id: column.id, ticket_category_id: create(:ticket_category, team: team).id }
  end

  def post_ticket(extra = {})
    post '/api/v1/integrations/tickets', params: { ticket: required_fields.merge(extra) }, headers: headers, as: :json
  end

  def patch_ticket(params, target = ticket)
    patch "/api/v1/integrations/tickets/#{target.id}", params: params, headers: headers, as: :json
  end

  describe 'development_type' do
    it 'keeps bug and task stored as they always were, and adds story' do
      expect(Ticket.development_types).to eq('bug' => 0, 'task' => 1, 'story' => 2)
    end

    %w[bug task story].each do |tipo|
      it "creates a ticket as #{tipo} and returns it" do
        post_ticket(development_type: tipo)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['development_type']).to eq(tipo)
      end

      it "sets #{tipo} on PATCH" do
        patch_ticket(development_type: tipo)

        expect(response).to have_http_status(:success)
        expect(ticket.reload.development_type).to eq(tipo)
      end
    end

    it 'refuses an invalid value on create' do
      post_ticket(development_type: 'epic')

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses an invalid value on PATCH, keeping the current one' do
      ticket.update!(development_type: 'bug')

      patch_ticket(development_type: 'epic')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('bug', 'task', 'story')
      expect(ticket.reload.development_type).to eq('bug')
    end

    it 'clears it when sent blank' do
      ticket.update!(development_type: 'task')

      patch_ticket(development_type: nil)

      expect(ticket.reload.development_type).to be_nil
    end

    it 'exposes it on the list and filters by it' do
      ticket.update!(development_type: 'story')
      create(:ticket, ticket_column: column)

      get '/api/v1/integrations/tickets', params: { development_type: 'story' }, headers: headers

      expect(response.parsed_body['payload'].pluck('id')).to eq([ticket.id])
      expect(response.parsed_body['payload'].first['development_type']).to eq('story')
    end
  end

  describe 'sprint_id' do
    it 'creates a ticket already in a sprint of its Mesa' do
      post_ticket(sprint_id: sprint.id)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['sprint_id']).to eq(sprint.id)
    end

    it 'puts the ticket in a sprint on PATCH and takes it back to the Backlog' do
      patch_ticket(sprint_id: sprint.id)
      expect(ticket.reload.sprint_id).to eq(sprint.id)

      patch_ticket(sprint_id: nil)
      expect(ticket.reload.sprint_id).to be_nil
    end

    it 'refuses a sprint from another Mesa, on create and on PATCH' do
      de_outra_mesa = create(:sprint, account: account, team: other_team)

      post_ticket(sprint_id: de_outra_mesa.id)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to include('sprint_id')

      patch_ticket(sprint_id: de_outra_mesa.id)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '404s for a sprint of another account and for one that does not exist' do
      alheio = create(:sprint, account: other_account, team: foreign_team)

      post_ticket(sprint_id: alheio.id)
      expect(response).to have_http_status(:not_found)

      patch_ticket(sprint_id: 0)
      expect(response).to have_http_status(:not_found)
    end

    # Trocar de Mesa deixaria o ticket num sprint de outra Mesa; em vez de limpar em
    # silencio, a API pede que quem chama diga para onde ele vai.
    it 'asks what to do with the sprint when the ticket changes Mesa' do
      ticket.update!(sprint: sprint)

      patch_ticket(ticket_column_id: other_team_column.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to include('sprint_id')
      expect(ticket.reload.team_id).to eq(team.id)
    end

    it 'changes Mesa when the sprint is sent along (blank for Backlog)' do
      ticket.update!(sprint: sprint)

      patch_ticket(ticket_column_id: other_team_column.id, sprint_id: nil)

      expect(response).to have_http_status(:success)
      expect(ticket.reload).to have_attributes(team_id: other_team.id, sprint_id: nil)
    end
  end

  # O defeito: `ticket_column_id` sem `team_id` era ignorado em silencio (so' era
  # aplicado com a Mesa junto), enquanto o `create` ja deduzia a Mesa pelo Estagio.
  describe 'Mesa e Estagio' do
    %w[PATCH\ /tickets/:id /route].each do |rota|
      path = ->(target) { rota.include?('route') ? "/api/v1/integrations/tickets/#{target.id}/route" : "/api/v1/integrations/tickets/#{target.id}" }

      context "with #{rota}" do
        it 'moves the ticket when only the Estagio is sent, deducing the Mesa' do
          patch path.call(ticket), params: { ticket_column_id: other_team_column.id }, headers: headers, as: :json

          expect(response).to have_http_status(:success)
          expect(ticket.reload).to have_attributes(team_id: other_team.id, ticket_column_id: other_team_column.id)
        end

        it 'refuses an Estagio that is not from the given Mesa, changing nothing' do
          patch path.call(ticket), params: { team_id: other_team.id, ticket_column_id: column.id }, headers: headers, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['attributes']).to include('ticket_column_id')
          expect(ticket.reload.ticket_column_id).to eq(column.id)
        end

        it '404s for an Estagio of another account, changing nothing' do
          patch path.call(ticket), params: { ticket_column_id: foreign_column.id }, headers: headers, as: :json

          expect(response).to have_http_status(:not_found)
          expect(ticket.reload.ticket_column_id).to eq(column.id)
        end

        it '404s for a Mesa of another account' do
          patch path.call(ticket), params: { team_id: foreign_team.id }, headers: headers, as: :json

          expect(response).to have_http_status(:not_found)
        end

        it 'sends the ticket to the first Estagio when only another Mesa is sent' do
          patch path.call(ticket), params: { team_id: other_team.id }, headers: headers, as: :json

          expect(response).to have_http_status(:success)
          expect(ticket.reload.ticket_column_id).to eq(other_team_column.id)
        end

        it 'does not move the ticket when the Mesa sent is the one it is already in' do
          patch path.call(ticket), params: { team_id: team.id }, headers: headers, as: :json

          expect(response).to have_http_status(:success)
          expect(ticket.reload.ticket_column_id).to eq(column.id)
        end

        it 'treats blank values as "do not move", as it always did' do
          patch path.call(ticket), params: { team_id: '', ticket_column_id: '', priority: 'low' }, headers: headers, as: :json

          expect(response).to have_http_status(:success)
          expect(ticket.reload).to have_attributes(ticket_column_id: column.id, priority: 'low')
        end
      end
    end

    it '404s for a ticket id that is not valid' do
      patch '/api/v1/integrations/tickets/abc', params: { priority: 'low' }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s for a ticket of another account' do
      alheio = create(:ticket, ticket_column: foreign_column)

      patch_ticket({ priority: 'low' }, alheio)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'note' do
    it 'keeps the triage prefix by default on /route' do
      patch "/api/v1/integrations/tickets/#{ticket.id}/route", params: { note: 'parece rede' }, headers: headers, as: :json

      nota = ticket.ticket_activities.find_by(activity_type: :automation_note)
      expect(nota.new_value).to eq('Direcionado automaticamente pela IA de triagem: parece rede')
    end

    it 'records the note exactly as sent when triage is false' do
      patch "/api/v1/integrations/tickets/#{ticket.id}/route", params: { note: 'migrado do fluxo antigo', triage: false },
                                                                headers: headers, as: :json

      nota = ticket.ticket_activities.find_by(activity_type: :automation_note)
      expect(nota.new_value).to eq('migrado do fluxo antigo')
      expect(nota.user).to be_nil
    end
  end

  # O model exige o responsavel na Mesa so' na CRIACAO (TicketOpening, `on: :create`),
  # de proposito; na atualizacao basta ser da conta. Outra conta, nunca.
  describe 'assignee_id' do
    let(:member) { create(:user, account: account, role: :agent).tap { |user| team.add_members([user.id]) } }
    let(:non_member) { create(:user, account: account, role: :agent) }
    let(:foreign_user) { create(:user, account: other_account, role: :agent) }

    it 'accepts a member of the Mesa on create' do
      post_ticket(assignee_id: member.id)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['assignee']['id']).to eq(member.id)
    end

    it 'refuses, on create, a user of the account who is not in the Mesa' do
      post_ticket(assignee_id: non_member.id)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'accepts, on PATCH, any user of the account' do
      patch_ticket(assignee_id: non_member.id)

      expect(response).to have_http_status(:success)
      expect(ticket.reload.assignee_id).to eq(non_member.id)
    end

    it '404s, on PATCH, for a user of another account' do
      patch_ticket(assignee_id: foreign_user.id)

      expect(response).to have_http_status(:not_found)
      expect(ticket.reload.assignee_id).to be_nil
    end
  end
end
