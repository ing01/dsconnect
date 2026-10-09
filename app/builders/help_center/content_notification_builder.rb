# Avisa os colaboradores da conta que um Artigo foi publicado ou um Portal
# novo foi criado na Central de Ajuda - pedido da Ingrid, pra ninguem do time
# depender de ficar checando a tela pra saber que tem conteudo novo.
#
# Mesmo motivo do Suggestions::AdminNotificationBuilder: nao reaproveita o
# NotificationBuilder generico (assume Conversation como ator) - mas aqui o
# destinatario e' todo mundo da conta, nao so' os Administradores.
class HelpCenter::ContentNotificationBuilder
  pattr_initialize [:content!, :notification_type!, :exclude_user_id]

  def perform
    destinatarios.each { |user| notificar(user) }
  end

  private

  def destinatarios
    scope = content.account.users
    exclude_user_id.present? ? scope.where.not(id: exclude_user_id) : scope
  end

  def notificar(user)
    user.notifications.create!(
      notification_type: notification_type,
      account: content.account,
      primary_actor: content
    )
  end
end
