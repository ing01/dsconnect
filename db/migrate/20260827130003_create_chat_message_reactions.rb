# Uma reacao de alguem a uma mensagem. Uma linha por pessoa e emoji, para que
# a contagem seja consulta e nao um contador que possa dessincronizar.
class CreateChatMessageReactions < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_message_reactions do |t|
      t.references :account, null: false, index: true
      t.references :chat_message, null: false, index: false
      t.references :user, null: false, index: true

      t.string :emoji, null: false

      t.timestamps
    end

    add_index :chat_message_reactions, %i[chat_message_id user_id emoji],
              unique: true, name: 'index_chat_reactions_unique'
    add_index :chat_message_reactions, :chat_message_id
  end
end
