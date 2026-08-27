# Quem participa de uma sala, e ate onde cada um leu.
#
# `last_read_at` por pessoa e o que permite o contador de nao lidas ser correto
# para cada um - diferente do prototipo, onde o numero era do navegador.
class CreateChatChannelMembers < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_channel_members do |t|
      t.references :account, null: false, index: true
      t.references :chat_channel, null: false, index: false
      t.references :user, null: false, index: true

      t.datetime :last_read_at

      t.timestamps
    end

    add_index :chat_channel_members, %i[chat_channel_id user_id], unique: true
    # A lista de salas de uma pessoa e a consulta mais frequente da tela.
    add_index :chat_channel_members, %i[user_id chat_channel_id]
  end
end
