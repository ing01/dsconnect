# Botao "Distribuir conversas" - admin-only (pedido da Ingrid, 2026-11-12).
# Roda sincrono: o volume de conversas abertas/sem atendente numa fila e'
# pequeno o suficiente pra devolver o resultado direto na resposta, sem
# precisar de job/polling.
class Api::V1::Accounts::ConversationDistributionController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def create
    result = Conversations::ForceDistributionService.new(@current_account).perform
    render json: serialize(result)
  end

  private

  def serialize(result)
    {
      total: result[:total],
      assigned_count: result[:assigned_count],
      unassigned: result[:unassigned].map { |outcome| serialize_outcome(outcome) }
    }
  end

  def serialize_outcome(outcome)
    {
      display_id: outcome.display_id,
      agent_outcomes: outcome.agent_outcomes.map { |agent_outcome| serialize_agent_outcome(agent_outcome) }
    }
  end

  def serialize_agent_outcome(agent_outcome)
    {
      agent_name: agent_outcome.agent_name,
      reason_key: agent_outcome.reason_key,
      reason_params: agent_outcome.reason_params
    }
  end
end
