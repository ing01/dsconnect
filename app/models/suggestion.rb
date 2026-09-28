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
  # Para o url_for dos anexos, como em ChatMessage.
  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :suggestion_column
  belongs_to :user
  # So Administrador pode ser responsavel - e assim que o time sabe quem esta
  # tocando o que, sem virar um campo de atribuicao livre pra qualquer agente.
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :priority, class_name: 'SuggestionPriority', optional: true
  belongs_to :category, class_name: 'SuggestionCategory', optional: true

  # O anexo e' so uma referencia visual pra ilustrar a sugestao (print, gif,
  # video curto) - nao tem vida propria como TicketAttachment (sem uploader
  # registrado, sem exclusao avulsa), mesma logica de ChatMessage#attachments.
  has_many_attached :attachments

  MAXIMUM_ATTACHMENT_SIZE = 20.megabytes
  MAXIMUM_ATTACHMENTS = 6

  validates :title, presence: true
  validates :time_spent_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :suggestion_column_belongs_to_account
  validate :assignee_is_an_administrator
  validate :priority_belongs_to_account
  validate :category_belongs_to_account
  validate :attachments_within_limits

  before_validation :set_default_position, on: :create
  before_validation :seed_completed_at, on: :create

  after_create_commit :notify_administrators

  # Move o card entre colunas e/ou dentro da mesma coluna, reindexando as
  # colunas afetadas para as posicoes ficarem contiguas - mesma logica de
  # Ticket#move_to!, sem trocar de "Time" (aqui nao existe) nem checar regras
  # de coluna (aqui tambem nao existem).
  def move_to!(suggestion_column:, position:)
    transaction do
      previous_column = self.suggestion_column
      update!(
        suggestion_column: suggestion_column,
        position: position,
        completed_at: completed_at_after_move(previous_column, suggestion_column)
      )
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

  # O que a tela precisa pra desenhar cada anexo - mesmo formato de
  # ChatMessage#attachments_payload. So imagem ganha miniatura; gif entra como
  # imagem (o proprio arquivo ja anima), video toca direto a partir da `url`.
  def attachments_payload
    attachments.map do |attachment|
      {
        id: attachment.id,
        name: attachment.filename.to_s,
        byte_size: attachment.byte_size,
        content_type: attachment.content_type,
        kind: image?(attachment) ? 'image' : 'video',
        url: url_for(attachment),
        thumb: thumb_for(attachment)
      }
    end
  end

  private

  def image?(attachment)
    attachment.content_type.to_s.start_with?('image/')
  end

  def thumb_for(attachment)
    return '' unless image?(attachment)

    url_for(attachment.representation(resize_to_limit: [320, 320]))
  rescue ActiveStorage::UnrepresentableError
    # Formato que o processador nao abre (ex: um SVG). O arquivo em tamanho
    # cheio continua servindo; so nao ha miniatura.
    ''
  end

  def attachments_within_limits
    return unless attachments.attached?

    if attachments.size > MAXIMUM_ATTACHMENTS
      errors.add(:attachments, I18n.t('errors.suggestion.too_many_attachments', count: MAXIMUM_ATTACHMENTS))
    end

    if attachments.any? { |attachment| attachment.byte_size > MAXIMUM_ATTACHMENT_SIZE }
      errors.add(:attachments, I18n.t('errors.suggestion.attachment_too_large', size: MAXIMUM_ATTACHMENT_SIZE / 1.megabyte))
    end

    return if attachments.all? { |attachment| attachment.content_type.to_s.start_with?('image/', 'video/') }

    errors.add(:attachments, I18n.t('errors.suggestion.invalid_attachment_type'))
  end

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

  def priority_belongs_to_account
    return if priority.blank? || account.blank?

    errors.add(:priority, :invalid) if priority.account_id != account_id
  end

  def category_belongs_to_account
    return if category.blank? || account.blank?

    errors.add(:category, :invalid) if category.account_id != account_id
  end

  # A coluna "concluido" (`SuggestionColumn#completed`) carimba sozinha a data
  # em que a sugestao chegou nela - assim a tela mostra QUANDO foi concluida
  # sem depender de `updated_at` (que muda de novo so' de trocar o responsavel
  # depois). So' muda quando a coluna de fato muda: reordenar dentro da mesma
  # coluna nao pode "renovar" a data.
  def completed_at_after_move(previous_column, target_column)
    return completed_at if previous_column == target_column

    target_column.completed? ? Time.zone.now : nil
  end

  def seed_completed_at
    self.completed_at = Time.zone.now if suggestion_column&.completed?
  end

  # Em segundo plano - a conta pode ter varios Administradores, e quem enviou
  # a sugestao nao deve esperar a bandeja de todos ser escrita pra receber a
  # confirmacao (mesmo motivo de Tickets::TriageNotificationJob).
  def notify_administrators
    Suggestions::AdminNotificationJob.perform_later(id)
  end
end
