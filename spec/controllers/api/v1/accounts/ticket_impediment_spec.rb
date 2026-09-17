require 'rails_helper'

# As duas acoes de impedimento pela API, mais o filtro que alimenta a tela
# "Tickets impedidos". O que interessa aqui e o contrato: quem pode chamar, o
# que a resposta carrega e o que sobra no banco.
RSpec.describe 'Ticket impediment', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:ticket) { create(:ticket, account: account, ticket_column: column, team: team) }

  def auth(user)
    user.create_new_auth_token
  end

  def act(action, record, params = {}, user: administrator)
    patch "/api/v1/accounts/#{account.id}/tickets/#{record.id}/#{action}",
          params: params, headers: auth(user), as: :json
  end

  describe 'PATCH /block' do
    it 'blocks the ticket and answers with the impediment in the payload' do
      act(:block, ticket, { reason: 'Aguardando retorno do cliente' })

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['blocked']).to be(true)
      expect(body['blocked_reason']).to eq('Aguardando retorno do cliente')
      expect(body['blocked_by']['id']).to eq(administrator.id)
    end

    it 'creates the internal comment with the reason' do
      expect { act(:block, ticket, { reason: 'Falta aprovacao do gestor' }) }
        .to change { ticket.ticket_comments.count }.by(1)

      expect(ticket.ticket_comments.order(:id).last.content).to eq('Falta aprovacao do gestor')
    end

    it 'rejects a blank reason without touching the ticket' do
      act(:block, ticket, { reason: '' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload).not_to be_blocked
    end

    # Impedir e tratativa do ticket: segue a mesma regra de `update?`, entao quem
    # nao e admin, responsavel nem membro da Mesa nao passa.
    it 'refuses an agent who does not handle the ticket' do
      estranho = create(:user, account: account, role: :agent)

      act(:block, ticket, { reason: 'Tentativa indevida' }, user: estranho)

      expect(response).to have_http_status(:unauthorized)
      expect(ticket.reload).not_to be_blocked
    end

    it 'allows a member of the ticket desk' do
      membro = create(:user, account: account, role: :agent)
      team.add_members([membro.id])

      act(:block, ticket, { reason: 'Dependencia de outro time' }, user: membro)

      expect(response).to have_http_status(:success)
      expect(ticket.reload.blocked_by).to eq(membro)
    end
  end

  describe 'PATCH /unblock' do
    before { ticket.block!(administrator, reason: 'Aguardando terceiro') }

    it 'clears the impediment' do
      act(:unblock, ticket)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['blocked']).to be(false)
      expect(ticket.reload).not_to be_blocked
    end

    it 'records the removal in the history and in the comments' do
      expect { act(:unblock, ticket) }
        .to change { ticket.ticket_activities.where(activity_type: :unblocked).count }.by(1)

      expect(ticket.ticket_comments.order(:id).last.content).to include(administrator.name)
    end

    it 'refuses an agent who does not handle the ticket' do
      estranho = create(:user, account: account, role: :agent)

      act(:unblock, ticket, {}, user: estranho)

      expect(response).to have_http_status(:unauthorized)
      expect(ticket.reload).to be_blocked
    end
  end

  describe 'GET /tickets?blocked=true' do
    let!(:impedido) { create(:ticket, account: account, ticket_column: column, team: team) }
    let!(:normal) { create(:ticket, account: account, ticket_column: column, team: team) }

    before { impedido.block!(administrator, reason: 'Travado') }

    def listar(params)
      get "/api/v1/accounts/#{account.id}/tickets", params: params, headers: auth(administrator), as: :json
      response.parsed_body['payload'].map { |t| t['id'] }
    end

    it 'returns only blocked tickets' do
      ids = listar({ blocked: true })

      expect(ids).to include(impedido.id)
      expect(ids).not_to include(normal.id)
    end

    it 'returns only non-blocked tickets when asked for the opposite' do
      ids = listar({ blocked: false })

      expect(ids).to include(normal.id)
      expect(ids).not_to include(impedido.id)
    end

    # A garantia de que a funcionalidade nao mexeu na listagem de sempre.
    it 'returns both when the filter is absent' do
      ids = listar({})

      expect(ids).to include(impedido.id, normal.id)
    end
  end
end
