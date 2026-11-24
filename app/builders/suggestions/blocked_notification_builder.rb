# Avisa quem abriu a sugestao que ela foi impedida e precisa de mais detalhes.
#
# Quem impediu nunca avisa a si mesmo (um Administrador pode ter aberto a
# propria sugestao).
class Suggestions::BlockedNotificationBuilder
  pattr_initialize [:suggestion!, :blocked_by!]

  def perform
    opener = suggestion.user
    return if opener == blocked_by

    opener.notifications.create!(
      notification_type: 'suggestion_blocked',
      account: suggestion.account,
      primary_actor: suggestion
    )
  end
end
