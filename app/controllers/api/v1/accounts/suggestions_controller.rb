class Api::V1::Accounts::SuggestionsController < Api::V1::Accounts::BaseController
  before_action :fetch_suggestion, only: [:update, :move, :destroy]
  before_action :check_authorization

  def index
    @suggestions = Current.account.suggestions.order(:position, :id)
  end

  # Qualquer agente/administrador pode enviar - cai direto na primeira coluna
  # do quadro (por posicao), sem etapa de aprovacao. Um Administrador pode
  # incluir direto pelo quadro (SuggestionPolicy#create? tambem e' aberto),
  # pra registrar o que ja esta sendo produzido - `assignee_id` so entra em
  # `suggestion_params` pra quem tem permissao de gerenciar o quadro.
  def create
    @suggestion = Current.account.suggestions.new(
      suggestion_params.merge(user: Current.user, suggestion_column: first_column)
    )
    @suggestion.save!
  end

  # So o Responsavel (quem esta produzindo) e' editavel aqui por enquanto -
  # titulo/descricao continuam fixos depois de enviados.
  def update
    @suggestion.update!(suggestion_params.slice(:assignee_id))
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

  def can_manage_suggestions?
    Current.account_user&.administrator? || Current.account_user&.permissions&.include?('suggestion_manage')
  end

  def suggestion_params
    permitted = [:title, :description]
    permitted << :assignee_id if can_manage_suggestions?
    params.require(:suggestion).permit(*permitted)
  end
end
