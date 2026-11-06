require 'rails_helper'

# Historico do cliente dentro da conversa: quando uma pessoa que ja falou com a
# gente abre uma conversa nova, o agente ve as mensagens das conversas anteriores
# (de qualquer canal). Cliente realmente novo nao tem nada acima.
RSpec.describe 'Conversation contact history API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, email: 'cliente@exemplo.com.br') }
  let(:whatsapp_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }
  let(:portal_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }

  def new_conversation(inbox: whatsapp_inbox, contact: self.contact, status: 'resolved')
    create(:conversation, account: account, inbox: inbox, contact: contact, status: status)
  end

  def add_message(conversation, content, **attrs)
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     message_type: :incoming, content: content, **attrs)
  end

  def history_url(conversation)
    "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/contact_history"
  end

  def get_history(conversation, user: administrator, params: {})
    get history_url(conversation), params: params, headers: user.create_new_auth_token, as: :json
  end

  describe 'GET contact_history' do
    it 'devolve as mensagens das conversas anteriores do cliente, em ordem, de qualquer canal' do
      old_whatsapp = new_conversation(inbox: whatsapp_inbox)
      first = add_message(old_whatsapp, 'Oi, preciso de ajuda')
      reply = add_message(old_whatsapp, 'Claro, o que houve?', message_type: :outgoing)
      old_portal = new_conversation(inbox: portal_inbox)
      second = add_message(old_portal, 'Voltei pelo portal')
      current = new_conversation(status: 'open')
      add_message(current, 'Nova conversa')

      get_history(current)

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].pluck('id')).to eq([first.id, reply.id, second.id])
      expect(body['meta']['has_more']).to be(false)
      expect(body['conversations'].pluck('display_id')).to contain_exactly(old_whatsapp.display_id, old_portal.display_id)
      expect(body['payload'].map { |message| message['conversation_id'] }.uniq)
        .to eq([old_whatsapp.display_id, old_portal.display_id])
    end

    it 'nao traz mensagens da propria conversa, de conversas mais novas nem de outros clientes' do
      old = new_conversation
      kept = add_message(old, 'Mensagem antiga')
      current = new_conversation(status: 'open')
      add_message(current, 'Mensagem da conversa atual')
      newer = new_conversation(status: 'open')
      add_message(newer, 'Mensagem de uma conversa mais nova')
      other_contact = create(:contact, account: account, email: 'outro@exemplo.com.br')
      add_message(new_conversation(contact: other_contact), 'Mensagem de outro cliente')

      get_history(current)

      expect(response.parsed_body['payload'].pluck('id')).to eq([kept.id])
    end

    it 'devolve vazio para cliente realmente novo, sem conversa anterior' do
      current = new_conversation(status: 'open')
      add_message(current, 'Primeira mensagem')

      get_history(current)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to eq([])
      expect(response.parsed_body['conversations']).to eq([])
      expect(response.parsed_body['meta']['has_more']).to be(false)
    end

    it 'inclui notas privadas e atividades, como o agente ve na conversa' do
      old = new_conversation
      note = add_message(old, 'Cliente pediu desconto', private: true, message_type: :outgoing)
      activity = add_message(old, 'Conversa resolvida', message_type: :activity)
      current = new_conversation(status: 'open')

      get_history(current)

      expect(response.parsed_body['payload'].pluck('id')).to eq([note.id, activity.id])
    end

    # Um agente so ve o que ja podia ver: conversas de caixas em que ele nao
    # esta nao aparecem no historico.
    it 'nao mostra a um agente conversas anteriores de caixas que ele nao acessa' do
      create(:inbox_member, user: agent, inbox: whatsapp_inbox)
      visible = add_message(new_conversation(inbox: whatsapp_inbox), 'Conversa que o agente pode ver')
      add_message(new_conversation(inbox: portal_inbox), 'Conversa de uma caixa sem acesso')
      current = new_conversation(inbox: whatsapp_inbox, status: 'open')

      get_history(current, user: agent)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([visible.id])
    end

    it 'recusa um agente sem acesso a conversa atual' do
      current = new_conversation(inbox: portal_inbox, status: 'open')

      get_history(current, user: agent)

      expect(response).to have_http_status(:unauthorized)
    end

    context 'com varias paginas' do
      before { stub_const('Api::V1::Accounts::Conversations::ContactHistoriesController::PAGE_SIZE', 2) }

      it 'pagina do mais novo para o mais antigo, sem repetir mensagem' do
        older = new_conversation(inbox: whatsapp_inbox)
        m1 = add_message(older, 'm1')
        m2 = add_message(older, 'm2')
        middle = new_conversation(inbox: portal_inbox)
        m3 = add_message(middle, 'm3')
        m4 = add_message(middle, 'm4')
        m5 = add_message(middle, 'm5')
        current = new_conversation(status: 'open')

        get_history(current)
        first_page = response.parsed_body
        expect(first_page['payload'].pluck('id')).to eq([m4.id, m5.id])
        expect(first_page['meta']['has_more']).to be(true)

        get_history(current, params: { before: first_page['payload'].first['id'] })
        second_page = response.parsed_body
        expect(second_page['payload'].pluck('id')).to eq([m2.id, m3.id])
        expect(second_page['meta']['has_more']).to be(true)

        get_history(current, params: { before: second_page['payload'].first['id'] })
        last_page = response.parsed_body
        expect(last_page['payload'].pluck('id')).to eq([m1.id])
        expect(last_page['meta']['has_more']).to be(false)
      end

      it 'ignora um cursor que nao pertence ao historico permitido' do
        add_message(new_conversation, 'antiga')
        current = new_conversation(status: 'open')
        own_message = add_message(current, 'da conversa atual')

        get_history(current, params: { before: own_message.id })

        expect(response.parsed_body['payload']).to eq([])
      end
    end
  end
end
