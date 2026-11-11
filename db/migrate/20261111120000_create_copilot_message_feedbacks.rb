# Avaliacao que o agente da a uma resposta do DueBot (polegar para cima/baixo, com
# motivo e comentario opcionais), guardada para analise e para a IA evoluir.
#
# Alem da referencia a mensagem guarda uma COPIA da pergunta e da resposta: o agente
# pode excluir a conversa com o DueBot depois, e sem a copia o feedback perderia
# justamente o texto que e' o motivo de ele existir. Por isso a FK da mensagem e'
# `nullify` (o feedback sobrevive) e as referencias ao contexto sao soltas.
class CreateCopilotMessageFeedbacks < ActiveRecord::Migration[7.2]
  def change # rubocop:disable Metrics/MethodLength
    create_table :copilot_message_feedbacks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :copilot_message, null: true, foreign_key: { on_delete: :nullify }
      t.integer :copilot_thread_id
      t.integer :assistant_id
      t.integer :rating, null: false
      t.string :reason
      t.text :comment
      t.text :question
      t.text :answer
      t.integer :conversation_display_id
      t.bigint :ticket_id
      t.string :screen

      t.timestamps
    end

    # Uma avaliacao por pessoa e por resposta: avaliar de novo atualiza a anterior.
    add_index :copilot_message_feedbacks, %i[copilot_message_id user_id],
              unique: true,
              where: 'copilot_message_id IS NOT NULL',
              name: 'index_copilot_feedbacks_on_message_and_user'
    add_index :copilot_message_feedbacks, %i[account_id rating created_at],
              name: 'index_copilot_feedbacks_for_analysis'
  end
end
