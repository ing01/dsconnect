# Botao "Distribuir conversas" - admin-only (pedido da Ingrid, 2026-11-12).
# Roda sincrono: o volume de conversas abertas/sem atendente numa fila e'
# pequeno o suficiente pra devolver o resultado direto na resposta, sem
# precisar de job/polling.
class Api::V1::Accounts::ConversationDistributionController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  # O servico ja protege cada conversa individualmente (uma conversa com dado
  # inconsistente vira "nao distribuida" com motivo, em vez de derrubar o
  # lote) - este rescue e' so' a ultima linha de defesa, pra um erro fora
  # desse loop (ex: na propria consulta das conversas candidatas) ainda
  # voltar com uma mensagem legivel em vez de um 500 cru sem corpo JSON
  # (bug relatado pela Ingrid, 2026-11-13: "Nao foi possivel atribuir as
  # conversas" sem motivo nenhum).
  rescue_from StandardError, with: :render_distribution_error

  def create
    result = Conversations::ForceDistributionService.new(@current_account).perform
    render json: serialize(result)
  end

  private

  def render_distribution_error(exception)
    Rails.logger.error("[ConversationDistributionController] #{exception.class}: #{exception.message}")
    render json: { error: I18n.t('errors.queues.distribution_failed', default: 'Não foi possível distribuir as conversas. Tente novamente ou contate o suporte.') },
           status: :internal_server_error
  end

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
