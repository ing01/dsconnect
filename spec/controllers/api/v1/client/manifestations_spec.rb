require 'rails_helper'

# O SAC pela Area do Cliente.
#
# O que se prova aqui e a FRONTEIRA e o SIGILO: um contato so alcanca as
# manifestacoes da propria empresa, dentro da permissao dele, e nunca ve uma
# anotacao interna. Quem recusa e o servidor - a tela nao participa.
RSpec.describe 'Client manifestations', type: :request do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }
  let(:outra_empresa) { create(:company, account: account) }
  let(:agente) { create(:user, account: account, role: :agent) }

  let(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br', company: empresa)
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  # Outra pessoa da MESMA empresa: e com ela que se prova a diferenca entre
  # `sees_own` e `sees_company`.
  let(:colega) { create(:contact, account: account, email: 'colega@exemplo.com.br', company: empresa) }

  def entrar
    cliente
    post '/api/v1/client/session',
         params: { email: 'cliente@exemplo.com.br', password: 'SenhaDoCliente@01' }, as: :json
    response.parsed_body['api_access_token']
  end

  def cabecalho
    { api_access_token: entrar }
  end

  def manifestacao_para(contato: nil, company: empresa, titulo: 'Sugestao')
    create(:manifestation, account: account, company: company,
                           contact: contato || cliente, title: titulo)
  end

  def titulos_listados
    response.parsed_body['payload'].map { |item| item['title'] }
  end

  describe 'POST create' do
    def registrar(params = {})
      post '/api/v1/client/manifestations',
           params: { title: 'O relatorio demora', description: 'Leva dois minutos para abrir.',
                     kind: 'complaint', subject_area: 'erp' }.merge(params),
           headers: cabecalho, as: :json
    end

    it 'registers a manifestation' do
      registrar

      expect(response).to have_http_status(:created)
      criada = Manifestation.find(response.parsed_body['id'])
      expect(criada.title).to eq('O relatorio demora')
      expect(criada.kind).to eq('complaint')
      expect(criada.subject_area).to eq('erp')
    end

    # Empresa, solicitante e data nao vem do formulario - sao preenchidos aqui.
    it 'fills the company and the requester from the signed-in contact' do
      registrar

      criada = Manifestation.find(response.parsed_body['id'])
      expect(criada.company_id).to eq(empresa.id)
      expect(criada.contact_id).to eq(cliente.id)
      expect(criada.created_at).to be_present
    end

    # O pedido central da seguranca: mandar outra empresa no corpo nao a muda.
    it 'ignores a company sent in the body' do
      registrar(company_id: outra_empresa.id)

      expect(Manifestation.find(response.parsed_body['id']).company_id).to eq(empresa.id)
    end

    it 'ignores a requester sent in the body' do
      registrar(contact_id: colega.id)

      expect(Manifestation.find(response.parsed_body['id']).contact_id).to eq(cliente.id)
    end

    # O cliente nao escolhe o andamento: toda manifestacao nasce Recebida.
    it 'ignores a status sent in the body' do
      registrar(status: 'completed')

      expect(Manifestation.find(response.parsed_body['id']).status).to eq('received')
    end

    it 'gets a number the client can quote' do
      registrar

      expect(response.parsed_body['reference']).to eq("SAC-#{Manifestation.last.display_id}")
    end

    it 'refuses a manifestation with no title' do
      registrar(title: '')

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a manifestation with no description' do
      registrar(description: '')

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'records the creation in the history, by the client' do
      registrar

      atividade = Manifestation.last.manifestation_activities.first
      expect(atividade.activity_type).to eq('created')
      expect(atividade.contact_id).to eq(cliente.id)
    end

    it 'keeps the optional attachment' do
      arquivo = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

      post '/api/v1/client/manifestations',
           params: { title: 'Com anexo', description: 'Segue a tela.', kind: 'other',
                     subject_area: 'portal', attachments: [arquivo] },
           headers: cabecalho

      expect(response).to have_http_status(:created)
      expect(Manifestation.last.manifestation_attachments.count).to eq(1)
    end

    it 'refuses an unauthenticated caller' do
      post '/api/v1/client/manifestations', params: { title: 'x', description: 'y' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET index' do
    it 'lists what the contact registered' do
      manifestacao_para(titulo: 'Minha')

      get '/api/v1/client/manifestations', headers: cabecalho, as: :json

      expect(response).to have_http_status(:success)
      expect(titulos_listados).to eq(['Minha'])
    end

    # O isolamento por empresa, que e o item 6 do pedido.
    it 'never lists another company manifestation' do
      manifestacao_para(company: outra_empresa, titulo: 'De outra empresa')

      get '/api/v1/client/manifestations', headers: cabecalho, as: :json

      expect(titulos_listados).not_to include('De outra empresa')
    end

    # A permissao do contato, reaproveitada dos tickets: `sees_own` e o padrao.
    it 'hides a colleague manifestation from a sees_own contact' do
      manifestacao_para(contato: colega, titulo: 'Do colega')

      get '/api/v1/client/manifestations', headers: cabecalho, as: :json

      expect(titulos_listados).not_to include('Do colega')
    end

    it 'shows a colleague manifestation to a sees_company contact' do
      cliente.update!(client_tickets_visibility: :company)
      manifestacao_para(contato: colega, titulo: 'Do colega')

      get '/api/v1/client/manifestations', headers: cabecalho, as: :json

      expect(titulos_listados).to include('Do colega')
    end
  end

  describe 'GET show' do
    it 'shows the status and the history, so the client can follow it' do
      manifestacao = manifestacao_para
      manifestacao.update!(status: :in_progress)
      manifestacao.manifestation_activities.create!(
        user: agente, activity_type: :status_changed,
        previous_value: 'received', new_value: 'in_progress'
      )

      get "/api/v1/client/manifestations/#{manifestacao.id}", headers: cabecalho, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('in_progress')
      expect(response.parsed_body['activities'].last['activity_type']).to eq('status_changed')
    end

    # O SIGILO: a anotacao interna nunca chega ao cliente. Este e o exemplo que
    # trava a regressao mais perigosa da funcionalidade.
    it 'never exposes an internal note' do
      manifestacao = manifestacao_para
      create(:manifestation_message, manifestation: manifestacao, user: agente,
                                     visibility: :public_reply, body: 'Vamos avaliar.')
      create(:manifestation_message, manifestation: manifestacao, user: agente,
                                     visibility: :internal_note, body: 'Anotacao reservada.')

      get "/api/v1/client/manifestations/#{manifestacao.id}", headers: cabecalho, as: :json

      corpos = response.parsed_body['messages'].map { |m| m['body'] }
      expect(corpos).to eq(['Vamos avaliar.'])
      # Nem o texto em lugar nenhum da resposta, nem o rotulo do tipo.
      expect(response.body).not_to include('Anotacao reservada')
      expect(response.parsed_body['messages'].map { |m| m['visibility'] }).to all(eq('public_reply'))
    end

    # Trocar o id na URL e o ataque que o item 6 pede para impedir.
    it 'returns 404 for another company manifestation' do
      alheia = manifestacao_para(company: outra_empresa)

      get "/api/v1/client/manifestations/#{alheia.id}", headers: cabecalho, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a colleague manifestation when the contact only sees its own' do
      do_colega = manifestacao_para(contato: colega)

      get "/api/v1/client/manifestations/#{do_colega.id}", headers: cabecalho, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST messages' do
    let(:manifestacao) { manifestacao_para }

    def responder(params = {})
      post "/api/v1/client/manifestations/#{manifestacao.id}/messages",
           params: { body: 'Continua acontecendo.' }.merge(params), headers: cabecalho, as: :json
    end

    it 'lets the client reply' do
      responder

      expect(response).to have_http_status(:created)
      mensagem = manifestacao.manifestation_messages.last
      expect(mensagem.body).to eq('Continua acontecendo.')
      expect(mensagem.contact_id).to eq(cliente.id)
    end

    # O cliente nao tem como criar anotacao interna: `visibility` e fixado no
    # servidor, nao lido do pedido.
    it 'always writes a public reply, even when asked for an internal note' do
      responder(visibility: 'internal_note', internal: true)

      expect(manifestacao.manifestation_messages.last.visibility).to eq('public_reply')
    end

    it 'refuses an empty reply' do
      responder(body: '   ')

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a reply on another company manifestation' do
      alheia = manifestacao_para(company: outra_empresa)

      post "/api/v1/client/manifestations/#{alheia.id}/messages",
           params: { body: 'oi' }, headers: cabecalho, as: :json

      expect(response).to have_http_status(:not_found)
      expect(alheia.manifestation_messages).to be_empty
    end

    # Encerrada e registro historico: nao recebe mais mensagem.
    it 'refuses a reply on a finished manifestation' do
      manifestacao.update!(status: :completed)

      responder

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Estava esperando o cliente e ele respondeu: volta para a fila da equipe
    # sozinho, senao ficaria parada esperando alguem notar.
    it 'puts the manifestation back in the team queue when it was awaiting the client' do
      manifestacao.update!(status: :awaiting_customer)

      responder

      expect(manifestacao.reload.status).to eq('in_progress')
      expect(manifestacao.manifestation_activities.last.activity_type).to eq('status_changed')
    end

    it 'records the reply in the history' do
      responder

      expect(manifestacao.manifestation_activities.map(&:activity_type)).to include('client_replied')
    end
  end
end
