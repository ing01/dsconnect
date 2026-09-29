require 'rails_helper'

# O aviso de mensagem do Chat Interno.
#
# O titulo era "Chat interno" para tudo: chegavam tres avisos de tres canais
# diferentes e os tres se apresentavam igual, sem dizer de onde vinham. Agora a
# mensagem de CANAL se anuncia pelo canal e por quem escreveu.
RSpec.describe Notification do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:autor) { create(:user, account: account, name: 'Ana Souza') }
  let(:destinatario) { create(:user, account: account) }

  def aviso_de(message)
    create(:notification, account: account, user: destinatario,
                          notification_type: :internal_chat_message,
                          primary_actor: message, secondary_actor: autor)
  end

  describe 'o titulo' do
    it 'names the channel and who wrote' do
      canal = create(:chat_channel, account: account, name: 'Comunicados')
      mensagem = create(:chat_message, chat_channel: canal, user: autor, content: 'Reuniao as 15h')

      expect(aviso_de(mensagem).push_message_title).to eq('Comunicados - Ana Souza')
    end

    # Conversa entre duas pessoas nao tem canal para nomear, e o nome de quem
    # escreveu ja abre o corpo do aviso.
    it 'keeps the generic title for a conversation between two people' do
      conversa = create(:chat_direct, account: account)
      mensagem = create(:chat_message, chat_channel: conversa, user: autor, content: 'oi')

      expect(aviso_de(mensagem).push_message_title).to eq('Chat interno')
    end
  end

  # Para onde o clique leva. O aviso tem de abrir A CONVERSA, e nao so a tela do
  # Chat - e a sala viaja na query `room`, que e como a tela a escolhe.
  describe 'o destino do clique' do
    it 'points at the room the message belongs to' do
      canal = create(:chat_channel, account: account, name: 'comunicados')
      mensagem = create(:chat_message, chat_channel: canal, user: autor)

      caminho = aviso_de(mensagem).push_target_path

      expect(caminho).to eq("/app/accounts/#{account.id}/internal-chat?room=#{canal.id}")
    end

    it 'points at the conversation for a direct message' do
      conversa = create(:chat_direct, account: account)
      mensagem = create(:chat_message, chat_channel: conversa, user: autor)

      expect(aviso_de(mensagem).push_target_path).to include("room=#{conversa.id}")
    end
  end

  describe 'o corpo' do
    it 'carries who wrote and a preview of what was written' do
      canal = create(:chat_channel, account: account, name: 'Comunicados')
      mensagem = create(:chat_message, chat_channel: canal, user: autor, content: 'Reuniao as 15h')

      corpo = aviso_de(mensagem).push_message_body

      expect(corpo).to include('Ana Souza')
      expect(corpo).to include('Reuniao as 15h')
    end
  end
end
