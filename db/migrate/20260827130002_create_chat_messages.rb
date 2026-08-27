# Uma mensagem interna. Nunca chega ao cliente por caminho nenhum.
class CreateChatMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_messages do |t|
      t.references :account, null: false, index: true
      t.references :chat_channel, null: false, index: false
      # Nulo se o agente for removido: a conversa nao pode perder o historico.
      t.references :user, null: true, index: true
      # A mensagem respondida, quando houver.
      t.references :reply_to, null: true, index: true

      t.text :content, null: false

      t.timestamps
    end

    # Historico de uma sala, do mais novo para o mais antigo.
    add_index :chat_messages, %i[chat_channel_id created_at]
  end
end
