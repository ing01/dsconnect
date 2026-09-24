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
    conversation.update!(attrs)
  end

  # A fila explicita da etapa sempre vence, quando configurada. Sem isso, a
  # conta pode ter uma fila por faixa de prioridade (ex: "Suporte N1" para
  # baixa/media, "Suporte N2" para alta/urgente) - so cai na fila padrao da
  # conta se nem a etapa nem a faixa de prioridade tiverem fila definida.
  HIGH_PRIORITY_TIER = %w[high urgent].freeze

  def queue_id_for(priority)
    params[:queue_id].presence || queue_id_by_priority_tier(priority) || account.helpdesk_default_queue_id
  end

  def queue_id_by_priority_tier(priority)
    if HIGH_PRIORITY_TIER.include?(priority.to_s)
      account.helpdesk_queue_high_id
    else
      account.helpdesk_queue_low_id
    end
  end
end
