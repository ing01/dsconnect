# A porta de entrada do fluxo: comeca uma execucao e retoma as que esperam.
#
# Fica separado do runner porque quem chama e o listener, que so sabe de eventos
# - "uma conversa comecou", "chegou uma mensagem" - e nao de etapas.
class AutomationRules::Flow::DispatcherService
  class << self
    # Chamado quando a regra casou pelo caminho normal das automacoes. Uma regra
    # sem etapas nao e um fluxo, e segue pelas acoes de sempre.
    #
    # O retorno decide se o listener (`AutomationRuleListener#execute_rule`)
    # tambem roda as ACOES CLASSICAS da regra (`AutomationRules::ActionService`)
    # - `true` significa "o fluxo ja e dono deste evento, nao rode as acoes
    # classicas por cima"; so `false` cai nas acoes de sempre.
    def start(rule:, conversation:)
      return false if rule.flow_steps.blank?
      # Uma conversa nao entra duas vezes na mesma triagem: se ja ha execucao
      # viva (rodando OU esperando resposta), a que existe e que manda - mas
      # o evento continua sendo do fluxo (`true`), nunca das acoes classicas.
      # Sem isso, toda mensagem trocada DURANTE o fluxo (responder o numero do
      # ticket, o CNPJ, "sim"/"nao"...) tambem disparava a acao classica da
      # regra por cima do proprio fluxo - a acao configurada e' o que fazia o
      # bot "parar de responder" no meio da conversa.
      return true if live_run(rule: rule, conversation: conversation).present?
      # Uma vez encaminhada para humano, a conversa e' dele ate ele resolver -
      # o bot nao pode "tomar de volta" so porque o cliente mandou mais uma
      # mensagem enquanto ainda esta em aberto. Sem isso, qualquer mensagem
      # depois de um handoff reiniciava a triagem inteira do zero (identificar
      # empresa, perguntar ticket de novo...) por cima do atendimento humano
      # ja em andamento - exatamente o problema: nenhuma execucao ficava mais
      # "viva" (o handoff e status terminal), entao a checagem acima nao via
      # nada e comecava uma nova. So volta a comecar sozinho quando a propria
      # conversa for marcada como resolvida (o atendimento anterior realmente
      # terminou) - ai sim uma mensagem nova e um atendimento novo de verdade.
      return true if handed_off_while_open?(rule: rule, conversation: conversation)
      # Bloqueio nao e uma etapa configuravel - roda aqui, antes de existir
      # execucao, para nenhum fluxo mal montado poder pular essa checagem. Aqui
      # SIM cai nas acoes classicas de proposito (design original): um contato
      # bloqueado nao entra no fluxo, mas a regra pode ainda querer marcar algo.
      return false unless AutomationRules::Flow::BlockGateService.new(conversation: conversation).allowed?

      run = AutomationFlowRun.create!(
        account_id: conversation.account_id, automation_rule: rule,
        conversation: conversation, status: :running
      )
      seed_known_contact(run, conversation)
      seed_account_settings(run, conversation)
      AutomationRules::Flow::RunnerService.new(run: run).perform
      true
    rescue ActiveRecord::RecordNotUnique
      # Dois eventos da mesma conversa podem chegar juntos e passar os dois pela
      # verificacao acima. Quem perde a corrida apenas desiste: o indice e a
      # garantia de verdade, e a execucao que venceu ja esta conduzindo - o
      # evento continua sendo do fluxo, por isso `true` aqui tambem.
      true
    end

    # Uma mensagem do cliente e o que destrava uma execucao parada. Mensagem de
    # agente nao: a triagem espera a pessoa do outro lado, e retomar com o texto
    # do atendente responderia a pergunta no lugar dela.
    def resume(message:)
      return false unless message.incoming?

      runs = AutomationFlowRun.waiting.where(conversation_id: message.conversation_id)
      return false if runs.empty?

      runs.each { |run| AutomationRules::Flow::RunnerService.new(run: run, message: message).perform }
      true
    end

    # Execucoes que ficaram esperando alem do prazo. A conversa nao pode ficar
    # presa num bot que espera para sempre.
    def expire_stale
      AutomationFlowRun.expired.find_each do |run|
        run.update!(status: :handed_off, current_step_id: nil, waiting_until: nil,
                    last_error: I18n.t('automations.flow.errors.timeout'))
        run.events.create!(
          account_id: run.account_id, step_type: 'timeout', outcome: :failed,
          error: I18n.t('automations.flow.errors.timeout'), created_at: Time.zone.now
        )
      end
    end

    private

    def live_run(rule:, conversation:)
      AutomationFlowRun.live.find_by(automation_rule_id: rule.id, conversation_id: conversation.id)
    end

    def handed_off_while_open?(rule:, conversation:)
      return false if conversation.resolved?

      AutomationFlowRun.handed_off.exists?(automation_rule_id: rule.id, conversation_id: conversation.id)
    end

    # O contato de quem esta escrevendo ja e conhecido antes do fluxo comecar
    # (o WhatsApp resolve isso por telefone antes de a Conversation existir) -
    # nao ha motivo para uma etapa `find_contact` (que busca por NOME dentro de
    # uma Empresa) so para gravar o que ja se sabe. `find_contact` continua
    # disponivel para o caso raro de um numero compartilhado por varias pessoas.
    def seed_known_contact(run, conversation)
      contact = conversation.contact
      return if contact.blank?

      run.write_variable('contato.id', contact.id)
      run.write_variable('contato.nome', contact.name)
      run.write_variable('contato.email', contact.email)
    end

    # `{{conta.telefone_suporte}}` fica disponivel pra qualquer mensagem do
    # fluxo (ex: empresa bloqueada) - lido de novo a cada execucao, nunca
    # gravado no modelo do fluxo, entao mudar a configuracao vale para a
    # proxima conversa sem precisar "recriar o fluxo".
    def seed_account_settings(run, conversation)
      run.write_variable('conta.telefone_suporte', conversation.account.helpdesk_support_phone_number)
    end
  end
end
