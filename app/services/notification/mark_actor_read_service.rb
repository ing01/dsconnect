# Marca como lidas as notificacoes de quem acabou de VER o assunto por outro
# caminho que nao a propria notificacao - abriu o ticket direto pela lista, por
# exemplo. Sem isso o aviso ficava na caixa de entrada (e no contador) de algo que
# a pessoa ja viu.
#
# Mesmo mecanismo do `MarkConversationReadService`: uma a uma, com `update!`, para
# o `notification.updated` ir ao tempo real e o contador/lista da tela acompanharem
# sem recarregar.
class Notification::MarkActorReadService
  pattr_initialize [:user!, :account!, :primary_actor!]

  def perform
    return unless user.is_a?(User)

    notifications.find_each do |notification|
      notification.update!(read_at: read_at)
    end
  end

  private

  def notifications
    user.notifications.where(account: account, primary_actor: primary_actor, read_at: nil)
  end

  def read_at
    @read_at ||= Time.current
  end
end
