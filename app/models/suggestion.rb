# == Schema Information
#
# Table name: suggestions
#
#  id                   :bigint           not null, primary key
#  description          :text
#  position             :integer          default(0), not null
#  title                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  assignee_id          :bigint
#  suggestion_column_id :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_suggestions_on_account_id            (account_id)
#  index_suggestions_on_assignee_id           (assignee_id)
#  index_suggestions_on_suggestion_column_id  (suggestion_column_id)
#  index_suggestions_on_user_id               (user_id)
#

# Uma sugestao de melhoria enviada por um usuario interno (agente/administrador)
# pelo formulario da tela Principal, OU incluida direto no quadro por um
# Administrador (pra registrar o que ja esta sendo produzido). Cai direto na
# primeira coluna do quadro - diferente da Triagem de Ticket, nao ha etapa de
# aprovacao: quem envia aqui ja e um usuario interno confiavel, nao um cliente.
class Suggestion < ApplicationRecord
  belongs_to :account
  belongs_to :suggestion_column
  belongs_to :user
  # So Administrador pode ser responsavel - e assim que o time sabe quem esta
  # tocando o que, sem virar um campo de atribuicao livre pra qualquer agente.
  belongs_to :assignee, class_name: 'User', optional: true

  validates :title, presence: true
  validate :suggestion_column_belongs_to_account
  validate :assignee_is_an_administrator

  before_validation :set_default_position, on: :create

  after_create_commit :notify_administrators

  # Move o card entre colunas e/ou dentro da mesma coluna, reindexando as
  # colunas afetadas para as posicoes ficarem contiguas - mesma logica de
  # Ticket#move_to!, sem trocar de "Time" (aqui nao existe) nem checar regras
  # de coluna (aqui tambem nao existem).
  def move_to!(suggestion_column:, position:)
    transaction do
      previous_column = self.suggestion_column
      update!(suggestion_column: suggestion_column, position: position)
      reindex_column!(previous_column) if previous_column != suggestion_column
      reindex_column!(suggestion_column)
    end
  end

  def push_event_data
    {
      id: id,
      title: title,
      description: description,
      suggestion_column_id: suggestion_column_id,
      user_name: user&.name,
      assignee_id: assignee_id,
      assignee_name: assignee&.name,
      created_at: created_at
    }
  end

  private

  def reindex_column!(column)
    column.suggestions.order(:position, :id).each_with_index do |suggestion, index|
      suggestion.update_column(:position, index) if suggestion.position != index # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def set_default_position
    return if suggestion_column.blank?

    self.position = (suggestion_column.suggestions.maximum(:position) || -1) + 1
  end

  def suggestion_column_belongs_to_account
    return if suggestion_column.blank? || account.blank?

    errors.add(:suggestion_column, :invalid) if suggestion_column.account_id != account_id
  end

  def assignee_is_an_administrator
    return if assignee.blank?

    errors.add(:assignee, :invalid) unless account.administrators.exists?(id: assignee_id)
  end

  # Em segundo plano - a conta pode ter varios Administradores, e quem enviou
  # a sugestao nao deve esperar a bandeja de todos ser escrita pra receber a
  # confirmacao (mesmo motivo de Tickets::TriageNotificationJob).
  def notify_administrators
    Suggestions::AdminNotificationJob.perform_later(id)
  end
end
