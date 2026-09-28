class Api::V1::Accounts::SuggestionsController < Api::V1::Accounts::BaseController
  # So quem gerencia o quadro decide isso - mesma logica de `assignee_id`
  # (ja existente): sao decisoes de triagem, nao um campo aberto pra quem so'
  # esta enviando a sugestao.
  MANAGEABLE_FIELDS = [:assignee_id, :priority_id, :category_id, :time_spent_hours].freeze

  before_action :fetch_suggestion, only: [:update, :move, :destroy]
  before_action :check_authorization

  def index
    @suggestions = Current.account.suggestions.with_attached_attachments
                          .includes(:priority, :category).order(:position, :id)
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
    @suggestion.attachments.attach(attachment_params) if attachment_params.present?
    @suggestion.save!
  end

  # So o que e' gerenciavel (Responsavel, Prioridade, Categoria, tempo gasto)
  # e' editavel aqui por enquanto - titulo/descricao continuam fixos depois
  # de enviados.
  def update
    @suggestion.update!(suggestion_params.slice(*MANAGEABLE_FIELDS))
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
    permitted += MANAGEABLE_FIELDS if can_manage_suggestions?
    params.require(:suggestion).permit(*permitted)
  end

  # Fora de `suggestion_params` de proposito: `Suggestion` nao tem um setter
  # `files=`, e' `attachments.attach` quem recebe isso - misturar os dois em
  # `.new(suggestion_params.merge(...))` derrubaria com um NoMethodError.
  def attachment_params
    params.dig(:suggestion, :files)
  end
end
