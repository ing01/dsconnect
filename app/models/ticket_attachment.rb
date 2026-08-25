class TicketAttachment < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  # Optional so removing an agent never takes the files they uploaded with them.
  belongs_to :user, optional: true

  has_one_attached :file

  MAXIMUM_FILE_SIZE = 40.megabytes

  validates :file, presence: true
  validate :file_within_size_limit

  before_validation :ensure_account_id

  def file_url
    return '' unless file.attached?

    Rails.application.routes.url_helpers.url_for(file)
  end

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  def file_within_size_limit
    return unless file.attached?
    return if file.byte_size <= MAXIMUM_FILE_SIZE

    errors.add(:file, I18n.t('errors.ticket_attachment.too_large', size: MAXIMUM_FILE_SIZE / 1.megabyte))
  end
end
