# Quem abre (ou responde em) uma sala do Chat Interno ja viu as mensagens dela:
# as notificacoes dessas mensagens somem, sem precisar abrir cada uma na caixa de
# entrada. Cada mensagem tem a sua notificacao (o ator e' a `ChatMessage`), entao
# a busca e' por todas as mensagens da sala.
#
# Uma a uma, com `update!`, para o tempo real (`notification.updated`) atualizar
# o contador e a lista na tela - o mesmo que o `MarkConversationReadService` faz.
class Notification::MarkInternalChatReadService
  pattr_initialize [:user!, :account!, :chat_channel!]

  def perform
    return unless user.is_a?(User)

    notifications.find_each do |notification|
      notification.update!(read_at: read_at)
    end
  end

  private

  def notifications
    user.notifications.where(
      account: account,
      notification_type: :internal_chat_message,
      primary_actor_type: 'ChatMessage',
      primary_actor_id: chat_channel.chat_messages.select(:id),
      read_at: nil
    )
  end

  def read_at
    @read_at ||= Time.current
  end
end
