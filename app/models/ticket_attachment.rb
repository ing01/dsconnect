class TicketAttachment < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  # Optional so removing an agent never takes the files they uploaded with them.
  belongs_to :user, optional: true
  # Presente quando o arquivo veio junto de uma mensagem da conversa; nulo no
  # anexo solto do ticket.
  belongs_to :ticket_customer_communication, optional: true

  has_one_attached :file

  MAXIMUM_FILE_SIZE = 40.megabytes

  validates :file, presence: true
  validate :file_within_size_limit

  # Ticket finalizado nao recebe mais nada: e registro historico. A checagem e
  # `on: :create` porque o que se impede e acrescentar depois do fim - o que ja
  # existia continua la, e continua legivel.
  validate :ticket_not_finalized, on: :create

  before_validation :ensure_account_id

  after_create_commit :log_added_activity
  after_destroy_commit :log_removed_activity

  def file_url
    return '' unless file.attached?

    Rails.application.routes.url_helpers.url_for(file)
  end

  private

  def ticket_not_finalized
    return unless ticket&.finalized?

    errors.add(:base, I18n.t('tickets.finalized.immutable'))
  end

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  def log_added_activity
    ticket.log_activity!(:attachment_added, user: user || Current.user,
                         new_value: file_name, details: activity_details)
  end

  # Apagar o ticket apaga os anexos junto; ai nao ha mais Historico onde anotar.
  def log_removed_activity
    return if destroyed_by_association

    ticket.log_activity!(:attachment_removed, previous_value: file_name, details: activity_details)
  end

  def file_name
    file.attached? ? file.filename.to_s : nil
  end

  def activity_details
    return {} unless file.attached?

    { 'Arquivo' => file.filename.to_s, 'Tamanho' => ActiveSupport::NumberHelper.number_to_human_size(file.byte_size) }
  end

  def file_within_size_limit
    return unless file.attached?
    return if file.byte_size <= MAXIMUM_FILE_SIZE

    errors.add(:file, I18n.t('errors.ticket_attachment.too_large', size: MAXIMUM_FILE_SIZE / 1.megabyte))
  end
end
