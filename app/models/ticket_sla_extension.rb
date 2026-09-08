# One manual extension of a ticket's deadline. Kept as its own row (rather than
# only mutating `tickets.due_at`) so every hour granted stays attributable and
# reversible in the audit trail.
class TicketSlaExtension < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  # Qual relogio foi esticado. Nulo apenas nas extensoes anteriores aos tres
  # SLAs, que a migracao apontou para o relogio de solucao quando havia um.
  belongs_to :ticket_applied_sla, optional: true
  # Nullable so removing an agent never erases the extension they granted.
  belongs_to :user, optional: true

  # Guardado alem do vinculo para que o relatorio saiba de que tipo era a folga
  # concedida mesmo que o relogio seja apagado com o ticket.
  enum sla_kind: TicketAppliedSla.kinds, _prefix: :sla

  MAXIMUM_HOURS = 999

  validates :reason, presence: true
  # Com sinal: o prazo passou a poder ser definido por data, e uma data anterior
  # a atual encurta o prazo. Zero e que nao e ajuste nenhum.
  validates :hours,
            numericality: {
              other_than: 0,
              greater_than_or_equal_to: -MAXIMUM_HOURS,
              less_than_or_equal_to: MAXIMUM_HOURS
            }

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end
end
