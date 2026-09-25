# A message sent TO the customer about a ticket, kept apart from TicketComment,
# which is the team's internal thread and never leaves the account.
#
# `status` reflects what the delivery actually did, not what the agent clicked:
# the record is created as `pending`, and only the send path marks it `sent`.
class TicketCustomerCommunication < ApplicationRecord
  belongs_to :account
  # Nullable so removing an agent never erases what was sent to a customer.
  belongs_to :user, optional: true
  belongs_to :ticket
  belongs_to :contact, optional: true

  STATUSES = %w[pending sent failed].freeze
  # `outbound` e o que a equipe envia ao cliente; `inbound` e a resposta dele,
  # escrita na Area do Cliente. A mesma conversa, lida dos dois lados.
  DIRECTIONS = %w[outbound inbound].freeze

  validates :subject, :body, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  # So a mensagem que SAI precisa de destinatario. A que chega ja chegou - nao
  # ha entrega a fazer, e exigir um e-mail aqui seria inventar um.
  validates :to_email, presence: true, if: :outbound?
  validates :status, inclusion: { in: STATUSES }
  validate :to_email_looks_deliverable, if: :outbound?

  before_validation :ensure_account_id

  # Os arquivos que vieram com a mensagem. Continuam sendo anexos do ticket -
  # aparecem na area de Arquivos como qualquer outro -, mas sabem de onde vieram.
  has_many :ticket_attachments, dependent: :nullify

  scope :sent, -> { where(status: 'sent') }
  scope :outbound, -> { where(direction: 'outbound') }
  scope :inbound, -> { where(direction: 'inbound') }
  # What satisfies the closing requirement: a closing message that actually went
  # out. A pending or failed one does not count.
  scope :closing_sent, -> { sent.where(closing: true) }

  def outbound?
    direction == 'outbound'
  end

  def inbound?
    direction == 'inbound'
  end

  # Quem escreveu. Do lado de fora e o contato; do lado de dentro, o agente.
  def author_name
    inbound? ? contact&.name : user&.name
  end

  def mark_sent!
    update!(status: 'sent', sent_at: Time.zone.now, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: 'failed', error_message: message.to_s.truncate(1000))
  end

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  # Cheap shape check only. Whether the address exists is something only the
  # delivery attempt can answer, and that is what sets the status.
  def to_email_looks_deliverable
    return if to_email.blank?

    errors.add(:to_email, :invalid) unless to_email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
