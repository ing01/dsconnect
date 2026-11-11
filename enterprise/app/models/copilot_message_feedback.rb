# == Schema Information
#
# Table name: copilot_message_feedbacks
#
#  id                      :bigint           not null, primary key
#  answer                  :text
#  comment                 :text
#  question                :text
#  rating                  :integer          not null
#  reason                  :string
#  screen                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  assistant_id            :integer
#  conversation_display_id :integer
#  copilot_message_id      :bigint
#  copilot_thread_id       :integer
#  ticket_id               :bigint
#  user_id                 :bigint           not null
#
# Indexes
#
#  index_copilot_feedbacks_for_analysis                   (account_id,rating,created_at)
#  index_copilot_feedbacks_on_message_and_user            (copilot_message_id,user_id) UNIQUE WHERE (copilot_message_id IS NOT NULL)
#  index_copilot_message_feedbacks_on_account_id          (account_id)
#  index_copilot_message_feedbacks_on_copilot_message_id  (copilot_message_id)
#  index_copilot_message_feedbacks_on_user_id             (user_id)
#
# A avaliacao que um agente da a uma resposta do DueBot. Guarda uma copia da pergunta
# e da resposta, porque a conversa com o DueBot pode ser excluida depois e o feedback
# precisa continuar util para analise.
class CopilotMessageFeedback < ApplicationRecord
  # Motivos oferecidos quando a resposta nao ajudou. Chaves estaveis (a tela traduz),
  # para agrupar na analise.
  REASONS = %w[wrong_answer incomplete not_helpful outdated other].freeze
  MAX_COMMENT_LENGTH = 2000

  belongs_to :account
  belongs_to :user
  belongs_to :copilot_message, optional: true

  enum rating: { negative: 0, positive: 1 }

  validates :rating, presence: true
  validates :answer, presence: true
  validates :reason, inclusion: { in: REASONS }, allow_blank: true
  validates :comment, length: { maximum: MAX_COMMENT_LENGTH }

  # Grava (ou atualiza) a avaliacao desta pessoa para esta resposta. O motivo so faz
  # sentido quando a resposta nao ajudou, entao e descartado numa avaliacao positiva.
  def self.record!(copilot_message:, user:, rating:, reason: nil, comment: nil)
    feedback = find_or_initialize_by(copilot_message_id: copilot_message.id, user_id: user.id)
    feedback.assign_attributes(
      account_id: copilot_message.account_id,
      rating: rating,
      reason: rating.to_s == 'negative' ? reason.presence : nil,
      comment: comment.to_s.strip.presence,
      **snapshot_of(copilot_message)
    )
    feedback.save!
    feedback
  end

  # A pergunta (a ultima do agente antes desta resposta) e a resposta, mais onde o
  # chat estava aberto.
  def self.snapshot_of(copilot_message)
    thread = copilot_message.copilot_thread
    question = thread.copilot_messages.user
                     .where(copilot_messages: { id: ...copilot_message.id })
                     .order(:id).last
    {
      copilot_thread_id: thread.id,
      assistant_id: thread.assistant_id,
      question: question&.message&.dig('content'),
      answer: copilot_message.message['content'],
      conversation_display_id: thread.conversation_display_id,
      ticket_id: thread.ticket_id,
      screen: thread.screen
    }
  end
end
