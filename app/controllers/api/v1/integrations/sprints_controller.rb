# Os sprints da conta da chave, para o sistema externo descobrir o `sprint_id` de
# POST/PATCH /tickets e do filtro de GET /tickets. `active: true` marca o sprint
# em andamento da Mesa (so' um por Mesa de cada vez - ver Sprint#activate!).
class Api::V1::Integrations::SprintsController < Api::V1::Integrations::BaseController
  def index
    # Valor fora da lista e' 422, e nao um filtro que devolve vazio: `status=ativo`
    # parecia "nenhum sprint ativo" e e' so' um erro de digitacao.
    if params[:status].present? && !Sprint.statuses.key?(params[:status].to_s)
      message = "status must be one of: #{Sprint.statuses.keys.join(', ')}"
      return render json: { error: message, message: message, attributes: ['status'] }, status: :unprocessable_entity
    end

    scope = Sprint.where(account_id: current_account.id).includes(:team).ordered
    scope = scope.where(team_id: current_account.teams.find(params[:team_id]).id) if params[:team_id].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    @sprints = scope
  end
end
