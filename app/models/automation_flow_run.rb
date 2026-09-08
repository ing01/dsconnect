# Uma execucao do fluxo de uma automacao sobre uma conversa.
#
# E o que distingue um fluxo de uma automacao comum: a regra comum roda e acaba
# no mesmo instante, enquanto um fluxo pergunta algo e fica parado ate o cliente
# responder - possivelmente minutos depois, em outra mensagem. Esta linha e a
# memoria disso: em que etapa parou e o que ja coletou.
class AutomationFlowRun < ApplicationRecord
  belongs_to :account
  belongs_to :automation_rule
  belongs_to :conversation
  # Preenchido quando o fluxo chega a criar o ticket.
  belongs_to :ticket, optional: true

  has_many :events, class_name: 'AutomationFlowRunEvent', dependent: :delete_all,
                    inverse_of: :automation_flow_run

  # `running` e `waiting` sao os estados vivos - os dois que o indice unico
  # impede de duplicar por conversa. Os demais sao terminais.
  enum status: { running: 0, waiting: 1, completed: 2, failed: 3, handed_off: 4 }

  before_validation :ensure_account_id

  scope :live, -> { where(status: [statuses[:running], statuses[:waiting]]) }
  scope :expired, -> { waiting.where(waiting_until: ...Time.zone.now) }

  # O que as etapas leem e escrevem. Guardado com chaves em texto porque vem de
  # JSON e volta para JSON; converter os dois lados evita o par
  # `variables['x']` / `variables[:x]` divergir.
  def read_variable(path)
    variables.dig(*path.to_s.split('.'))
  end

  def write_variable(path, value)
    keys = path.to_s.split('.')
    merged = variables.deep_dup
    leaf = keys[0..-2].reduce(merged) { |node, key| node[key] ||= {} }
    leaf[keys.last] = value
    update!(variables: merged)
  end

  def live?
    running? || waiting?
  end

  private

  def ensure_account_id
    self.account_id ||= conversation&.account_id
  end
end
