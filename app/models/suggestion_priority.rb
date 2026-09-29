# == Schema Information
#
# Table name: suggestion_priorities
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  color      :string           default("slate"), not null
#
# Indexes
#
#  index_suggestion_priorities_on_account_id  (account_id)
#

# Lista de prioridades do quadro de Sugestoes, configuravel por conta - mesmo
# espirito de SuggestionColumn, so nome e posicao. Excluir uma prioridade em
# uso so desmarca a sugestao (`dependent: :nullify`) - diferente de
# SuggestionColumn, aqui nao ha por que travar a exclusao.
class SuggestionPriority < ApplicationRecord
  belongs_to :account
  has_many :suggestions, foreign_key: :priority_id, dependent: :nullify, inverse_of: :priority

  # As mesmas 6 cores de `components-next/label/Label.vue` /
  # `ticketLabels.js` - o mesmo badge usado em Tickets, nao uma paleta
  # propria so pra Sugestoes.
  COLORS = %w[slate amber teal ruby blue iris].freeze

  validates :name, presence: true
  validates :color, inclusion: { in: COLORS }

  before_validation :set_default_position, on: :create

  private

  def set_default_position
    return if position.present? && position != 0

    self.position = (account&.suggestion_priorities&.maximum(:position) || -1) + 1
  end
end
