require 'rails_helper'

# A Area do Cliente pela API.
#
# O que se prova aqui e a FRONTEIRA: um contato so alcanca o que e da propria
# empresa, e so o que a regra dele permite. A tela nao participa disso - quem
# recusa e o servidor.
RSpec.describe 'Client Area', type: :request do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }
  let(:outra_empresa) { create(:company, account: account) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  # `client_visible`: a Categoria que o cliente ve no select. A mesma marca e a
  # fronteira do POST - vide Api::V1::Client::TicketsController.
  let(:categoria) do
    team.ticket_categories.first.tap { |c| c.update!(client_visible: true) }
  end

  let(:agente) { create(:user, account: account, role: :agent) }

  let(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br', company: empresa)
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  def entrar(email: 'cliente@exemplo.com.br', senha: 'SenhaDoCliente@01')
    # `cliente` e preguicoso: sem esta linha, os exemplos que nao o mencionam
    # tentariam entrar antes de ele existir.
    cliente
    post '/api/v1/client/session', params: { email: email, password: senha }, as: :json
    response.parsed_body['api_access_token']
  end

  def cabecalho(token)
    { api_access_token: token }
  end

  def ticket_para(contato: nil, company: empresa, titulo: 'Chamado')
    create(:ticket, account: account, team: team, ticket_column: column, ticket_category: categoria,
                    company: company, contact: contato, title: titulo)
  end

  describe 'POST /api/v1/client/session' do
    it 'signs in a contact that has client access' do
      token = entrar

      expect(response).to have_http_status(:success)
      expect(token).to be_present
      expect(response.parsed_body['contact']['company_name']).to eq(empresa.name)
    end

    it 'refuses a wrong password' do
      cliente
      entrar(senha: 'errada')

      expect(response).to have_http_status(:unauthorized)
    end

    # Contato sem acesso liberado nao e cliente: e so um contato.
    it 'refuses a contact without client access' do
      create(:contact, account: account, email: 'semacesso@exemplo.com.br', company: empresa)
      entrar(email: 'semacesso@exemplo.com.br')

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/client/tickets' do
    it 'refuses without a token' do
      get '/api/v1/client/tickets', as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'shows only the tickets this contact may see' do
      meu = ticket_para(contato: cliente, titulo: 'Meu')
      colega = ticket_para(titulo: 'Do colega')
      alheio = ticket_para(company: outra_empresa, titulo: 'De outra empresa')

      get '/api/v1/client/tickets', headers: cabecalho(entrar), as: :json

      ids = response.parsed_body['tickets'].map { |t| t['id'] }
      expect(ids).to include(meu.id)
      expect(ids).not_to include(colega.id)
      expect(ids).not_to include(alheio.id)
    end

    # A outra regra: quem responde pela empresa ve os chamados dos colegas -
    # mas nunca os de outra empresa.
    it 'includes colleagues tickets when the contact sees the whole company' do
      cliente.update!(client_tickets_visibility: :company)
      colega = ticket_para(titulo: 'Do colega')
      alheio = ticket_para(company: outra_empresa, titulo: 'De outra empresa')

      get '/api/v1/client/tickets', headers: cabecalho(entrar), as: :json

      ids = response.parsed_body['tickets'].map { |t| t['id'] }
      expect(ids).to include(colega.id)
      expect(ids).not_to include(alheio.id)
    end

    # O pedido que motivou a troca do quadro por Mesa para uma lista unica:
    # chamados de Mesas diferentes tem que aparecer juntos, e cada um precisa
    # dizer em qual Mesa e em qual Estagio esta.
    it 'brings together tickets from different teams, each saying its own team and stage' do
      outra_mesa = create(:team, account: account)
      outra_coluna = create(:ticket_column, team: outra_mesa, position: 0)
      desta_mesa = ticket_para(contato: cliente, titulo: 'Desta Mesa')
      da_outra_mesa = create(:ticket, account: account, team: outra_mesa, ticket_column: outra_coluna,
                                      ticket_category: outra_mesa.ticket_categories.first,
                                      company: empresa, contact: cliente, title: 'Da outra Mesa')

      get '/api/v1/client/tickets', headers: cabecalho(entrar), as: :json

      tickets = response.parsed_body['tickets'].index_by { |t| t['id'] }
      expect(tickets.keys).to include(desta_mesa.id, da_outra_mesa.id)
      expect(tickets[desta_mesa.id]['team_name']).to eq(team.name)
      expect(tickets[desta_mesa.id]['ticket_column_name']).to eq(column.name)
      expect(tickets[da_outra_mesa.id]['team_name']).to eq(outra_mesa.name)
      expect(tickets[da_outra_mesa.id]['ticket_column_name']).to eq(outra_coluna.name)
    end

    # A lista do cliente monta o mesmo componente REAL do painel interno
    # (`TicketListView`), e ele le o mesmo partial de ticket - por isso a
    # linha vem com os mesmos campos.
    #
    # A fronteira que vale aqui e a de LINHAS: o recorte por empresa acontece
    # antes de qualquer serializacao, e e o que os exemplos acima fixam. Se um
    # dia algum campo precisar sair do payload do cliente, e aqui que a regra
    # nova deve ser escrita.
    it 'serialises the rows exactly like the internal list does' do
      ticket_para(contato: cliente)

      get '/api/v1/client/tickets', headers: cabecalho(entrar), as: :json

      ticket = response.parsed_body['tickets'].first
      expect(ticket).to include('id', 'display_id', 'title', 'status', 'priority', 'ticket_column_id')
    end

    # A lista nao e a busca: resolvido, fechado e cancelado saem dela, como no
    # Kanban interno.
    it 'keeps finished tickets out of the list' do
      aberto = ticket_para(contato: cliente, titulo: 'Em andamento')
      encerrado = ticket_para(contato: cliente, titulo: 'Ja encerrado')
      # `update_columns` de proposito: cancelar pelo model exige motivo e
      # dispara atividade, e o que este exemplo prova e so o recorte da lista.
      encerrado.update_columns(status: 'cancelled') # rubocop:disable Rails/SkipsModelValidations

      get '/api/v1/client/tickets', headers: cabecalho(entrar), as: :json

      ids = response.parsed_body['tickets'].map { |t| t['id'] }
      expect(ids).to include(aberto.id)
      expect(ids).not_to include(encerrado.id)
    end
  end

  describe 'GET /api/v1/client/tickets/:id' do
    it 'answers 404 for a ticket of another company' do
      alheio = ticket_para(company: outra_empresa)

      get "/api/v1/client/tickets/#{alheio.id}", headers: cabecalho(entrar), as: :json

      expect(response).to have_http_status(:not_found)
    end

    # O ponto central do detalhe: a aba Comunicacao mostra o que foi enviado AO
    # cliente. Comentario interno e a conversa da equipe sobre o atendimento e
    # nao pode sair do servidor - filtrar na tela seria tarde demais.
    it 'carries the messages sent to the customer and never the internal comments' do
      meu = ticket_para(contato: cliente)
      meu.ticket_comments.create!(account: account, user: agente, content: 'Conversa interna da equipe')
      meu.ticket_customer_communications.create!(
        account: account, user: agente, contact: cliente, to_email: cliente.email,
        subject: 'Retorno do atendimento', body: 'Segue a posicao do seu chamado.',
        closing: false, status: 'sent', sent_at: Time.current
      )

      get "/api/v1/client/tickets/#{meu.id}", headers: cabecalho(entrar), as: :json

      body = response.parsed_body
      expect(body['communications'].map { |c| c['subject'] }).to eq(['Retorno do atendimento'])
      expect(body).not_to have_key('comments')
      expect(response.body).not_to include('Conversa interna da equipe')
    end

    it 'carries the appointments and the checklist, for reading only' do
      meu = ticket_para(contato: cliente)
      meu.ticket_checklist_items.create!(account: account, title: 'Coletar evidencias', required: true)
      evento = CalendarEvent.create!(account: account, team: team, title: 'Visita tecnica',
                                     start_at: 1.day.from_now, end_at: 1.day.from_now + 1.hour)
      meu.calendar_events << evento

      get "/api/v1/client/tickets/#{meu.id}", headers: cabecalho(entrar), as: :json

      body = response.parsed_body
      expect(body['checklist_items'].map { |i| i['title'] }).to eq(['Coletar evidencias'])
      expect(body['appointments'].map { |a| a['title'] }).to eq(['Visita tecnica'])
    end

    it 'opens a ticket the contact may see' do
      meu = ticket_para(contato: cliente)

      get "/api/v1/client/tickets/#{meu.id}", headers: cabecalho(entrar), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq(meu.id)
    end
  end

  describe 'POST /api/v1/client/tickets' do
    # Empresa e solicitante NAO vem do formulario. Mandar outros nao muda nada -
    # os campos nem sao lidos dos parametros.
    it 'binds the ticket to the contact and their company, ignoring what was sent' do
      post '/api/v1/client/tickets',
           params: { ticket_category_id: categoria.id, title: 'Preciso de ajuda',
                     description: 'Detalhes', priority: 'urgent',
                     company_id: outra_empresa.id, contact_id: 999_999,
                     assignee_id: 1, status: 'closed' },
           headers: cabecalho(entrar), as: :json

      expect(response).to have_http_status(:created)
      ticket = Ticket.find(response.parsed_body['id'])
      expect(ticket.company_id).to eq(empresa.id)
      expect(ticket.contact_id).to eq(cliente.id)
      expect(ticket.assignee_id).to be_nil
      expect(ticket.status).to eq('open')
      # Prioridade deixou de ser escolha do cliente: quem atende define na
      # triagem, e o ponto de partida e neutro.
      expect(ticket.priority).to eq('medium')
    end

    # A Categoria e o unico rumo que o cliente da ao chamado, e ela pertence a
    # uma Mesa - e essa Mesa que o segura ate a triagem decidir.
    it 'takes the Mesa from the chosen category and waits for triage' do
      post '/api/v1/client/tickets',
           params: { ticket_category_id: categoria.id, title: 'Chamado', description: 'Detalhes' },
           headers: cabecalho(entrar), as: :json

      expect(response).to have_http_status(:created), response.body
      ticket = Ticket.find(response.parsed_body['id'])
      esperado = team.ticket_columns.find_by(kind: 'pending') || team.ticket_columns.order(:position, :id).first
      expect(ticket.ticket_column_id).to eq(esperado.id)
      expect(ticket.team_id).to eq(team.id)
      expect(ticket.pending_triage).to be(true)
    end

    # O chamado em triagem ainda nao foi aceito: aparecer no quadro da equipe
    # seria dar por iniciado um atendimento que nao comecou.
    it 'stays out of the agents board until triage' do
      post '/api/v1/client/tickets',
           params: { ticket_category_id: categoria.id, title: 'Chamado', description: 'Detalhes' },
           headers: cabecalho(entrar), as: :json

      criado = Ticket.find(response.parsed_body['id'])
      expect(criado.ticket_column.operational_tickets).not_to include(criado)
    end
  end

  describe 'revogacao do acesso' do
    # A checagem e a cada requisicao, e nao so no login: desligar o acesso
    # precisa derrubar quem ja estava dentro.
    it 'drops an open session when the access is turned off' do
      token = entrar
      cliente.disable_client_access!

      get '/api/v1/client/tickets', headers: cabecalho(token), as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'drops an open session when the contact is blocked' do
      token = entrar
      cliente.update!(blocked: true)

      get '/api/v1/client/tickets', headers: cabecalho(token), as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'invalidates the token on sign out' do
      token = entrar
      delete '/api/v1/client/session', headers: cabecalho(token), as: :json

      get '/api/v1/client/tickets', headers: cabecalho(token), as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # A Categoria decide se o chamado precisa vir com arquivo. "Erro" quase sempre
  # precisa de print ou log; "Duvida", nao - por isso e configuracao, e nao regra
  # no codigo.
  # Categoria e um conceito POR MESA - indice unico em [team_id, name] -, entao as
  # mesmas existem em cada Mesa. A lista do cliente e plana: sem escolher quais
  # aparecem, cada nome se repetia uma vez por Mesa no select dele.
  describe 'GET /api/v1/client/categories' do
    let(:outra_mesa) { create(:team, account: account, name: 'implantacao') }

    # A repeticao que o cliente via. Criar uma Mesa ja semeia as mesmas seis
    # Categorias - e dai que vinha o nome tres vezes no select.
    it 'shows each name once, not once per Mesa' do
      categoria
      outra_mesa

      # A duplicata existe no banco: e ela que aparecia na tela.
      expect(TicketCategory.where(name: categoria.name).count).to be > 1

      get '/api/v1/client/categories', headers: cabecalho(entrar)

      nomes = response.parsed_body.pluck('name')
      expect(nomes).to eq(nomes.uniq)
      expect(nomes).to include(categoria.name)
    end

    it 'leaves out what was not marked for the client' do
      categoria
      escondida = team.ticket_categories.create!(name: 'Interno')

      get '/api/v1/client/categories', headers: cabecalho(entrar)

      expect(response.parsed_body.pluck('id')).not_to include(escondida.id)
    end

    # A marcacao nao e enfeite de tela: o POST recusa o que nao esta na lista.
    # Senao um pedido montado a mao escolheria a Mesa onde o chamado entra.
    it 'refuses to open a ticket on a category the client cannot see' do
      escondida = team.ticket_categories.create!(name: 'Interno')

      post '/api/v1/client/tickets',
           params: { ticket_category_id: escondida.id, title: 'Chamado', description: 'Detalhes' },
           headers: cabecalho(entrar)

      expect(Ticket.last&.ticket_category_id).not_to eq(escondida.id)
    end
  end

  describe 'categoria que exige anexo' do
    let(:arquivo) do
      Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'), 'image/png')
    end

    before { categoria.update!(require_attachment: true) }

    def abrir(params)
      post '/api/v1/client/tickets', params: params, headers: cabecalho(entrar)
    end

    # A recusa e ANTES de gravar: um ticket criado e so depois recusado deixaria
    # lixo no Kanban da equipe.
    it 'refuses to open without a file, creating nothing' do
      expect { abrir(team_id: team.id, title: 'Erro na emissao', description: 'Detalhes') }
        .not_to change(Ticket, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('attachment_required')
    end

    it 'opens the ticket with the file attached, in one request' do
      abrir(ticket_category_id: categoria.id, title: 'Erro na emissao',
            description: 'Detalhes', attachments: [arquivo])

      expect(response).to have_http_status(:created)
      ticket = Ticket.find(response.parsed_body['id'])
      expect(ticket.ticket_attachments.count).to eq(1)
      expect(ticket.ticket_attachments.first.file).to be_attached
    end

    # A exigencia e da Categoria, e nao da Mesa: outra Categoria da mesma Mesa
    # continua abrindo sem arquivo.
    it 'leaves other categories alone' do
      outra = team.ticket_categories.create!(name: 'Duvida', client_visible: true)

      abrir(ticket_category_id: outra.id, title: 'Como faco?', description: 'Detalhes')

      expect(response).to have_http_status(:created)
    end
  end

  # A resposta do cliente entra na MESMA conversa que a equipe ja usa, com
  # `direction: inbound`. Nao ha thread separada: o que ele escreve aparece na
  # aba Comunicacao do agente, no lugar onde ele ja olha.
  describe 'POST /api/v1/client/tickets/:id/communications' do
    let(:arquivo) do
      Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'), 'image/png')
    end
    let(:meu) { ticket_para(contato: cliente) }

    it 'records the reply as an inbound message of the ticket conversation' do
      post "/api/v1/client/tickets/#{meu.id}/communications",
           params: { body: 'O erro voltou a acontecer hoje.' },
           headers: cabecalho(entrar)

      expect(response).to have_http_status(:created)
      mensagem = meu.ticket_customer_communications.last
      expect(mensagem.direction).to eq('inbound')
      expect(mensagem.contact).to eq(cliente)
      expect(mensagem.user).to be_nil
      # Nao ha entrega a fazer: a mensagem ja chegou.
      expect(mensagem.status).to eq('sent')
    end

    # O ponto do pedido: o responsavel/seguidores do ticket precisam ser
    # avisados quando o cliente responde - ver
    # Tickets::CustomerCommunicationNotificationBuilder.
    it 'enqueues a notification job for whoever follows the ticket' do
      expect do
        post "/api/v1/client/tickets/#{meu.id}/communications",
             params: { body: 'O erro voltou a acontecer hoje.' },
             headers: cabecalho(entrar)
      end.to have_enqueued_job(Tickets::CustomerCommunicationNotificationJob)
    end

    it 'keeps the files that came with the message tied to it' do
      post "/api/v1/client/tickets/#{meu.id}/communications",
           params: { body: 'Segue o print', attachments: [arquivo] },
           headers: cabecalho(entrar)

      expect(response).to have_http_status(:created)
      mensagem = meu.ticket_customer_communications.last
      expect(mensagem.ticket_attachments.count).to eq(1)
      # E continua sendo anexo do ticket, visivel na area de Arquivos.
      expect(meu.ticket_attachments.count).to eq(1)
    end

    it 'refuses an empty message' do
      expect do
        post "/api/v1/client/tickets/#{meu.id}/communications",
             params: { body: '   ' }, headers: cabecalho(entrar)
      end.not_to change(TicketCustomerCommunication, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('body_required')
    end

    # A fronteira vale aqui tambem: responder num ticket de outra empresa nao
    # encontra o ticket.
    it 'answers 404 for a ticket of another company' do
      alheio = ticket_para(company: outra_empresa)

      post "/api/v1/client/tickets/#{alheio.id}/communications",
           params: { body: 'Oi' }, headers: cabecalho(entrar)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows both directions on the ticket detail' do
      meu.ticket_customer_communications.create!(
        account: account, user: agente, contact: cliente, to_email: cliente.email,
        subject: 'Retorno', body: 'Estamos analisando.', status: 'sent', sent_at: Time.current
      )
      post "/api/v1/client/tickets/#{meu.id}/communications",
           params: { body: 'Obrigado!' }, headers: cabecalho(entrar)

      get "/api/v1/client/tickets/#{meu.id}", headers: cabecalho(entrar), as: :json

      sentidos = response.parsed_body['communications'].map { |c| c['direction'] }
      expect(sentidos).to contain_exactly('inbound', 'outbound')
    end
  end

  # A aba Notificacoes: o que a EQUIPE escreveu nos chamados dele.
  describe 'GET /api/v1/client/notifications' do
    let(:meu) { ticket_para(contato: cliente) }

    def enviada(ticket, corpo)
      ticket.ticket_customer_communications.create!(
        account: account, user: agente, contact: cliente, to_email: cliente.email,
        subject: 'Retorno', body: corpo, status: 'sent', sent_at: Time.current
      )
    end

    it 'lists what the team wrote on the tickets this contact may see' do
      enviada(meu, 'Estamos analisando o seu chamado.')

      get '/api/v1/client/notifications', headers: cabecalho(entrar), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.map { |n| n['ticket_id'] }).to eq([meu.id])
    end

    # A fronteira vale aqui como em todo o resto.
    it 'never leaks messages of another company' do
      alheio = ticket_para(company: outra_empresa)
      enviada(alheio, 'Mensagem de outra empresa')

      get '/api/v1/client/notifications', headers: cabecalho(entrar), as: :json

      expect(response.parsed_body).to be_empty
    end

    # A resposta que ele mesmo enviou nao e novidade para ele.
    it 'leaves the replies written by the contact out' do
      meu.ticket_customer_communications.create!(
        account: account, contact: cliente, direction: 'inbound',
        subject: 'Retorno', body: 'Minha propria resposta', status: 'sent', sent_at: Time.current
      )

      get '/api/v1/client/notifications', headers: cabecalho(entrar), as: :json

      expect(response.parsed_body).to be_empty
    end
  end

  describe 'idioma das respostas' do
    # Sem isto tudo saia no idioma padrao da instalacao, e o cliente de uma
    # conta em portugues lia "Invalid e-mail or password.".
    it 'answers in the locale of the account' do
      account.update!(locale: 'pt_BR')
      cliente

      post '/api/v1/client/session',
           params: { email: cliente.email, password: 'errada' }, as: :json

      expect(response.parsed_body['error']).to eq(
        I18n.t('client_area.invalid_credentials', locale: :pt_BR)
      )
    end

    # Token invalido nao tem conta de onde tirar idioma; o padrao da Area do
    # Cliente responde, e ele nao e o ingles.
    it 'falls back to the Client Area default when there is no account to ask' do
      get '/api/v1/client/tickets', headers: cabecalho('token-que-nao-existe'), as: :json

      expect(response.parsed_body['error']).to eq(
        I18n.t('client_area.unauthorized', locale: :pt_BR)
      )
    end
  end

  # O token do cliente nao e credencial de agente.
  it 'does not open the internal agent API' do
    token = entrar

    get "/api/v1/accounts/#{account.id}/tickets", headers: cabecalho(token), as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
