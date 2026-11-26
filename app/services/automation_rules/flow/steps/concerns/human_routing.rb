# Devolve a Conversation para humanos de verdade: Mesa, Fila e prioridade -
# nao so o generico `handoff` do fluxo (que so marca o `AutomationFlowRun`).
#
# As duas etapas que decidem uma prioridade de negocio de verdade (`ai_resolve`
# quando a IA nao resolve, `ai_triage` sempre) usam o mesmo tratamento - sem
# isso, so uma das duas rotas ficava com Mesa/Fila/prioridade e a outra deixava
# a conversa exatamente como chegou, so encaminhada sem informacao nenhuma
# para quem for atender.
module AutomationRules::Flow::Steps::Concerns::HumanRouting
  extend ActiveSupport::Concern

  private

  # `queue_id` aciona sozinho o que `ServiceQueue` ja oferece (auto-assign por
  # estrategia, reforco de prioridade, SLA padrao) via os callbacks que
  # `Conversation` ja tem - esta etapa so precisa setar a coluna.
  def route_conversation_to_humans!(team_id:, priority:, queue_id: nil)
    attrs = { priority: priority }
    attrs[:team_id] = team_id if team_id.present?
    attrs[:queue_id] = queue_id if queue_id.present?
    # Indo para a Fila padrao da caixa, o Time e' o DELA: com o Time padrao da
    # conta, a regra "a Fila acompanha o Time" (Conversation#queue_follows_team?)
    # tirava a conversa da fila da caixa logo em seguida.
    inbox_queue = inbox_queue_in_effect
    attrs[:team_id] = inbox_queue.team_id if inbox_queue && queue_id.to_i == inbox_queue.id
    conversation.update!(attrs)
  end

  # Ordem: a fila explicita da etapa -> a Fila padrao da CAIXA (escolha mais
  # especifica que a conta) -> a fila da faixa de prioridade da conta (ex:
  # "Suporte N1" para baixa/media, "Suporte N2" para alta/urgente) -> a fila
  # padrao da conta.
  HIGH_PRIORITY_TIER = %w[high urgent].freeze

  def queue_id_for(priority)
    params[:queue_id].presence || inbox_queue_in_effect&.id ||
      queue_id_by_priority_tier(priority) || account.helpdesk_default_queue_id
  end

  # A Fila padrao da caixa vale quando a etapa nao escolheu uma propria.
  def inbox_queue_in_effect
    return if params[:queue_id].present?

    conversation.inbox_default_queue
  end

  def queue_id_by_priority_tier(priority)
    if HIGH_PRIORITY_TIER.include?(priority.to_s)
      account.helpdesk_queue_high_id
    else
      account.helpdesk_queue_low_id
    end
  end
end
