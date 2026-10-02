# Uma manifestacao de SAC: o que o cliente registra pelo Portal sobre o ERP, o
# atendimento, a implantacao ou o comercial.
#
# Independente do fluxo de tickets de proposito (ver a migration). O caminho de
# volta e explicito e unico: `Manifestations::TicketConversionService`.
class Manifestation < ApplicationRecord
  belongs_to :account
  # Opcionais na associacao, exigidos na CRIACAO (abaixo): excluir uma Empresa
  # nulifica o vinculo em vez de apagar a manifestacao, como ja acontece com os
  # tickets.
  belongs_to :company, optional: true
  belongs_to :contact, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :converted_ticket, class_name: 'Ticket', optional: true

  has_many :manifestation_messages, dependent: :destroy
  has_many :manifestation_activities, dependent: :destroy
  has_many :manifestation_attachments, dependent: :destroy

  # O que o cliente veio dizer.
  KINDS = { suggestion: 0, complaint: 1, compliment: 2, improvement: 3, other: 4 }.freeze
  # Sobre o que ele esta falando.
  SUBJECT_AREAS = { erp: 0, support: 1, agent: 2, implementation: 3,
                    portal: 4, commercial: 5, other: 6 }.freeze
  # O andamento. `received` e o estado de quem acabou de registrar.
  STATUSES = { received: 0, under_review: 1, in_progress: 2,
               awaiting_customer: 3, completed: 4, cancelled: 5 }.freeze

  enum kind: KINDS
  enum subject_area: SUBJECT_AREAS, _prefix: :about
  enum status: STATUSES, _prefix: :status

  # Os estados em que nada mais se espera. Separado para que a tela interna
  # consiga destacar o que esta PENDENTE sem repetir a lista.
  FINISHED_STATUSES = %w[completed cancelled].freeze

  validates :title, :description, presence: true
  # Sem empresa nao ha como isolar o que o cliente ve, entao toda manifestacao
  # NASCE com uma. Perder a empresa depois (exclusao) e outra coisa: ai ela sai
  # da vista do cliente e segue no acervo interno.
  validates :company, :contact, presence: true, on: :create

  before_validation :ensure_account_id
  before_create :set_display_id

  scope :ordered, -> { order(created_at: :desc, id: :desc) }
  scope :pending, -> { where.not(status: FINISHED_STATUSES) }
  # A que ninguem olhou ainda: o que a tela interna marca como "nova".
  scope :untouched, -> { where(status: :received) }

  def finished?
    FINISHED_STATUSES.include?(status)
  end

  def converted?
    converted_ticket_id.present?
  end

  # O numero como o cliente o cita.
  def reference
    "SAC-#{display_id}"
  end

  private

  def ensure_account_id
    self.account_id ||= company&.account_id || contact&.account_id
  end

  # Sequencial por conta, como o `display_id` do ticket. O indice unico
  # `[account_id, display_id]` e quem garante de verdade - este calculo apenas
  # escolhe o proximo.
  def set_display_id
    return if display_id.present? || account_id.blank?

    self.display_id = (Manifestation.where(account_id: account_id).maximum(:display_id) || 0) + 1
  end
end
