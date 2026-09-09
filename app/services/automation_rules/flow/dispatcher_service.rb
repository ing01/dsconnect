# A porta de entrada do fluxo: comeca uma execucao e retoma as que esperam.
#
# Fica separado do runner porque quem chama e o listener, que so sabe de eventos
# - "uma conversa comecou", "chegou uma mensagem" - e nao de etapas.
class AutomationRules::Flow::DispatcherService
  class << self
    # Chamado quando a regra casou pelo caminho normal das automacoes. Uma regra
    # sem etapas nao e um fluxo, e segue pelas acoes de sempre.
    def start(rule:, conversation:)
      return false if rule.flow_steps.blank?
      # Uma conversa nao entra duas vezes na mesma triagem: se ja ha execucao
      # viva, a que existe e que manda.
      return false if live_run(rule: rule, conversation: conversation).present?
      # Bloqueio nao e uma etapa configuravel - roda aqui, antes de existir
      # execucao, para nenhum fluxo mal montado poder pular essa checagem.
      return false unless AutomationRules::Flow::BlockGateService.new(conversation: conversation).allowed?

      run = AutomationFlowRun.create!(
        account_id: conversation.account_id, automation_rule: rule,
        conversation: conversation, status: :running
      )
      seed_known_contact(run, conversation)
      AutomationRules::Flow::RunnerService.new(run: run).perform
      true
    rescue ActiveRecord::RecordNotUnique
      # Dois eventos da mesma conversa podem chegar juntos e passar os dois pela
      # verificacao acima. Quem perde a corrida apenas desiste: o indice e a
      # garantia de verdade, e a execucao que venceu ja esta conduzindo.
      false
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
  end
end
