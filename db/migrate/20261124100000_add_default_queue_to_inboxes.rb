# Fila padrao de cada caixa de entrada: toda conversa nova que chega por ela ja
# nasce nessa Fila (e no Time dela). Serve, por exemplo, para o WhatsApp da Meta
# cair numa Fila propria, fora da visao do suporte, ate a regra mudar.
class AddDefaultQueueToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_reference :inboxes, :default_queue, null: true, index: true,
                                            foreign_key: { to_table: :queues, on_delete: :nullify }
  end
end
