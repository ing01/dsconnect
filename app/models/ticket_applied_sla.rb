# Um relogio de SLA correndo (ou ja encerrado) sobre um Ticket.
#
# Os tres tipos tem estado proprio e independente - atendimento pode estar
# cumprido enquanto estagio venceu e solucao ainda corre. Por isso um registro
# por relogio, e nao colunas num Ticket.
#
# Diferente de AppliedSla (Conversation), que recalcula os vencimentos a cada
# leitura a partir da conversa, aqui `due_at` e persistido: o relogio de estagio
# conta a partir da entrada naquela coluna, e horas concedidas precisam deslocar
# um prazo que exista de fato. `threshold` e `only_during_business_hours` sao
# copias do que a configuracao dizia quando o relogio comecou, para que mudar a
# matriz da Mesa depois nao reescreva o passado.
class TicketAppliedSla < ApplicationRecord
  belongs_to :account
  belongs_to :ticket
  # Preenchido apenas nos relogios de estagio: diz de qual coluna era o prazo.
  belongs_to :ticket_column, optional: true
  # Nulo nos relogios de estagio, e nulo tambem se a linha da matriz for apagada
  # depois - o relogio ja tem o `threshold` que valia, entao nao depende dela.
  belongs_to :ticket_sla_policy, optional: true

  has_many :ticket_sla_events, dependent: :destroy
  has_many :ticket_sla_extensions, dependent: :nullify

  enum kind: { response: 0, stage: 1, resolution: 2 }
  # `active` e o unico estado nao terminal. Nao existe "cumprido parcialmente":
  # cada relogio responde por si.
  enum status: { active: 0, hit: 1, missed: 2 }

  validates :threshold, numericality: { greater_than: 0 }
  validates :ticket_column_id, presence: true, if: :stage?
  validates :ticket_column_id, absence: true, unless: :stage?

  before_validation :ensure_account_id

  # Um relogio que comeca, e cumprido, vence ou ganha horas muda o que a tela
  # mostra sem que o ticket em si tenha mudado - por isso o proprio relogio pede
  # a rebroadcast, reusando o evento de ticket atualizado que ja existe.
  after_commit :broadcast_ticket_update, on: [:create, :update]

  scope :running, -> { where(status: :active) }
  scope :overdue, -> { running.where(due_at: ...Time.zone.now) }

  # O relogio que vale hoje para um tipo - o ativo, ou o ultimo encerrado quando
  # nao ha nenhum correndo (um ticket fechado ainda precisa mostrar o resultado).
  scope :current_for, lambda { |kind|
    where(kind: kind).order(Arel.sql('CASE WHEN status = 0 THEN 0 ELSE 1 END'), started_at: :desc)
  }

  # Encerra o relogio dizendo se o prazo foi respeitado. Idempotente: um relogio
  # ja encerrado nunca muda de resposta, senao reabrir um ticket reescreveria
  # historico de SLA.
  def settle!(at: Time.zone.now)
    return false unless active?

    update!(status: at <= due_at ? :hit : :missed, completed_at: at)
    true
  end

  # Marca o vencimento sem encerrar: o prazo estourou, mas o relogio continua
  # sendo o vigente ate que alguem cumpra ou o ticket saia do estagio. E o que
  # permite mostrar "vencido ha 3h" em vez de so "vencido".
  def mark_missed!
    return false unless active?

    update!(status: :missed)
    true
  end

  def overdue?
    active? && due_at < Time.zone.now
  end

  # Segundos restantes; negativo quando o prazo ja passou. O frontend so faz a
  # contagem regressiva a partir daqui - quem decide o vencimento e o backend.
  def remaining_seconds(now: Time.zone.now)
    (due_at - (completed_at || now)).to_i
  end

  def push_event_data
    {
      id: id,
      kind: kind,
      status: status,
      due_at: due_at.to_i,
      started_at: started_at.to_i,
      completed_at: completed_at&.to_i,
      threshold: threshold,
      extended_seconds: extended_seconds,
      only_during_business_hours: only_during_business_hours,
      ticket_column_id: ticket_column_id,
      ticket_column_name: ticket_column&.name,
      remaining_seconds: remaining_seconds
    }
  end

  private

  def broadcast_ticket_update
    # Relogios sao destruidos junto com o ticket, entao aqui ele pode ja nao
    # existir - e um ticket apagado nao tem SLA a mostrar.
    current_ticket = Ticket.find_by(id: ticket_id)
    return if current_ticket.blank?

    Rails.configuration.dispatcher.dispatch(
      Events::Types::TICKET_UPDATED, Time.zone.now, ticket: current_ticket
    )
  end

  def ensure_account_id
    self.account_id ||= ticket&.account_id
  end
end
