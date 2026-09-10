# Liga a notificacao push do Chat Interno para quem ja tinha conta.
#
# O `push_flags` e um bitmask e nasce com o que o AccountUser define na criacao.
# Um tipo de notificacao novo entra como bit desligado em todas as linhas que ja
# existiam - e essas pessoas nunca chegaram a escolher: o Chat Interno nao
# existia quando configuraram suas preferencias. Sem isto, a notificacao ficaria
# desligada para sempre para todos eles, sem nenhum sinal de que existe.
#
# `internal_chat_message` e o tipo 11 em Notification::NOTIFICATION_TYPES, e o
# FlagShihTzu guarda o tipo N no bit 2^(N-1) - dai o 1024. O numero e fixo por
# design: renumerar trocaria a preferencia de quem ja escolheu.
#
# Escrito em SQL, e nao pelo model, porque migracao que depende de model quebra
# quando o model muda; e o `& 1024 = 0` torna a operacao repetivel sem efeito
# colateral em quem ja tem a flag ligada.
class EnableInternalChatPushForExistingUsers < ActiveRecord::Migration[7.2]
  INTERNAL_CHAT_PUSH_BIT = 1024

  def up
    execute <<~SQL.squish
      UPDATE notification_settings
      SET push_flags = push_flags | #{INTERNAL_CHAT_PUSH_BIT}
      WHERE (push_flags & #{INTERNAL_CHAT_PUSH_BIT}) = 0
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE notification_settings
      SET push_flags = push_flags - #{INTERNAL_CHAT_PUSH_BIT}
      WHERE (push_flags & #{INTERNAL_CHAT_PUSH_BIT}) > 0
    SQL
  end
end
