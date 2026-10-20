require 'rails_helper'

# O SAC do lado da equipe: listar, filtrar, mover o andamento, responder, anotar
# e converter em ticket.
RSpec.describe 'Manifestations API', type: :request do
  let(:account) { create(:account) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:outro_agente) { create(:user, account: account, role: :agent) }
  let(:administrador) { create(:user, account: account, role: :administrator) }
  let(:empresa) { create(:company, account: account) }
  let(:outra_empresa) { create(:company, account: account) }
  let(:contato) { create(:contact, account: account, company: empresa) }

  let!(:suporte) { create(:team, account: account, name: 'Suporte') }
  # A Mesa nasce com os Estagios padrao (DefaultMesaBuilder), e a Mesa so aceita
  # um "Pendente" - entao e o dela que se usa, nao um segundo criado aqui.
  let(:coluna_pendente) { suporte.ticket_columns.find_by(kind: 'pending') }

  def manifestacao(atributos = {})
    create(:manifestation, { account: account, company: empresa, contact: contato }.merge(atributos))
  end

  def listar(params = {}, user: agente)
    get "/api/v1/accounts/#{account.id}/manifestations",
        params: params, headers: user.create_new_auth_token, as: :json
  end

  def alterar(registro, params, user: agente)
    patch "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}",
          params: { manifestation: params }, headers: user.create_new_auth_token, as: :json
  end

  def titulos_listados
    response.parsed_body['payload'].map { |item| item['title'] }
  end

  describe 'GET index' do
    it 'refuses an unauthenticated caller' do
      get "/api/v1/accounts/#{account.id}/manifestations"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the manifestations for the team' do
      manifestacao(title: 'Primeira')

      listar

      expect(response).to have_http_status(:success)
      expect(titulos_listados).to eq(['Primeira'])
    end

    it 'does not list another account manifestation' do
      outra_conta = create(:account)
      create(:manifestation, account: outra_conta, title: 'De outra conta',
                             company: create(:company, account: outra_conta))

      listar

      expect(titulos_listados).not_to include('De outra conta')
    end

    # Os contadores que a tela usa para destacar o que precisa de atencao.
    it 'counts the total, the pending and the untouched' do
      manifestacao(status: :received)
      manifestacao(status: :in_progress)
      manifestacao(status: :completed)

      listar

      expect(response.parsed_body['meta']).to include(
        'total' => 3, 'pending' => 2, 'untouched' => 1
      )
    end

    describe 'os filtros' do
      it 'filters by company' do
        manifestacao(title: 'Da empresa')
        manifestacao(company: outra_empresa, title: 'Da outra')

        listar({ company_id: empresa.id })

        expect(titulos_listados).to eq(['Da empresa'])
      end

      it 'filters by kind' do
        manifestacao(kind: :complaint, title: 'Reclamacao')
        manifestacao(kind: :compliment, title: 'Elogio')

        listar({ kind: 'complaint' })

        expect(titulos_listados).to eq(['Reclamacao'])
      end

      it 'filters by subject area' do
        manifestacao(subject_area: :erp, title: 'Sobre o ERP')
        manifestacao(subject_area: :commercial, title: 'Sobre o comercial')

        listar({ subject_area: 'commercial' })

        expect(titulos_listados).to eq(['Sobre o comercial'])
      end

      it 'filters by status' do
        manifestacao(status: :received, title: 'Nova')
        manifestacao(status: :completed, title: 'Concluida')

        listar({ status: 'completed' })

        expect(titulos_listados).to eq(['Concluida'])
      end

      it 'filters by requester' do
        outro_contato = create(:contact, account: account, company: empresa)
        manifestacao(title: 'Do contato')
        manifestacao(contact: outro_contato, title: 'Do outro')

        listar({ contact_id: contato.id })

        expect(titulos_listados).to eq(['Do contato'])
      end

      it 'filters by assignee' do
        manifestacao(assignee: agente, title: 'Minha')
        manifestacao(title: 'De ninguem')

        listar({ assignee_id: agente.id })

        expect(titulos_listados).to eq(['Minha'])
      end

      # Periodo pela data de registro, com os dois lados opcionais.
      it 'filters by period' do
        manifestacao(title: 'Antiga', created_at: 10.days.ago)
        manifestacao(title: 'Recente')

        listar({ created_after: 2.days.ago.to_date.to_s })

        expect(titulos_listados).to eq(['Recente'])
      end

      it 'accepts more than one status at once' do
        manifestacao(status: :received, title: 'Nova')
        manifestacao(status: :in_progress, title: 'Andando')
        manifestacao(status: :cancelled, title: 'Cancelada')

        listar({ status: %w[received in_progress] })

        expect(titulos_listados).to contain_exactly('Nova', 'Andando')
      end

      it 'narrows to what is still pending' do
        manifestacao(status: :completed, title: 'Concluida')
        manifestacao(status: :received, title: 'Nova')

        listar({ pending_only: true })

        expect(titulos_listados).to eq(['Nova'])
      end

      it 'finds one by its number' do
        registro = manifestacao(title: 'Procurada')
        manifestacao(title: 'Outra')

        listar({ query: "SAC-#{registro.display_id}" })

        expect(titulos_listados).to eq(['Procurada'])
      end

      it 'searches the title' do
        manifestacao(title: 'Lentidao no relatorio')
        manifestacao(title: 'Elogio ao suporte')

        listar({ query: 'lentidao' })

        expect(titulos_listados).to eq(['Lentidao no relatorio'])
      end
    end
  end

  describe 'GET show' do
    # A equipe ve as DUAS listas - e a diferenca entre elas e explicita no corpo.
    it 'shows public replies and internal notes, each marked' do
      registro = manifestacao
      create(:manifestation_message, manifestation: registro, user: agente,
                                     visibility: :public_reply, body: 'Resposta ao cliente.')
      create(:manifestation_message, manifestation: registro, user: agente,
                                     visibility: :internal_note, body: 'Anotacao da equipe.')

      get "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}",
          headers: agente.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      tipos = response.parsed_body['messages'].to_h { |m| [m['body'], m['visibility']] }
      expect(tipos).to eq('Resposta ao cliente.' => 'public_reply',
                          'Anotacao da equipe.' => 'internal_note')
    end

    it 'does not reach a manifestation of another account' do
      outra_conta = create(:account)
      alheia = create(:manifestation, account: outra_conta,
                                      company: create(:company, account: outra_conta))

      get "/api/v1/accounts/#{account.id}/manifestations/#{alheia.id}",
          headers: agente.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH update' do
    it 'changes the status' do
      registro = manifestacao

      alterar(registro, { status: 'under_review' })

      expect(response).to have_http_status(:success)
      expect(registro.reload.status).to eq('under_review')
    end

    # Toda movimentacao grava autor e hora - e para isso que o historico existe.
    it 'records the status change with its author' do
      registro = manifestacao

      alterar(registro, { status: 'in_progress' })

      atividade = registro.manifestation_activities.last
      expect(atividade.activity_type).to eq('status_changed')
      expect(atividade.previous_value).to eq('received')
      expect(atividade.new_value).to eq('in_progress')
      expect(atividade.user_id).to eq(agente.id)
    end

    it 'assigns an internal owner' do
      registro = manifestacao

      alterar(registro, { assignee_id: outro_agente.id })

      expect(registro.reload.assignee_id).to eq(outro_agente.id)
      expect(registro.manifestation_activities.last.activity_type).to eq('assignee_changed')
    end

    it 'does not log anything when nothing changed' do
      registro = manifestacao(status: :received)

      expect { alterar(registro, { status: 'received' }) }
        .not_to(change { registro.manifestation_activities.count })
    end
  end

  describe 'POST messages' do
    let(:registro) { manifestacao }

    def escrever(params, user: agente)
      post "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}/messages",
           params: params, headers: user.create_new_auth_token, as: :json
    end

    it 'replies to the client' do
      escrever({ body: 'Estamos avaliando.' })

      expect(response).to have_http_status(:created)
      mensagem = registro.manifestation_messages.last
      expect(mensagem.visibility).to eq('public_reply')
      expect(mensagem.user_id).to eq(agente.id)
    end

    it 'writes an internal note when asked' do
      escrever({ body: 'Checar com a implantacao.', internal: true })

      expect(registro.manifestation_messages.last.visibility).to eq('internal_note')
    end

    # Sem a flag, a mensagem e publica - e o caso comum.
    it 'replies in public when the internal flag is absent' do
      escrever({ body: 'Oi' })

      expect(registro.manifestation_messages.last.visibility).to eq('public_reply')
    end

    # Um valor que nao da para interpretar erra para o lado de ESCONDER.
    #
    # Esconder uma resposta e um incomodo; mostrar uma anotacao interna e um
    # vazamento. Entre as duas falhas possiveis, esta e a aceitavel - e o teste
    # existe para fixar a direcao, nao para celebrar o valor estranho.
    it 'errs toward hiding when the internal flag cannot be read' do
      escrever({ body: 'Oi', internal: 'talvez' })

      expect(registro.manifestation_messages.last.visibility).to eq('internal_note')
    end

    it 'replies in public for an explicit false' do
      escrever({ body: 'Oi', internal: 'false' })

      expect(registro.manifestation_messages.last.visibility).to eq('public_reply')
    end

    it 'records the reply and the note differently in the history' do
      escrever({ body: 'Resposta' })
      escrever({ body: 'Nota', internal: true })

      expect(registro.manifestation_activities.map(&:activity_type))
        .to include('replied', 'internal_note_added')
    end

    it 'refuses an empty message' do
      escrever({ body: '  ' })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Responder e pedir para aguardar o cliente, numa acao.
    it 'can move the manifestation to awaiting the client' do
      escrever({ body: 'Pode confirmar?', awaiting_customer: true })

      expect(registro.reload.status).to eq('awaiting_customer')
    end

    it 'never moves the status because of an internal note' do
      escrever({ body: 'Nota', internal: true, awaiting_customer: true })

      expect(registro.reload.status).to eq('received')
    end
  end

  describe 'POST convert' do
    let(:registro) do
      manifestacao(kind: :complaint, subject_area: :erp, title: 'Relatorio travando',
                   description: 'Trava ao exportar.')
    end

    def converter(params = {}, user: administrador)
      post "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}/convert",
           params: params, headers: user.create_new_auth_token, as: :json
    end

    it 'creates a ticket through the existing mechanism' do
      converter({ team_id: suporte.id })

      expect(response).to have_http_status(:success)
      ticket = registro.reload.converted_ticket
      expect(ticket).to be_present
      expect(ticket.team_id).to eq(suporte.id)
      # O Estagio de entrada da Mesa, como na abertura pelo Portal.
      expect(ticket.ticket_column_id).to eq(coluna_pendente.id)
      expect(ticket.priority).to eq('medium')
    end

    # Preservar empresa, contato e descricao e o item 5 do pedido.
    it 'preserves the company, the requester and the description' do
      converter({ team_id: suporte.id })

      ticket = registro.reload.converted_ticket
      expect(ticket.company_id).to eq(empresa.id)
      expect(ticket.contact_id).to eq(contato.id)
      expect(ticket.description).to include('Trava ao exportar.')
      # E diz de onde veio, para quem abrir o ticket poder voltar na origem.
      expect(ticket.description).to include(registro.reference)
    end

    it 'carries the attachments over' do
      anexo = registro.manifestation_attachments.new(account_id: account.id)
      anexo.file.attach(io: Rails.root.join('spec/assets/avatar.png').open,
                        filename: 'avatar.png', content_type: 'image/png')
      anexo.save!

      converter({ team_id: suporte.id })

      expect(registro.reload.converted_ticket.ticket_attachments.count).to eq(1)
      # A manifestacao nao perde os dela: ela nao deixa de existir por ter
      # virado ticket.
      expect(registro.manifestation_attachments.count).to eq(1)
    end

    it 'records the conversion in the history' do
      converter({ team_id: suporte.id })

      atividade = registro.reload.manifestation_activities.last
      expect(atividade.activity_type).to eq('converted_to_ticket')
      expect(atividade.new_value).to eq(registro.converted_ticket.display_id.to_s)
    end

    it 'links the manifestation to the ticket and stamps the time' do
      converter({ team_id: suporte.id })

      expect(registro.reload.converted_ticket_id).to be_present
      expect(registro.converted_at).to be_present
      expect(registro.converted?).to be(true)
    end

    # O ponto do pedido: nao duplicar.
    it 'refuses to convert twice' do
      converter({ team_id: suporte.id })
      primeiro = registro.reload.converted_ticket_id

      expect { converter({ team_id: suporte.id }) }.not_to change(Ticket, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(registro.reload.converted_ticket_id).to eq(primeiro)
    end

    # Converter cria um chamado de verdade no Kanban: fica com o administrador.
    it 'forbids a plain agent from converting' do
      converter({ team_id: suporte.id }, user: agente)

      expect(response).to have_http_status(:unauthorized)
      expect(registro.reload.converted?).to be(false)
    end

    it 'moves the manifestation to in progress, since the work now lives in the ticket' do
      converter({ team_id: suporte.id })

      expect(registro.reload.status).to eq('in_progress')
    end
  end

  describe 'POST convert_to_suggestion' do
    let!(:coluna_sugestoes) { create(:suggestion_column, account: account, name: 'Entrada') }
    let(:registro) do
      manifestacao(kind: :improvement, subject_area: :erp, title: 'Exportar em Excel',
                   description: 'Seria util exportar direto em Excel.')
    end

    def converter_sugestao(user: administrador)
      post "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}/convert_to_suggestion",
           headers: user.create_new_auth_token, as: :json
    end

    it 'creates a suggestion on the account board, without needing a Mesa' do
      converter_sugestao

      expect(response).to have_http_status(:success)
      sugestao = registro.reload.converted_suggestion
      expect(sugestao).to be_present
      expect(sugestao.suggestion_column_id).to eq(coluna_sugestoes.id)
      expect(sugestao.title).to eq('Exportar em Excel')
      expect(sugestao.description).to include('Seria util exportar direto em Excel.')
      expect(sugestao.description).to include(registro.reference)
    end

    it 'credits the suggestion to whoever converted it' do
      converter_sugestao

      expect(registro.reload.converted_suggestion.user_id).to eq(administrador.id)
    end

    it 'only copies attachments the Suggestions board accepts (image/video)' do
      imagem = registro.manifestation_attachments.new(account_id: account.id)
      imagem.file.attach(io: Rails.root.join('spec/assets/avatar.png').open,
                         filename: 'avatar.png', content_type: 'image/png')
      imagem.save!
      documento = registro.manifestation_attachments.new(account_id: account.id)
      documento.file.attach(io: StringIO.new('conteudo'), filename: 'nota.pdf', content_type: 'application/pdf')
      documento.save!

      converter_sugestao

      expect(registro.reload.converted_suggestion.attachments.count).to eq(1)
      expect(registro.manifestation_attachments.count).to eq(2)
    end

    it 'records the conversion in the history' do
      converter_sugestao

      atividade = registro.reload.manifestation_activities.last
      expect(atividade.activity_type).to eq('converted_to_suggestion')
    end

    it 'links the manifestation to the suggestion and stamps the time' do
      converter_sugestao

      expect(registro.reload.converted_suggestion_id).to be_present
      expect(registro.converted_at).to be_present
      expect(registro.converted?).to be(true)
    end

    it 'refuses to convert twice' do
      converter_sugestao
      primeiro = registro.reload.converted_suggestion_id

      expect { converter_sugestao }.not_to change(Suggestion, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(registro.reload.converted_suggestion_id).to eq(primeiro)
    end

    # As duas saidas sao mutuamente exclusivas: uma manifestacao ja convertida
    # em ticket nao pode tambem virar sugestao.
    it 'refuses when the manifestation was already converted into a ticket' do
      post "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}/convert",
           params: { team_id: suporte.id }, headers: administrador.create_new_auth_token, as: :json

      expect { converter_sugestao }.not_to change(Suggestion, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'forbids a plain agent from converting' do
      converter_sugestao(user: agente)

      expect(response).to have_http_status(:unauthorized)
      expect(registro.reload.converted?).to be(false)
    end

    it 'moves the manifestation to in progress' do
      converter_sugestao

      expect(registro.reload.status).to eq('in_progress')
    end

    it 'fails clearly when the account has no Suggestions board column' do
      coluna_sugestoes.destroy!

      converter_sugestao

      expect(response).to have_http_status(:unprocessable_entity)
      expect(registro.reload.converted?).to be(false)
    end
  end

  describe 'DELETE destroy' do
    it 'lets an administrator delete one' do
      registro = manifestacao

      delete "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}",
             headers: administrador.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(Manifestation.exists?(registro.id)).to be(false)
    end

    it 'forbids a plain agent' do
      registro = manifestacao

      delete "/api/v1/accounts/#{account.id}/manifestations/#{registro.id}",
             headers: agente.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Manifestation.exists?(registro.id)).to be(true)
    end
  end
end
