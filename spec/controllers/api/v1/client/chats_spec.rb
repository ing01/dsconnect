require 'rails_helper'

# GET /api/v1/client/chat - a tela "de agora" do chat com a equipe. O que se
# prova aqui: sem conversa nenhuma devolve estado vazio (a conversa so nasce
# no primeiro envio); com uma aberta, essa e' a mostrada; e sem nenhuma
# aberta mas com uma RESOLVIDA, a resolvida e' devolvida (com `resolved:
# true`) em vez de nada - e' o que deixa a pesquisa de satisfacao visivel e
# respondivel mesmo depois de um F5.
RSpec.describe 'Client chat', type: :request do
  let(:account) { create(:account) }
  let(:agente) { create(:user, account: account, role: :agent) }

  let(:cliente) do
    contato = create(:contact, account: account, email: 'cliente@exemplo.com.br')
    contato.enable_client_access!(password: 'SenhaDoCliente@01')
    contato
  end

  let(:inbox) { Inboxes::EnsureClientPortalInboxService.new(account: account).perform }
  let(:contact_inbox) { ContactInboxBuilder.new(contact: cliente, inbox: inbox).perform }

  def entrar
    post '/api/v1/client/session', params: { email: 'cliente@exemplo.com.br', password: 'SenhaDoCliente@01' }, as: :json
    { api_access_token: response.parsed_body['api_access_token'] }
  end

  def conversa(status:, criada_em: Time.current)
    create(:conversation, account: account, inbox: inbox, contact: cliente,
                          contact_inbox: contact_inbox, status: status, created_at: criada_em)
  end

  def mensagem_em(conversation, texto)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, content: texto, sender: agente)
  end

  def abrir_chat(headers)
    get '/api/v1/client/chat', headers: headers, as: :json
  end

  describe 'GET show' do
    it 'returns an empty state when the contact never chatted' do
      abrir_chat(entrar)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['conversation_id']).to be_nil
      expect(body['messages']).to eq([])
    end

    it 'returns the open conversation, flagged as not resolved' do
      mensagem_em(conversa(status: :open), 'Oi')

      abrir_chat(entrar)

      body = response.parsed_body
      expect(body['resolved']).to be(false)
      expect(body['messages'].pluck('content')).to eq(['Oi'])
    end

    # O caso que motivou a mudanca: sessao encerrada, sem nenhuma aberta - a
    # pessoa deu F5 (ou trocou de aba) antes de responder a pesquisa de
    # satisfacao, e sem isto a tela voltaria em branco, perdendo a chance.
    it 'returns the last resolved conversation, flagged as resolved, when none is open' do
      mensagem_em(conversa(status: :resolved), 'Atendimento encerrado')

      abrir_chat(entrar)

      body = response.parsed_body
      expect(body['resolved']).to be(true)
      expect(body['conversation_id']).not_to be_nil
      expect(body['messages'].pluck('content')).to eq(['Atendimento encerrado'])
    end

    it 'prefers the open conversation over an older resolved one' do
      mensagem_em(conversa(status: :resolved, criada_em: 2.days.ago), 'Sessao antiga')
      aberta = conversa(status: :open)
      mensagem_em(aberta, 'Sessao atual')

      abrir_chat(entrar)

      body = response.parsed_body
      expect(body['resolved']).to be(false)
      expect(body['conversation_id']).to eq(aberta.display_id)
    end
  end
end
