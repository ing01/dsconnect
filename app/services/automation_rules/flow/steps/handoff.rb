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
  #
  # Sem fila na etapa, a Fila padrao da CAIXA vem antes da fila da conta, e leva
  # o Time dela junto - senao a conversa nascia na fila da caixa e o handoff a
  # mandava para a geral (relato da Ingrid, 2026-11-26).
  def route_to_queue!
    inbox_queue = conversation.inbox_default_queue if params[:queue_id].blank?
    return route_to_inbox_queue!(inbox_queue) if inbox_queue

    queue_id = params[:queue_id].presence || account.helpdesk_default_queue_id
    return if queue_id.blank?

    attrs = { queue_id: queue_id }
    attrs[:team_id] = params[:team_id] if params[:team_id].present?
    conversation.update!(attrs)
  end

  def route_to_inbox_queue!(queue)
    conversation.update!(queue_id: queue.id, team_id: queue.team_id)
  end
end
