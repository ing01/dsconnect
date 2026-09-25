# Marca quando um atendente devolve uma conversa pra fila (desatribui uma
# conversa que ja tinha dono). Usado pra furar a fila: conversas devolvidas
# vao pro topo, ignorando prioridade (ver `SortHandler#sort_on_queue_position`
# e `QueuesController#claim_next_conversation`).
class AddRequeuedAtToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :requeued_at, :datetime
    add_index :conversations, :requeued_at
  end
end
