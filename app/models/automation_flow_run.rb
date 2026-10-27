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

  def self.advisory_lock_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('AUTOMATION_FLOW_ADVISORY_LOCK', 'false')) == true
  end

  # Prefixo das chaves de lock desta tabela (`ADVISORY_LOCK_NAMESPACE + id`):
  # positivo e alto, para nao colidir com os outros locks de sessao do sistema
  # (o importador usa o id do item, negativo).
  ADVISORY_LOCK_NAMESPACE = 1 << 40

  # Uma passada por vez sobre a mesma execucao: duas mensagens que chegam juntas
  # disparam dois runners, e sem isto os dois caminhariam pelo fluxo ao mesmo
  # tempo (o bot responderia em dobro e a etapa pularia uma casa).
  #
  # Lock de SESSAO do Postgres, e nao `with_lock`, de proposito. `with_lock` abre
  # uma transacao em volta de tudo, e a passada inclui chamadas de IA que levam
  # segundos: as ferramentas do Captain (`UpdatePriorityTool`, `HandoffTool`)
  # gravam na linha da Conversa no meio dessa chamada, e a linha ficava travada
  # ate a IA terminar. Mensagem ou atribuicao do atendente nessa conversa
  # esperava o lock - e, passando de `statement_timeout`, falhava. Aqui cada
  # escrita das etapas e confirmada na hora e nada fica preso.
  #
  # Chave de seguranca: o lock de sessao so vale com
  # `AUTOMATION_FLOW_ADVISORY_LOCK=true`. Desligada (o padrao), a passada roda como
  # sempre rodou - transacao com `with_lock` - e desligar de novo volta ao
  # comportamento anterior sem novo deploy.
  def with_exclusive_pass(&)
    return with_lock(&) unless self.class.advisory_lock_enabled?

    self.class.connection_pool.with_connection do |connection|
      key = ADVISORY_LOCK_NAMESPACE + id
      connection.execute("SELECT pg_advisory_lock(#{key})")
      begin
        # Relê depois de conseguir o lock: a passada anterior pode ter mexido na
        # execucao enquanto esta esperava.
        reload
        yield
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{key})")
      end
    end
  end

  private

  def ensure_account_id
    self.account_id ||= conversation&.account_id
  end
end
