# "Excluir" uma conversa privada do Chat Interno some so' para quem excluiu: o
# outro participante continua com tudo. `cleared_at` e' o corte de quem excluiu:
# as mensagens anteriores a ele nao aparecem mais para essa pessoa, e a conversa
# so' volta a ser listada quando chega mensagem nova.
class AddClearedAtToChatChannelMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channel_members, :cleared_at, :datetime
  end
end
