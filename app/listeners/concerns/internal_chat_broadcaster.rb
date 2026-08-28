# A transmissao em tempo real do Chat Interno.
#
# Fica num modulo proprio, e nao dentro do ActionCableListener, por duas razoes:
# aquela classe ja passava do limite de tamanho do projeto, e as regras de quem
# pode receber uma conversa entre funcionarios sao especificas o bastante para
# merecerem um lugar so delas.
module InternalChatBroadcaster
  extend ActiveSupport::Concern
  include Events::Types

  # Mensagem nova numa sala.
  def internal_chat_message_created(event)
    broadcast_chat_message(event, INTERNAL_CHAT_MESSAGE_CREATED)
  end

  # Mensagem alterada - hoje, quando uma reacao muda. A tela substitui o
  # registro inteiro pelo id.
  def internal_chat_message_updated(event)
    broadcast_chat_message(event, INTERNAL_CHAT_MESSAGE_UPDATED)
  end

  private

  # Apenas quem participa da sala recebe.
  #
  # Nao usa `user_tokens`: aquele helper acrescenta todos os administradores da
  # conta, o que faria uma conversa privada entre dois funcionarios chegar a
  # quem nao participa dela.
  def broadcast_chat_message(event, event_name)
    message = event.data[:chat_message]
    channel = message.chat_channel
    # O autor tambem recebe, para que as outras abas e aparelhos dele
    # acompanhem; a tela ignora o que ja tem pelo id.
    tokens = channel.members.pluck(:pubsub_token)

    broadcast(message.account, tokens, event_name, {
                channel_id: channel.id,
                message: message.push_event_data
              })
  end
end
