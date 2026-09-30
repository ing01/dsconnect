require 'rails_helper'

# Os niveis de Complexidade - Configuracoes > Tickets > Complexidade.
#
# Lista da CONTA, como o Catalogo de Servicos, com uma matriz que diz quais Mesas
# oferecem cada nivel. Nenhum nome esta fixo no codigo: criar, renomear e desligar
# e tudo dado.
RSpec.describe 'Ticket complexities API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let!(:suporte) { create(:team, account: account, name: 'Suporte') }
  let!(:implantacao) { create(:team, account: account, name: 'Implantacao') }

  def listar(user = administrator)
    get "/api/v1/accounts/#{account.id}/ticket_complexities",
        headers: user.create_new_auth_token, as: :json
  end

  def criar(params, user: administrator)
    post "/api/v1/accounts/#{account.id}/ticket_complexities",
         params: { ticket_complexity: params }, headers: user.create_new_auth_token, as: :json
  end

  def alterar(complexity, params, user: administrator)
    patch "/api/v1/accounts/#{account.id}/ticket_complexities/#{complexity.id}",
          params: { ticket_complexity: params }, headers: user.create_new_auth_token, as: :json
  end

  def nomes_listados
    response.parsed_body['payload'].map { |item| item['name'] }
  end

  describe 'GET index' do
    it 'refuses an unauthenticated caller' do
      get "/api/v1/accounts/#{account.id}/ticket_complexities"

      expect(response).to have_http_status(:unauthorized)
    end

    # Conta que existe desde antes desta funcionalidade nao pode abrir a tela
    # vazia. Os tres nomes vivem num lugar so (DefaultComplexitiesBuilder).
    it 'seeds the three starting levels on an account that has none' do
      listar

      expect(response).to have_http_status(:success)
      expect(nomes_listados).to eq(%w[Baixo Médio Alto])
    end

    # E toda Mesa comeca oferecendo os tres: a matriz existe para RESTRINGIR, e
    # comecar com tudo desmarcado deixaria os tickets sem opcao no dia da
    # atualizacao.
    it 'makes every level available to every Mesa at the start' do
      listar

      response.parsed_body['payload'].each do |item|
        expect(item['team_ids']).to contain_exactly(suporte.id, implantacao.id)
      end
    end

    # Semear e idempotente, e cego ao conteudo: quem renomeou ou apagou nao ve os
    # nomes voltarem.
    it 'does not seed again, nor undo a rename' do
      listar
      TicketComplexity.find_by(name: 'Médio').update!(name: 'Moderado')
      TicketComplexity.find_by(name: 'Alto').destroy!

      listar

      expect(nomes_listados).to eq(%w[Baixo Moderado])
    end

    it 'lists for a plain agent, who needs it to fill the ticket form' do
      listar(agent)

      expect(response).to have_http_status(:success)
      expect(nomes_listados).to be_present
    end

    it 'does not list another account levels' do
      create(:ticket_complexity, account: create(:account), name: 'De outra conta')

      listar

      expect(nomes_listados).not_to include('De outra conta')
    end

    it 'orders by position' do
      listar
      TicketComplexity.find_by(name: 'Alto').update!(position: -1)

      listar

      expect(nomes_listados.first).to eq('Alto')
    end
  end

  describe 'POST create' do
    # O pedido central da configuracao: um nivel novo sem alterar codigo.
    it 'creates a brand new level with the Mesas that offer it' do
      criar({ name: 'Crítico', team_ids: [suporte.id] })

      expect(response).to have_http_status(:success)
      complexity = TicketComplexity.find(response.parsed_body['id'])
      expect(complexity.name).to eq('Crítico')
      expect(complexity.team_ids).to eq([suporte.id])
      expect(complexity.active).to be(true)
    end

    it 'accepts a weight, for the cost step that comes later' do
      criar({ name: 'Crítico', weight: '2.5' })

      expect(TicketComplexity.find(response.parsed_body['id']).weight).to eq(2.5)
    end

    it 'refuses a negative weight' do
      criar({ name: 'Crítico', weight: '-1' })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a duplicated name in the same account' do
      criar({ name: 'Crítico' })
      criar({ name: 'Crítico' })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a nameless level' do
      criar({ name: '' })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Moldar a lista e do administrador; o agente apenas a le.
    it 'forbids a plain agent from creating one' do
      criar({ name: 'Crítico' }, user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(account.ticket_complexities.where(name: 'Crítico')).to be_empty
    end

    # A Mesa de outra conta nao entra na matriz: isso vazaria o nome dela para o
    # formulario deste cliente.
    it 'ignores a Mesa from another account' do
      alheia = create(:team, account: create(:account))

      criar({ name: 'Crítico', team_ids: [suporte.id, alheia.id] })

      expect(TicketComplexity.find(response.parsed_body['id']).team_ids).to eq([suporte.id])
    end
  end

  describe 'PATCH update' do
    let(:complexity) { create(:ticket_complexity, account: account, teams: [suporte, implantacao]) }

    it 'renames a level' do
      alterar(complexity, { name: 'Moderado' })

      expect(response).to have_http_status(:success)
      expect(complexity.reload.name).to eq('Moderado')
    end

    # Desativar e o caminho comum: o nivel sai dos formularios e continua nos
    # tickets que o usam.
    it 'deactivates without losing the level' do
      alterar(complexity, { active: false })

      expect(complexity.reload.active).to be(false)
      expect(TicketComplexity.exists?(complexity.id)).to be(true)
    end

    it 'reorders' do
      alterar(complexity, { position: 9 })

      expect(complexity.reload.position).to eq(9)
    end

    # A matriz: a tela manda o conjunto COMPLETO de Mesas.
    it 'replaces the Mesas that offer the level' do
      alterar(complexity, { team_ids: [implantacao.id] })

      expect(complexity.reload.team_ids).to eq([implantacao.id])
    end

    it 'can leave the level available to no Mesa at all' do
      alterar(complexity, { team_ids: [] })

      expect(complexity.reload.team_ids).to be_empty
    end

    # Renomear nao pode apagar a matriz de quem nao pediu isso.
    it 'leaves the matrix alone when the request does not mention it' do
      alterar(complexity, { name: 'Moderado' })

      expect(complexity.reload.team_ids).to contain_exactly(suporte.id, implantacao.id)
    end

    it 'forbids a plain agent' do
      alterar(complexity, { name: 'Moderado' }, user: agent)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not reach a level of another account' do
      alheio = create(:ticket_complexity, account: create(:account))

      patch "/api/v1/accounts/#{account.id}/ticket_complexities/#{alheio.id}",
            params: { ticket_complexity: { name: 'Invadido' } },
            headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy' do
    let(:complexity) { create(:ticket_complexity, account: account, teams: [suporte]) }

    it 'lets an administrator delete a level created by mistake' do
      delete "/api/v1/accounts/#{account.id}/ticket_complexities/#{complexity.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(TicketComplexity.exists?(complexity.id)).to be(false)
    end

    # O ponto sensivel: apagar um nivel EM USO nao pode apagar o ticket. Ele
    # apenas volta a ficar sem Complexidade.
    it 'keeps the tickets that used it, without the complexity' do
      column = create(:ticket_column, team: suporte)
      ticket = create(:ticket, account: account, team: suporte, ticket_column: column,
                               ticket_complexity: complexity)

      delete "/api/v1/accounts/#{account.id}/ticket_complexities/#{complexity.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload).to be_present
      expect(ticket.ticket_complexity_id).to be_nil
    end

    it 'forbids a plain agent' do
      delete "/api/v1/accounts/#{account.id}/ticket_complexities/#{complexity.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(TicketComplexity.exists?(complexity.id)).to be(true)
    end
  end
end
