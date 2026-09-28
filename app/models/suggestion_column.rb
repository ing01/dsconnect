# == Schema Information
#
# Table name: suggestion_columns
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_suggestion_columns_on_account_id  (account_id)
#

# Coluna do quadro Kanban de Sugestoes de melhoria - 1 quadro por conta (nao
# por Time, diferente de TicketColumn). Deliberadamente enxuto: so nome e
# posicao, sem kind/automacao/regras de obrigatoriedade - nada disso faz
# sentido pra um quadro de feedback interno.
class SuggestionColumn < ApplicationRecord
  belongs_to :account
  has_many :suggestions, -> { order(:position, :id) }, dependent: :restrict_with_error, inverse_of: :suggestion_column

  validates :name, presence: true

  before_validation :set_default_position, on: :create
  before_destroy :ensure_no_suggestions, prepend: true

  # Persiste uma nova ordem de colunas a partir de uma lista ordenada de ids -
  # mesmo padrao de TicketColumn.reorder!, so que por conta em vez de por Time.
  def self.reorder!(account, column_ids)
    transaction do
      column_ids.each_with_index do |id, index|
        account.suggestion_columns.where(id: id).update_all(position: index) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  private

  def ensure_no_suggestions
    count = suggestions.count
    return if count.zero?

    errors.add(:base, I18n.t('errors.suggestion_column.has_suggestions', count: count))
    throw :abort
  end

  def set_default_position
    return if position.present? && position != 0

    self.position = (account&.suggestion_columns&.maximum(:position) || -1) + 1
  end
end
