# O prazo contratado de uma Mesa para uma Prioridade: quanto tempo ate falar com
# o cliente (atendimento) e quanto tempo ate encerrar (solucao).
#
# E o equivalente de SlaPolicy para Tickets. SlaPolicy nao serve aqui porque e
# por conta e nao se divide por Mesa x Prioridade; as duas convivem, cada uma
# governando o seu lado, e compartilham a mesma unidade (segundos) e o mesmo
# servico de calculo por expediente.
#
# O prazo do Estagio nao mora aqui: ele pertence ao Estagio
# (TicketColumn#stage_threshold), porque varia por coluna e nao por prioridade.
class TicketSlaPolicy < ApplicationRecord
  belongs_to :account
  belongs_to :team

  has_many :ticket_applied_slas, dependent: :nullify

  # As prioridades reais do Ticket, sem lista paralela.
  enum priority: Ticket.priorities

  validates :priority, uniqueness: { scope: :team_id }
  validates :response_threshold, :resolution_threshold,
            numericality: { greater_than: 0 }, allow_nil: true
  validate :at_least_one_threshold

  before_validation :ensure_account_id

  # O prazo de um dos dois relogios configuraveis por prioridade. Nil significa
  # "esta Mesa nao promete prazo nenhum aqui", e nenhum relogio e aberto.
  def threshold_for(kind)
    case kind.to_s
    when 'response' then response_threshold
    when 'resolution' then resolution_threshold
    end
  end

  private

  def ensure_account_id
    self.account_id ||= team&.account_id
  end

  # Uma linha sem prazo nenhum nao configura nada; apagar a linha e o jeito de
  # dizer que a prioridade nao tem SLA.
  def at_least_one_threshold
    return if response_threshold.present? || resolution_threshold.present?

    errors.add(:base, I18n.t('errors.ticket_sla_policy.no_threshold'))
  end
end
