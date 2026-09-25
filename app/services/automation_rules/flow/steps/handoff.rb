# Encerra a triagem e deixa o atendimento para uma pessoa.
#
# E o destino de todo caminho que a automacao nao sabe resolver: melhor entregar
# a um atendente do que seguir adiante com dado faltando.
class AutomationRules::Flow::Steps::Handoff < AutomationRules::Flow::Steps::Base
  def perform
    say(rendered(:content)) if params[:content].present?
    route_to_queue!
    conversation.bot_handoff!(dispatch_event: false)
    handoff(result: { reason: params[:reason] })
  end

  private

  # Mesma regra do fim de fluxo das outras etapas que encaminham pra humano
  # (`ai_triage`/`ai_resolve`): sem isso, a conversa ficava so aberta, sem fila
  # e sem dono - nao aparecia em nenhuma aba pra ninguem pegar. A fila da
  # propria etapa (se configurada) sempre vence; sem ela, cai na fila padrao da
  # conta (Configuracoes > Tickets > Automacao).
  def route_to_queue!
    queue_id = params[:queue_id].presence || account.helpdesk_default_queue_id
    return if queue_id.blank?

    attrs = { queue_id: queue_id }
    attrs[:team_id] = params[:team_id] if params[:team_id].present?
    conversation.update!(attrs)
  end
end
