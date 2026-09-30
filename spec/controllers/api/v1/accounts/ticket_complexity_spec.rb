require 'rails_helper'

# A Complexidade no ticket: escolher, trocar, filtrar e o que ela impede no
# fechamento.
RSpec.describe 'Ticket complexity', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  let(:suporte) { create(:team, account: account, name: 'Suporte') }
  let(:comercial) { create(:team, account: account, name: 'Comercial') }
  let(:coluna_suporte) { create(:ticket_column, team: suporte, position: 0) }
  let(:coluna_comercial) { create(:ticket_column, team: comercial, position: 0) }

  # A matriz do pedido: Baixo em todas as Mesas, Alto so no Suporte.
  let!(:baixo) { create(:ticket_complexity, account: account, name: 'Baixo', teams: [suporte, comercial]) }
  let!(:alto) { create(:ticket_complexity, account: account, name: 'Alto', teams: [suporte]) }

  # O ticket exige descricao, prioridade e Categoria; sem elas o 422 nao diria
  # nada sobre Complexidade.
  def criar(params)
    team = account.teams.find(params[:team_id])
    base = { description: 'detalhes', priority: 'medium',
             ticket_category_id: team.ticket_categories.first&.id }

    post "/api/v1/accounts/#{account.id}/tickets",
         params: { ticket: base.merge(params) },
         headers: administrator.create_new_auth_token, as: :json
  end

  def alterar(ticket, params)
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}",
          params: { ticket: params }, headers: administrator.create_new_auth_token, as: :json
  end

  def ticket_em(team, column, extra = {})
    create(:ticket, { account: account, team: team, ticket_column: column }.merge(extra))
  end

  describe 'criacao' do
    it 'records the complexity chosen on the form' do
      criar({ title: 'Erro na emissao', team_id: suporte.id,
              ticket_column_id: coluna_suporte.id, ticket_complexity_id: alto.id })

      expect(response).to have_http_status(:success)
      expect(Ticket.find(response.parsed_body['id']).ticket_complexity).to eq(alto)
    end

    it 'answers with the name, so the card does not show an id' do
      criar({ title: 'Erro', team_id: suporte.id,
              ticket_column_id: coluna_suporte.id, ticket_complexity_id: alto.id })

      expect(response.parsed_body['ticket_complexity_name']).to eq('Alto')
    end

    # Compatibilidade: o campo e opcional no registro, e abrir sem ele continua
    # valendo - a exigencia e so no fechamento.
    it 'still opens a ticket without any complexity' do
      criar({ title: 'Erro', team_id: suporte.id, ticket_column_id: coluna_suporte.id })

      expect(response).to have_http_status(:success)
      expect(Ticket.find(response.parsed_body['id']).ticket_complexity_id).to be_nil
    end

    # A regra e da Mesa, e vale no SERVIDOR: a tela filtrar a lista e
    # conveniencia.
    it 'refuses a complexity the Mesa does not offer' do
      criar({ title: 'Proposta', team_id: comercial.id,
              ticket_column_id: coluna_comercial.id, ticket_complexity_id: alto.id })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a complexity that is deactivated' do
      baixo.update!(active: false)

      criar({ title: 'Erro', team_id: suporte.id,
              ticket_column_id: coluna_suporte.id, ticket_complexity_id: baixo.id })

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'edicao' do
    it 'changes the complexity of an existing ticket' do
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: baixo)

      alterar(ticket, { ticket_complexity_id: alto.id })

      expect(response).to have_http_status(:success)
      expect(ticket.reload.ticket_complexity).to eq(alto)
    end

    it 'clears it again' do
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: alto)

      alterar(ticket, { ticket_complexity_id: '' })

      expect(ticket.reload.ticket_complexity_id).to be_nil
    end

    it 'refuses a complexity the Mesa does not offer' do
      ticket = ticket_em(suporte, coluna_suporte)

      alterar(ticket, { ticket_complexity_id: alto.id })
      expect(response).to have_http_status(:success)

      ticket_comercial = ticket_em(comercial, coluna_comercial)
      alterar(ticket_comercial, { ticket_complexity_id: alto.id })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket_comercial.reload.ticket_complexity_id).to be_nil
    end
  end

  # O caso do pedido: a Mesa muda e o nivel atual nao existe na Mesa nova.
  #
  # Segue a mesma regra da Categoria (TicketOpening): a troca NAO e recusada - o
  # valor incompativel e limpado, e quem fica sem Complexidade precisa escolher
  # outra antes de fechar. Recusar a troca deixaria o ticket preso na Mesa errada.
  describe 'troca de Mesa' do
    def transferir(ticket, params)
      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/transfer",
            params: { ticket: params }, headers: administrator.create_new_auth_token, as: :json
    end

    it 'clears a complexity the new Mesa does not offer, instead of blocking the move' do
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: alto)

      transferir(ticket, { team_id: comercial.id, ticket_column_id: coluna_comercial.id })

      expect(response).to have_http_status(:success)
      ticket.reload
      expect(ticket.team).to eq(comercial)
      expect(ticket.ticket_complexity_id).to be_nil
    end

    # E o fechamento passa a cobrar a escolha nova - e assim que o pedido "exigir
    # que o usuario selecione uma nova" se realiza.
    it 'then demands a new one before the ticket can be closed' do
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: alto)
      transferir(ticket, { team_id: comercial.id, ticket_column_id: coluna_comercial.id })

      expect(ticket.reload.missing_close_requirements).to include('ticket_complexity')
    end

    # O nivel que a Mesa nova TAMBEM oferece sobrevive a troca.
    it 'keeps a complexity both Mesas offer' do
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: baixo)

      transferir(ticket, { team_id: comercial.id, ticket_column_id: coluna_comercial.id })

      expect(ticket.reload.ticket_complexity).to eq(baixo)
    end

    # Um ticket gravado quando a matriz era outra nao pode ficar impossivel de
    # salvar por causa de um campo que ninguem tocou.
    it 'lets an untouched ticket be saved after the matrix changed under it' do
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: alto)
      alto.replace_teams!([])

      alterar(ticket, { title: 'Outro titulo' })

      expect(response).to have_http_status(:success)
      expect(ticket.reload.title).to eq('Outro titulo')
    end
  end

  describe 'fechamento' do
    # Fechar exige mais do que Complexidade: Categoria, Catalogo e a comunicacao de
    # encerramento. Estes exemplos ISOLAM a Complexidade deixando o resto
    # satisfeito - a Categoria vem da fabrica, o Catalogo entra aqui, e a
    # comunicacao usa a propria valvula do produto (`customer_email_deliverable?`),
    # que dispensa o envio onde nao ha como enviar.
    def ticket_pronto_para_fechar(complexity: nil)
      ticket = ticket_em(suporte, coluna_suporte, ticket_complexity: complexity)
      ticket.update!(service_catalog_item: create(:service_catalog_item))
      allow_any_instance_of(Ticket).to receive(:customer_email_deliverable?).and_return(false) # rubocop:disable RSpec/AnyInstance
      ticket
    end

    it 'blocks the close while there is no complexity' do
      ticket = ticket_pronto_para_fechar

      expect(ticket.missing_close_requirements).to include('ticket_complexity')
      expect(ticket.closeable?).to be(false)
      expect { ticket.close! }.to raise_error(TicketClosing::NotAllowed)
    end

    it 'closes once the complexity is set' do
      ticket = ticket_pronto_para_fechar(complexity: alto)

      expect(ticket.missing_close_requirements).not_to include('ticket_complexity')
      expect { ticket.close! }.not_to raise_error
      expect(ticket.reload.status).to eq('closed')
    end

    # A recusa tem de vir do SERVIDOR, e nao so da tela.
    it 'refuses the close over the API, with the reason' do
      ticket = ticket_pronto_para_fechar

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/close",
            headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['missing']).to include('ticket_complexity')
      expect(ticket.reload.status).to eq('open')
    end

    it 'accepts the close over the API once it is set' do
      ticket = ticket_pronto_para_fechar(complexity: alto)

      patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/close",
            headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(ticket.reload.status).to eq('closed')
    end

    # Compatibilidade com o que existia: numa Mesa que nao oferece nivel nenhum,
    # exigir Complexidade trancaria o ticket sem que exista acao capaz de
    # destranca-lo.
    it 'does not require it in a Mesa that offers no complexity at all' do
      baixo.replace_teams!([suporte])
      outra = create(:team, account: account)
      ticket = ticket_em(outra, create(:ticket_column, team: outra))
      ticket.update!(service_catalog_item: create(:service_catalog_item))
      allow_any_instance_of(Ticket).to receive(:customer_email_deliverable?).and_return(false) # rubocop:disable RSpec/AnyInstance

      expect(ticket.missing_close_requirements).not_to include('ticket_complexity')
      expect { ticket.close! }.not_to raise_error
    end

    it 'requires it again as soon as the Mesa offers a level' do
      outra = create(:team, account: account)
      ticket = ticket_em(outra, create(:ticket_column, team: outra))
      expect(ticket.missing_close_requirements).not_to include('ticket_complexity')

      baixo.replace_teams!([suporte, comercial, outra])

      expect(ticket.reload.missing_close_requirements).to include('ticket_complexity')
    end
  end

  describe 'a Busca detalhada' do
    def buscar(params)
      get "/api/v1/accounts/#{account.id}/tickets",
          params: params, headers: administrator.create_new_auth_token, as: :json
    end

    def ids_encontrados
      response.parsed_body['payload'].map { |item| item['id'] }
    end

    it 'filters by one complexity' do
      com_alto = ticket_em(suporte, coluna_suporte, ticket_complexity: alto)
      com_baixo = ticket_em(suporte, coluna_suporte, ticket_complexity: baixo)

      buscar(ticket_complexity_id: alto.id)

      expect(ids_encontrados).to include(com_alto.id)
      expect(ids_encontrados).not_to include(com_baixo.id)
    end

    # Varias complexidades no mesmo filtro sao um "ou", como nos demais filtros.
    it 'filters by more than one at once' do
      com_alto = ticket_em(suporte, coluna_suporte, ticket_complexity: alto)
      com_baixo = ticket_em(suporte, coluna_suporte, ticket_complexity: baixo)
      sem_nada = ticket_em(suporte, coluna_suporte)

      buscar(ticket_complexity_id: [alto.id, baixo.id])

      expect(ids_encontrados).to include(com_alto.id, com_baixo.id)
      expect(ids_encontrados).not_to include(sem_nada.id)
    end

    it 'does not filter at all when nothing is asked' do
      ticket_em(suporte, coluna_suporte, ticket_complexity: alto)
      sem_nada = ticket_em(suporte, coluna_suporte)

      buscar({})

      expect(ids_encontrados).to include(sem_nada.id)
    end
  end

  describe 'a disponibilidade por Mesa' do
    it 'lists only what the Mesa offers' do
      expect(TicketComplexity.available_for_team(suporte.id)).to contain_exactly(baixo, alto)
      expect(TicketComplexity.available_for_team(comercial.id)).to contain_exactly(baixo)
    end

    # `active` vale SOBRE a matriz: desligado na conta, nao aparece em Mesa
    # nenhuma.
    it 'hides a deactivated level from every Mesa' do
      alto.update!(active: false)

      expect(TicketComplexity.available_for_team(suporte.id)).to contain_exactly(baixo)
    end
  end
end
