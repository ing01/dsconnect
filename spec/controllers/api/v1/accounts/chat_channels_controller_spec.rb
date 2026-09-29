require 'rails_helper'

# As salas do Chat Interno. Os comportamentos fixados aqui comecaram todos como
# um problema relatado:
#
#  - o administrador ve todos os CANAIS da conta, nao so os que entrou;
#  - conversa entre duas pessoas continua so de quem participa, para qualquer papel;
#  - canal fixo vai para o topo;
#  - a lista traz a previa da ultima mensagem, porque sem ela toda sala ainda nao
#    aberta aparecia como "Sem mensagens ainda".
RSpec.describe 'Chat channels API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:outro_agente) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  def entrar(channel, user, can_post: false)
    create(:chat_channel_member, chat_channel: channel, user: user, can_post: can_post)
  end

  def listar(user)
    get "/api/v1/accounts/#{account.id}/chat_channels",
        headers: user.create_new_auth_token, as: :json
  end

  def ids_listados
    response.parsed_body['payload'].map { |room| room['id'] }
  end

  describe 'GET index' do
    it 'refuses an unauthenticated caller' do
      get "/api/v1/accounts/#{account.id}/chat_channels"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists only the rooms an agent belongs to' do
      meu = create(:chat_channel, account: account)
      entrar(meu, agent)
      alheio = create(:chat_channel, account: account)
      entrar(alheio, outro_agente)

      listar(agent)

      expect(ids_listados).to eq([meu.id])
    end

    # O pedido: administrador ve TODOS os canais, inclusive os que nao criou e os
    # em que nao entrou.
    it 'shows every channel of the account to an administrator' do
      dos_outros = create(:chat_channel, account: account)
      entrar(dos_outros, agent)

      listar(administrator)

      expect(ids_listados).to include(dos_outros.id)
    end

    it 'shows even a private channel to an administrator' do
      privado = create(:chat_channel, account: account, visibility: :private_channel)
      entrar(privado, agent)

      listar(administrator)

      expect(ids_listados).to include(privado.id)
    end

    # A linha que NAO se atravessa: administrar o Chat nao e ler conversa alheia.
    it 'never shows a conversation between two other people to an administrator' do
      conversa = create(:chat_direct, account: account)
      entrar(conversa, agent)
      entrar(conversa, outro_agente)

      listar(administrator)

      expect(ids_listados).not_to include(conversa.id)
    end

    it 'still shows the administrator their own conversations' do
      minha = create(:chat_direct, account: account)
      entrar(minha, administrator)
      entrar(minha, agent)

      listar(administrator)

      expect(ids_listados).to include(minha.id)
    end

    it 'does not cross accounts' do
      outra_conta = create(:account)
      create(:chat_channel, account: outra_conta)

      listar(administrator)

      expect(ids_listados).to be_empty
    end

    # Canal fixo primeiro, mesmo que outra sala tenha mensagem mais nova - e onde
    # mora o que todos precisam ver.
    it 'puts a pinned channel at the top' do
      comum = create(:chat_channel, account: account, last_message_at: Time.current)
      entrar(comum, agent)
      fixo = create(:chat_channel, account: account, pinned: true, last_message_at: 3.days.ago)
      entrar(fixo, agent)

      listar(agent)

      expect(ids_listados.first).to eq(fixo.id)
    end

    # O defeito relatado: "Sem mensagens ainda" numa sala que TEM mensagens. A
    # lista lia o que so era carregado ao ABRIR a sala.
    it 'carries a preview of the last message, without opening the room' do
      channel = create(:chat_channel, account: account)
      entrar(channel, agent)
      create(:chat_message, chat_channel: channel, user: outro_agente, content: 'primeira')
      ultima = create(:chat_message, chat_channel: channel, user: outro_agente, content: 'a mais recente')

      listar(agent)

      previa = response.parsed_body['payload'].first['lastMessage']
      expect(previa['id']).to eq(ultima.id)
      expect(previa['body']).to eq('a mais recente')
      expect(previa['userId']).to eq(outro_agente.id)
    end

    it 'says nothing instead of guessing when the room is really empty' do
      channel = create(:chat_channel, account: account)
      entrar(channel, agent)

      listar(agent)

      expect(response.parsed_body['payload'].first['lastMessage']).to be_nil
    end

    # O numero de nao lidas vem no mesmo pacote, e precisa continuar CERTO depois
    # de passar a ser calculado para todas as salas de uma vez.
    it 'counts what this person has not read' do
      channel = create(:chat_channel, account: account)
      entrar(channel, agent)
      create(:chat_message, chat_channel: channel, user: outro_agente)
      create(:chat_message, chat_channel: channel, user: outro_agente)
      # A propria mensagem nunca conta como nao lida.
      create(:chat_message, chat_channel: channel, user: agent)

      listar(agent)

      expect(response.parsed_body['payload'].first['unread']).to eq(2)
    end

    # Sala sem novidade traz zero. A consulta agrupada nao devolve linha para ela,
    # e confundir "sem linha" com "nao calculado" a jogava de volta na consulta
    # por sala.
    it 'reports zero for a room with nothing new' do
      channel = create(:chat_channel, account: account)
      membro = entrar(channel, agent)
      create(:chat_message, chat_channel: channel, user: outro_agente)
      membro.mark_read!

      listar(agent)

      expect(response.parsed_body['payload'].first['unread']).to eq(0)
    end

    it 'counts nothing in an empty room' do
      channel = create(:chat_channel, account: account)
      entrar(channel, agent)

      listar(agent)

      expect(response.parsed_body['payload'].first['unread']).to eq(0)
    end

    # Duas consultas para a previa e o nao lido de TODAS as salas, nao duas por
    # sala: esta lista abre a cada visita ao Chat.
    it 'does not query once per room for the previews' do
      # Uma delas sem novidade de proposito: e o caso que voltava a consultar sozinho.
      4.times do |indice|
        channel = create(:chat_channel, account: account)
        membro = entrar(channel, agent)
        create(:chat_message, chat_channel: channel, user: outro_agente)
        membro.mark_read! if indice.zero?
      end

      consultas = []
      assinatura = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        consultas << payload[:sql] if payload[:sql].include?('chat_messages')
      end
      listar(agent)
      ActiveSupport::Notifications.unsubscribe(assinatura)

      # Tres: o maior id de cada sala, o carregamento dessas mensagens, e a
      # contagem do nao lido. Uma por sala passaria de oito.
      expect(consultas.size).to be <= 3
    end
  end

  describe 'POST create' do
    def criar(params, user: administrator)
      post "/api/v1/accounts/#{account.id}/chat_channels",
           params: params, headers: user.create_new_auth_token, as: :json
    end

    it 'creates a pinned announcement channel with its authorized writers' do
      criar({ name: 'Comunicados', pinned: true, posting_policy: 'moderators',
              member_ids: [agent.id, outro_agente.id], moderator_ids: [agent.id] })

      expect(response).to have_http_status(:success)
      channel = ChatChannel.find(response.parsed_body['id'])
      expect(channel.pinned).to be(true)
      expect(channel.posting_moderators?).to be(true)
      expect(channel.chat_channel_members.where(can_post: true).pluck(:user_id)).to eq([agent.id])
    end

    it 'keeps the old default: everyone writes, nothing pinned' do
      criar({ name: 'Geral', member_ids: [agent.id] })

      channel = ChatChannel.find(response.parsed_body['id'])
      expect(channel.pinned).to be(false)
      expect(channel.posting_everyone?).to be(true)
    end
  end

  describe 'PATCH update' do
    let(:channel) { create(:chat_channel, account: account) }

    def alterar(params, user: administrator)
      patch "/api/v1/accounts/#{account.id}/chat_channels/#{channel.id}",
            params: params, headers: user.create_new_auth_token, as: :json
    end

    before { entrar(channel, agent) }

    it 'lets an administrator pin an existing channel and restrict it' do
      alterar({ pinned: true, posting_policy: 'moderators', moderator_ids: [agent.id] })

      expect(response).to have_http_status(:success)
      channel.reload
      expect(channel.pinned).to be(true)
      expect(channel.chat_channel_members.find_by(user_id: agent.id).can_post).to be(true)
    end

    # Decisao sobre o canal da empresa, nao sobre a participacao de cada um nele.
    it 'forbids a plain agent from changing the channel' do
      alterar({ pinned: true }, user: agent)

      expect(response).to have_http_status(:forbidden)
      expect(channel.reload.pinned).to be(false)
    end

    it 'refuses to touch a conversation between two people' do
      conversa = create(:chat_direct, account: account)
      entrar(conversa, administrator)

      patch "/api/v1/accounts/#{account.id}/chat_channels/#{conversa.id}",
            params: { pinned: true }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
