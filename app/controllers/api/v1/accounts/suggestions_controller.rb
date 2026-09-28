class Api::V1::Accounts::SuggestionsController < Api::V1::Accounts::BaseController
  before_action :fetch_suggestion, only: [:move, :destroy]
  before_action :check_authorization

  def index
    @suggestions = Current.account.suggestions.order(:position, :id)
  end

  # Qualquer agente/administrador pode enviar - cai direto na primeira coluna
  # do quadro (por posicao), sem etapa de aprovacao.
  def create
    @suggestion = Current.account.suggestions.new(
      suggestion_params.merge(user: Current.user, suggestion_column: first_column)
    )
    @suggestion.save!
  end

  def move
    target_column = Current.account.suggestion_columns.find(params[:suggestion_column_id])
    @suggestion.move_to!(suggestion_column: target_column, position: params[:position].to_i)
  end

  def destroy
    @suggestion.destroy!
    head :ok
  end

  private

  def fetch_suggestion
    @suggestion = Current.account.suggestions.find(params[:id])
  end

  def first_column
    Suggestions::DefaultColumnsBuilder.new(account: Current.account).perform
    Current.account.suggestion_columns.order(:position, :id).first
  end

  def suggestion_params
    params.require(:suggestion).permit(:title, :description)
  end
end
