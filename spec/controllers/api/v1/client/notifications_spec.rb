require 'rails_helper'

# A aba "Notificacoes" do Portal do Cliente. O que se prova aqui: abrir
# (dispensar) um item some ele da lista, "limpar tudo" some com o que esta
# visivel agora, e a fronteira entre contatos - o que um dispensa nao pode
# afetar o que o outro ve.
RSpec.describe 'Client notifications', type: :request do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }

  let(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br', company: empresa)
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  def entrar(email: 'cliente@exemplo.com.br', senha: 'SenhaDoCliente@01')
    post '/api/v1/client/session', params: { email: email, password: senha }, as: :json
    response.parsed_body['api_access_token']
  end

  def cabecalho
    cliente
    { api_access_token: entrar }
  end

  def ticket_da(contato: cliente, company: empresa)
    create(:ticket, account: account, team: team, contact: contato, company: company,
                    ticket_column: create(:ticket_column, team: team, position: 0))
  end

  def comunicacao_em(ticket, corpo: 'Resposta da equipe')
    create(:ticket_customer_communication, ticket: ticket, user: agente, account: account,
                                           direction: 'outbound', body: corpo)
  end

  def listar(headers)
    get '/api/v1/client/notifications', headers: headers, as: :json
  end

  def chaves_listadas
    response.parsed_body.map { |item| item['id'] }
  end

  describe 'GET index' do
    it 'lists a communication the team sent on the contact ticket' do
      comunicacao_em(ticket_da)

      listar(cabecalho)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first['preview']).to include('Resposta da equipe')
    end
  end

  describe 'POST dismiss' do
    it 'removes the dismissed item from the next listing' do
      comunicacao = comunicacao_em(ticket_da)
      headers = cabecalho
      chave = "communication_#{comunicacao.id}"

      post "/api/v1/client/notifications/#{chave}/dismiss", headers: headers, as: :json
      expect(response).to have_http_status(:success)

      listar(headers)
      expect(chaves_listadas).not_to include(chave)
    end

    it 'does not delete the underlying communication, only hides it' do
      comunicacao = comunicacao_em(ticket_da)
      headers = cabecalho

      post "/api/v1/client/notifications/communication_#{comunicacao.id}/dismiss", headers: headers, as: :json

      expect(TicketCustomerCommunication.exists?(comunicacao.id)).to be(true)
    end

    it 'is idempotent - dismissing the same item twice does not error' do
      comunicacao = comunicacao_em(ticket_da)
      headers = cabecalho
      chave = "communication_#{comunicacao.id}"

      post "/api/v1/client/notifications/#{chave}/dismiss", headers: headers, as: :json
      post "/api/v1/client/notifications/#{chave}/dismiss", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(ClientNotificationDismissal.where(item_key: chave).count).to eq(1)
    end

    # A fronteira: dispensar e' por CONTATO - o colega da mesma empresa
    # continua vendo o que o cliente ja dispensou.
    it 'only hides the item for the contact who dismissed it' do
      # `sees_company`: sem isso o colega nem enxergaria o ticket do cliente -
      # o teste precisa provar que o DISMISS e' por contato, nao que a
      # fronteira de visibilidade de ticket existe (isso ja e' outro teste).
      colega = create(:contact, account: account, email: 'colega@exemplo.com.br', company: empresa,
                                client_tickets_visibility: :company)
      colega.enable_client_access!(password: 'OutraSenha@01')
      comunicacao = comunicacao_em(ticket_da)
      chave = "communication_#{comunicacao.id}"

      post "/api/v1/client/notifications/#{chave}/dismiss", headers: cabecalho, as: :json

      colega_headers = { api_access_token: entrar(email: 'colega@exemplo.com.br', senha: 'OutraSenha@01') }
      listar(colega_headers)

      expect(chaves_listadas).to include(chave)
    end
  end

  describe 'POST dismiss_all' do
    it 'clears every item currently visible' do
      comunicacao_em(ticket_da, corpo: 'Primeira')
      comunicacao_em(ticket_da, corpo: 'Segunda')
      headers = cabecalho

      post '/api/v1/client/notifications/dismiss_all', headers: headers, as: :json
      expect(response).to have_http_status(:success)

      listar(headers)
      expect(chaves_listadas).to be_empty
    end

    it 'does not hide an item that arrives after clearing' do
      comunicacao_em(ticket_da, corpo: 'Antiga')
      headers = cabecalho
      post '/api/v1/client/notifications/dismiss_all', headers: headers, as: :json

      nova = comunicacao_em(ticket_da, corpo: 'Nova, depois de limpar')

      listar(headers)
      expect(chaves_listadas).to eq(["communication_#{nova.id}"])
    end
  end
end
