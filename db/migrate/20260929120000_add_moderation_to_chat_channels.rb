# Canal fixo e canal de aviso.
#
# `pinned` sobe o canal para o topo da barra lateral - e onde mora o que todos
# precisam ver, e ordenar por ultima mensagem o empurrava para baixo sozinho.
#
# `posting_policy` separa ler de escrever: num canal de aviso todos leem e so
# quem foi autorizado escreve. Quem autoriza marca `can_post` no membro; o
# administrador escreve sempre, sem precisar de marca.
#
# Os defaults preservam o que existe: nenhum canal atual e fixo, e em todos
# continua todo mundo podendo escrever.
class AddModerationToChatChannels < ActiveRecord::Migration[7.2]
  def change
    add_column :chat_channels, :pinned, :boolean, default: false, null: false
    add_column :chat_channels, :posting_policy, :integer, default: 0, null: false
    add_column :chat_channel_members, :can_post, :boolean, default: false, null: false
  end
end
