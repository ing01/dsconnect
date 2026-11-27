# "Resumo do cliente" na tela da conversa. A permissao e' a de ver a conversa
# (ver Conversations::BaseController).
class Api::V1::Accounts::Conversations::CustomerBriefingsController < Api::V1::Accounts::Conversations::BaseController
  def show
    render json: CustomerBriefing::FactsBuilder.new(
      conversation: @conversation, user: Current.user, company_id: params[:company_id]
    ).perform
  end

  # O texto da IA vem separado: a ficha aparece na hora e ele logo depois.
  def summary
    result = CustomerBriefing::SummaryService.new(
      conversation: @conversation, user: Current.user, company_id: params[:company_id],
      force: ActiveModel::Type::Boolean.new.cast(params[:force])
    ).perform

    # Sempre 422 no erro: repassar um 401 do provedor deslogaria o atendente.
    render json: result, status: result[:error] ? :unprocessable_entity : :ok
  end
end
