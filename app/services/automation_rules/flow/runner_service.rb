# Caminha pelo fluxo de uma automacao, do ponto onde parou ate precisar parar
# de novo.
#
# O runner nao sabe o que cada etapa faz - so pergunta a ela para onde ir. Um
# tipo novo de etapa e uma classe nova no REGISTRY, e nada aqui muda.
#
# Uma passada termina de tres formas: o fluxo acaba, o fluxo pede para esperar a
# resposta do cliente, ou uma etapa falha. Esperar e o que distingue isto de uma
# automacao comum - a execucao fica gravada e retoma quando a resposta chega.
class AutomationRules::Flow::RunnerService
  # Teto de etapas por passada. Um fluxo mal configurado pode se apontar em
  # circulo, e um laco infinito aqui prenderia o processo do servidor.
  MAXIMUM_STEPS_PER_PASS = 50

  REGISTRY = {
    'send_message' => AutomationRules::Flow::Steps::SendMessage,
    'ask' => AutomationRules::Flow::Steps::Ask,
    'find_company' => AutomationRules::Flow::Steps::FindCompany,
    'find_contact' => AutomationRules::Flow::Steps::FindContact,
    'condition' => AutomationRules::Flow::Steps::Condition,
    'create_ticket' => AutomationRules::Flow::Steps::CreateTicket,
    'handoff' => AutomationRules::Flow::Steps::Handoff,
    'check_company_blocked' => AutomationRules::Flow::Steps::CheckCompanyBlocked,
    'check_problem_clarity' => AutomationRules::Flow::Steps::CheckProblemClarity,
    'find_open_ticket_by_number' => AutomationRules::Flow::Steps::FindOpenTicketByNumber,
    'find_open_ticket_for_customer' => AutomationRules::Flow::Steps::FindOpenTicketForCustomer,
    'list_companies' => AutomationRules::Flow::Steps::ListCompanies,
    'ai_resolve' => AutomationRules::Flow::Steps::AiResolve,
    'ai_triage' => AutomationRules::Flow::Steps::AiTriage,
    'link_contact_to_company' => AutomationRules::Flow::Steps::LinkContactToCompany
  }.freeze

  def initialize(run:, message: nil)
    @run = run
    @message = message
    @resolver = AutomationRules::Flow::VariableResolver.new(run)
  end

  def perform
    # Toda mensagem gerada por uma etapa (`I18n.t` de retry/erro/handoff, etc.)
    # tem que sair no idioma da conta, nunca no default do processo (`en`) -
    # sem isso, so o texto literal escrito no `content` de cada etapa (fixo em
    # portugues nos modelos prontos) aparecia certo, e toda mensagem padrao
    # vinha em ingles para qualquer conta, independente do idioma configurado.
    I18n.with_locale(run.account.locale) { perform_locked }
  rescue StandardError => e
    # Um erro nao previsto nao pode deixar a conversa presa num bot mudo: fica
    # registrado (via `finish`, que ja avisa o cliente - ver `notify_customer_of_failure`
    # abaixo) e o atendimento volta a ser humano. Fora do bloco acima porque o
    # `with_locale` de cima ja terminou quando uma excecao cai aqui.
    I18n.with_locale(run.account.locale) { finish(:failed, error: e.message) }
    ChatwootExceptionTracker.new(e, account: run.account).capture_exception
  end

  private

  attr_reader :run, :resolver

  def perform_locked
    # Serializado por execucao: duas mensagens que chegam juntas disparam dois
    # runners sobre a mesma linha, e sem a trava os dois caminhariam pelo fluxo
    # ao mesmo tempo - o bot responderia em dobro e a etapa pularia uma casa.
    run.with_lock do
      return unless run.live?
      # A mesma mensagem so e consumida uma vez, mesmo que o evento chegue
      # duplicado: a trava ordena os dois, e este teste descarta o segundo.
      return if @message.present? && run.last_message_id == @message.id

      run.update!(status: :running, last_message_id: @message&.id || run.last_message_id)
      walk
    end
  end

  def walk
    step_id = run.current_step_id.presence || first_step_id
    # A mensagem que reativou a execucao vale so para a etapa que estava
    # esperando; as seguintes rodam sem ela.
    incoming = @message

    MAXIMUM_STEPS_PER_PASS.times do
      return finish(:completed) if step_id.blank?

      step = find_step(step_id)
      return finish(:failed, error: "etapa #{step_id} nao existe") if step.blank?

      outcome = execute(step, incoming)
      incoming = nil
      return if halted?(step, outcome)

      step_id = outcome.next_step_id
    end

    finish(:failed, error: I18n.t('automations.flow.errors.too_many_steps'))
  end

  def execute(step, incoming)
    handler = REGISTRY[step['type']]
    return unsupported(step) if handler.blank?

    outcome = handler.new(run: run, step: step, resolver: resolver, message: incoming).perform
    log(step, outcome)
    outcome
  end

  # Cada etapa vira uma linha do historico assim que roda, e nao no fim: se o
  # processo cair no meio, o que ja aconteceu continua registrado.
  def log(step, outcome)
    run.events.create!(
      account_id: run.account_id, step_id: step['id'], step_type: step['type'],
      outcome: outcome.error.present? ? :failed : :ok,
      input: { message: @message&.content }.compact,
      result: outcome.result || {}, error: outcome.error, created_at: Time.zone.now
    )
  end

  # Devolve true quando a passada acabou aqui.
  def halted?(step, outcome)
    case outcome.action
    when :wait then wait_for_reply(step, outcome)
    when :stop then finish(:completed)
    when :handoff then finish(:handed_off)
    when :fail then finish(:failed, error: outcome.error)
    else return false
    end

    true
  end

  def wait_for_reply(step, outcome)
    minutes = step['type'] == 'ask' ? ask_timeout(step) : AutomationRules::Flow::Steps::Ask::DEFAULT_TIMEOUT_MINUTES
    run.update!(
      status: :waiting, current_step_id: outcome.next_step_id,
      waiting_until: minutes.minutes.from_now
    )
  end

  def ask_timeout(step)
    AutomationRules::Flow::Steps::Ask.new(run: run, step: step, resolver: resolver).timeout_minutes
  end

  def finish(status, error: nil)
    run.update!(status: status, current_step_id: nil, waiting_until: nil, last_error: error)
    notify_customer_of_failure if status == :failed
  end

  # Toda falha nao controlada (uma excecao qualquer, `fail_step` explicito,
  # etapa desconhecida, fluxo circular) passa por aqui - e' a rede de
  # seguranca final: o cliente sempre recebe um aviso e o atendimento volta a
  # ser humano, nunca so um registro interno de que algo deu errado. Um
  # `:handoff` controlado (a propria etapa ja decidiu o que dizer) nunca cai
  # aqui, so `status == :failed`.
  def notify_customer_of_failure
    conversation = run.conversation
    return if conversation.blank?

    Messages::MessageBuilder.new(
      nil, conversation,
      { content: I18n.t('automations.flow.errors.unexpected'), private: false,
        content_attributes: { automation_rule_id: run.automation_rule_id } }
    ).perform
    route_to_default_queue(conversation)
    conversation.bot_handoff!(dispatch_event: false)
  rescue StandardError
    # Falhar ao AVISAR sobre a falha original nao pode subir de novo - o
    # `run.update!` que chamou isto ja deixou o status correto gravado.
    nil
  end

  # Mesma regra do handoff deliberado (`Steps::Handoff`): uma falha nao
  # controlada tambem e "a automacao nao sabe o que fazer" - sem fila, a
  # conversa ficava so aberta, sem aparecer em nenhuma aba pra ninguem pegar.
  # Nunca sobrescreve uma fila que a etapa que falhou ja tenha definido antes.
  def route_to_default_queue(conversation)
    return if conversation.queue_id.present?

    queue_id = run.account.helpdesk_default_queue_id
    conversation.update!(queue_id: queue_id) if queue_id.present?
  end

  def unsupported(step)
    AutomationRules::Flow::Steps::Base::Result.new(
      action: :fail, error: "tipo de etapa desconhecido: #{step['type']}"
    )
  end

  def steps
    @steps ||= (run.automation_rule.flow_steps || []).map { |step| step.with_indifferent_access.stringify_keys }
  end

  def first_step_id
    steps.first&.dig('id')
  end

  def find_step(step_id)
    steps.find { |step| step['id'].to_s == step_id.to_s }
  end
end
