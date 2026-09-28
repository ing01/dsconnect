class Api::V1::Accounts::SuggestionColumnsController < Api::V1::Accounts::BaseController
  before_action :fetch_suggestion_column, only: [:update, :destroy]
  before_action :check_authorization

  def index
    Suggestions::DefaultColumnsBuilder.new(account: Current.account).perform
    @suggestion_columns = Current.account.suggestion_columns.order(:position, :id)
  end

  def create
    @suggestion_column = Current.account.suggestion_columns.create!(suggestion_column_params)
  end

  def update
    @suggestion_column.update!(suggestion_column_params)
  end

  def destroy
    @suggestion_column.destroy!
    head :ok
  end

  def reorder
    SuggestionColumn.reorder!(Current.account, params[:column_ids])
    @suggestion_columns = Current.account.suggestion_columns.order(:position, :id)
    render :index
  end

  private

  def fetch_suggestion_column
    @suggestion_column = Current.account.suggestion_columns.find(params[:id])
  end

  def suggestion_column_params
    params.require(:suggestion_column).permit(:name, :completed)
  end
end
