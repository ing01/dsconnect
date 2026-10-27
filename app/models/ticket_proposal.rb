# A proposta comercial de uma melhoria, montada pela equipe a partir de um ticket
# e, quando liberada, aprovada ou recusada pelo cliente na Area do Cliente.
#
# Segue o modelo comercial da Duesoft: um RESUMO e uma lista de itens
# (REQUISITOS), cada um com titulo, descricao e valor. `amount` e' o TOTAL dos
# itens, calculado aqui - nunca digitado.
#
# A resposta do cliente e DEFINITIVA: `decide!` so grava enquanto a proposta esta
# `pending`, e o faz numa unica instrucao SQL - dois cliques ao mesmo tempo nao
# conseguem ambos vencer.
class TicketProposal < ApplicationRecord
  STATUSES = %w[pending approved refused].freeze
  DECISIONS = %w[approved refused].freeze
  ITEM_KEYS = %w[title description amount].freeze

  belongs_to :account
  belongs_to :ticket
  # Nullable so removing an agent never erases a proposal already sent.
  belongs_to :user, optional: true
  belongs_to :decided_by_contact, class_name: 'Contact', optional: true

  validates :company_name, :summary, :location, :payment_terms, :proposal_date, :valid_until, presence: true
  validates :items, presence: true
  validates :deadline_days, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validate :items_complete
  validate :valid_until_not_before_proposal_date

  before_validation :ensure_account_id
  before_validation :compute_total

  scope :ordered, -> { order(created_at: :desc, id: :desc) }
  scope :visible_to_client, -> { where(visible_to_client: true) }

  # Aceita o que vem do formulario (Parameters) ou do banco (Hash): guarda so as
  # tres chaves conhecidas, com o valor como texto.
  def items=(value)
    super(Array(value).map { |item| item.to_h.stringify_keys.slice(*ITEM_KEYS).transform_values(&:to_s) })
  end

  def decided?
    status != 'pending'
  end

  def expired?
    valid_until < Time.zone.today
  end

  # Quantos dias a proposta vale, contados da data em que foi feita.
  def validity_days
    (valid_until - proposal_date).to_i
  end

  # Grava a decisao uma unica vez. Devolve false quando a proposta ja foi
  # decidida (ou nao esta liberada ao cliente) - quem chama responde 409.
  def decide!(decision, contact)
    raise ArgumentError, "decisao invalida: #{decision}" unless DECISIONS.include?(decision)

    now = Time.current
    updated = self.class.where(id: id, status: 'pending', visible_to_client: true)
                  .update_all(status: decision, decided_at: now, decided_by_contact_id: contact.id, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
    return false if updated.zero?

    reload
    true
  end

  # Usado como `secondary_actor` de uma Notification (ver
  # Tickets::ProposalNotificationBuilder) - sem isto, `notification.push_event_data`
  # quebra ao chamar `secondary_actor&.push_event_data`.
  def push_event_data
    { id: id, ticket_id: ticket_id, status: status, amount: amount.to_s, company_name: company_name }
  end

  private

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end

  def compute_total
    self.amount = items.sum { |item| item['amount'].to_d }
  end

  def items_complete
    return if items.blank?

    errors.add(:items, :invalid) if items.any? { |item| item['title'].blank? || item['amount'].to_d <= 0 }
  end

  def valid_until_not_before_proposal_date
    return if proposal_date.blank? || valid_until.blank?

    errors.add(:valid_until, :invalid) if valid_until < proposal_date
  end
end
