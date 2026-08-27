# Uma sala do Chat Interno.
#
# Canal e conversa privada sao a mesma coisa com `kind` diferente: os dois tem
# membros, mensagens e leitura por pessoa, e a tela ja os trata pelo mesmo
# contrato. Separa-los em duas tabelas duplicaria mensagens e leitura sem
# ganhar nada.
#
# Deliberadamente separado de Conversation: aquilo e atendimento ao cliente,
# com inbox, contato, SLA, automacoes e relatorios. Nada disso pode alcancar
# uma conversa entre funcionarios.
class CreateChatChannels < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_channels do |t|
      t.references :account, null: false, index: true
      t.references :created_by, null: true, index: true

      t.integer :kind, null: false, default: 0
      t.integer :visibility, null: false, default: 0
      # Nulo nas conversas privadas, que se identificam pelos participantes.
      t.string :name
      t.text :description
      # Espelha a ultima mensagem para ordenar a lista sem varrer mensagens.
      t.datetime :last_message_at

      t.timestamps
    end

    # Nome unico so entre canais: duas conversas privadas nao tem nome.
    add_index :chat_channels, %i[account_id name], unique: true, where: 'name IS NOT NULL'
    add_index :chat_channels, %i[account_id last_message_at]
  end
end
