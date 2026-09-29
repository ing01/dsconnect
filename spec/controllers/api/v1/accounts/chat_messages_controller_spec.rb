require 'rails_helper'

# As mensagens do Chat Interno: quem pode escrever e quem pode apagar.
#
# Num canal de aviso todos leem e so quem foi autorizado escreve - e a recusa vem
# do servidor, nao da tela: esconder o campo e conveniencia, nunca a regra.
RSpec.describe 'Chat messages API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:outro_agente) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:chat_channel, account: account) }

  def entrar(sala, user, can_post: false)
    create(:chat_channel_member, chat_channel: sala, user: user, can_post: can_post)
  end

  def escrever(sala, user, content: 'oi')
    post "/api/v1/accounts/#{account.id}/chat_channels/#{sala.id}/messages",
         params: { content: content }, headers: user.create_new_auth_token, as: :json
  end

  def apagar(sala, message, user)
    delete "/api/v1/accounts/#{account.id}/chat_channels/#{sala.id}/messages/#{message.id}",
           headers: user.create_new_auth_token, as: :json
  end

  describe 'POST create' do
    it 'lets any member write in an ordinary channel' do
      entrar(channel, agent)

      expect { escrever(channel, agent) }.to change(ChatMessage, :count).by(1)
      expect(response).to have_http_status(:success)
    end

    context 'when the channel only allows authorized writers' do
      let(:aviso) { create(:chat_channel, account: account, posting_policy: :moderators) }

      # O ponto central do canal fixo de avisos: le todo mundo, escreve quem foi
      # autorizado.
      it 'refuses a member who was not authorized' do
        entrar(aviso, agent)

        expect { escrever(aviso, agent) }.not_to change(ChatMessage, :count)
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to be_present
      end

      it 'accepts a member who was authorized' do
        entrar(aviso, agent, can_post: true)

        expect { escrever(aviso, agent) }.to change(ChatMessage, :count).by(1)
        expect(response).to have_http_status(:success)
      end

      # O administrador escreve sempre, sem precisar de marca: e quem responde
      # pelo canal da empresa.
      it 'accepts an administrator without any mark' do
        entrar(aviso, administrator)

        expect { escrever(aviso, administrator) }.to change(ChatMessage, :count).by(1)
      end

      # E ainda LE: restringir a escrita nao pode tirar ninguem da sala.
      it 'still lets an unauthorized member read' do
        entrar(aviso, agent)
        create(:chat_message, chat_channel: aviso, user: administrator, content: 'aviso')

        get "/api/v1/accounts/#{account.id}/chat_channels/#{aviso.id}/messages",
            headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['payload'].first['body']).to eq('aviso')
      end
    end

    it 'refuses someone who is not in the room at all' do
      entrar(channel, outro_agente)

      expect { escrever(channel, agent) }.not_to change(ChatMessage, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy' do
    before { entrar(channel, agent) }

    it 'lets the author delete their own message' do
      minha = create(:chat_message, chat_channel: channel, user: agent)

      expect { apagar(channel, minha, agent) }.to change(ChatMessage, :count).by(-1)
      expect(response).to have_http_status(:success)
    end

    # Apagar mensagem alheia nao e do autor: cada um responde pelo que escreveu.
    it 'refuses to let an agent delete someone else message' do
      entrar(channel, outro_agente)
      alheia = create(:chat_message, chat_channel: channel, user: outro_agente)

      expect { apagar(channel, alheia, agent) }.not_to change(ChatMessage, :count)
      expect(response).to have_http_status(:forbidden)
    end

    # O administrador apaga qualquer uma, porque responde pelo que fica no Chat da
    # empresa.
    it 'lets an administrator delete any message' do
      alheia = create(:chat_message, chat_channel: channel, user: agent)

      expect { apagar(channel, alheia, administrator) }.to change(ChatMessage, :count).by(-1)
    end

    # A RESPOSTA sobrevive: ela continua fazendo sentido sozinha, so perde a
    # citacao. Sem isto o `reply_to_id` apontaria para uma linha que nao existe.
    it 'keeps the replies, without the quote' do
      original = create(:chat_message, chat_channel: channel, user: agent)
      resposta = create(:chat_message, chat_channel: channel, user: agent, reply_to: original)

      apagar(channel, original, agent)

      expect(resposta.reload).to be_present
      expect(resposta.reply_to_id).to be_nil
    end

    it 'does not reach a message of another room' do
      outra = create(:chat_channel, account: account)
      entrar(outra, agent)
      de_outra = create(:chat_message, chat_channel: outra, user: agent)

      expect { apagar(channel, de_outra, agent) }.not_to change(ChatMessage, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
