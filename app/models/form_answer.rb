# Uma resposta por pergunta. `value` guarda texto/array/data conforme o tipo
# do campo; `file_upload` usa o anexo (`file`) em vez de `value` - mesmo
# limite de tamanho de TicketAttachment, pro mesmo tipo de campo poder
# existir num formulario sem surpresa de limite diferente.
class FormAnswer < ApplicationRecord
  belongs_to :account
  belongs_to :form_response

  has_one_attached :file

  MAXIMUM_FILE_SIZE = 40.megabytes

  validates :field_id, presence: true
  validate :file_within_size_limit

  before_validation :ensure_account_id

  def file_url
    return '' unless file.attached?

    Rails.application.routes.url_helpers.url_for(file)
  end

  private

  def ensure_account_id
    self.account_id ||= form_response&.account_id
  end

  def file_within_size_limit
    return unless file.attached?
    return if file.byte_size <= MAXIMUM_FILE_SIZE

    errors.add(:file, I18n.t('errors.ticket_attachment.too_large', size: MAXIMUM_FILE_SIZE / 1.megabyte))
  end
end
