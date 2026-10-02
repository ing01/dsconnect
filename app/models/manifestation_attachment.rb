# Um arquivo de manifestacao.
#
# Copia o TicketAttachment, incluindo o limite de tamanho. Tabela propria porque
# `ticket_attachments.ticket_id` e obrigatorio - nao ha onde pendurar ali um
# anexo que ainda nao pertence a ticket nenhum.
class ManifestationAttachment < ApplicationRecord
  belongs_to :manifestation
  belongs_to :account
  # Quem enviou: o agente ou o contato. Nulaveis para que remover a pessoa nao
  # leve o arquivo com ela.
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  has_one_attached :file

  MAXIMUM_FILE_SIZE = 40.megabytes

  validates :file, presence: true
  validate :file_within_size_limit

  before_validation :ensure_account_id

  def file_url
    return '' unless file.attached?

    Rails.application.routes.url_helpers.url_for(file)
  end

  def file_name
    file.attached? ? file.filename.to_s : ''
  end

  def byte_size
    file.attached? ? file.byte_size : 0
  end

  private

  def ensure_account_id
    self.account_id ||= manifestation&.account_id
  end

  def file_within_size_limit
    return unless file.attached?
    return if file.byte_size <= MAXIMUM_FILE_SIZE

    errors.add(:file, I18n.t('manifestations.attachment.too_large',
                             limit: MAXIMUM_FILE_SIZE / 1.megabyte))
  end
end
