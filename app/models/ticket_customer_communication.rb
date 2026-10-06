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

  # `skipped` e a mensagem registrada SEM e-mail: quando o agente desmarca
  # "enviar e-mail ao cliente", nada e entregue pelo correio, mas o texto
  # continua no chamado e aparece na Area do Cliente. Um status proprio em vez de
  # `sent` porque `sent` significa "o servidor de e-mail aceitou" - dizer isso de
  # algo que nunca foi enviado tiraria do status a unica coisa que ele afirma.
  STATUSES = %w[pending sent skipped failed].freeze
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
  scope :skipped, -> { where(status: 'skipped') }
  # A mensagem existe para o cliente: entregue por e-mail ou registrada sem
  # envio. E o que conta como "a equipe se comunicou".
  scope :registered, -> { where(status: %w[sent skipped]) }
  scope :outbound, -> { where(direction: 'outbound') }
  scope :inbound, -> { where(direction: 'inbound') }
  # What satisfies the closing requirement: a closing message that reached the
  # customer - by e-mail, or registered without one. A pending or failed one does
  # not count.
  scope :closing_registered, -> { registered.where(closing: true) }

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

  # Registrada sem e-mail. `sent_at` e gravado porque e a hora em que a mensagem
  # passou a existir para o cliente - e disso que as telas se servem para ordenar
  # e datar a conversa.
  def mark_skipped!
    update!(status: 'skipped', sent_at: Time.zone.now, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: 'failed', error_message: message.to_s.truncate(1000))
  end

  # Usado como `secondary_actor` de uma Notification (ver
  # Tickets::CustomerCommunicationNotificationBuilder) - sem isto,
  # `notification.push_event_data` quebra ao chamar `secondary_actor&.push_event_data`
  # na hora de transmitir o aviso por ActionCable.
  def push_event_data
    {
      id: id,
      ticket_id: ticket_id,
      direction: direction,
      body: body,
      author_name: author_name,
      created_at: created_at.to_i
    }
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
