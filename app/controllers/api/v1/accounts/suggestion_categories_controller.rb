class Api::V1::Accounts::SuggestionCategoriesController < Api::V1::Accounts::BaseController
  before_action :fetch_suggestion_category, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @suggestion_categories = Current.account.suggestion_categories.order(:position, :id)
  end

  def create
    @suggestion_category = Current.account.suggestion_categories.create!(suggestion_category_params)
  end

  def update
    @suggestion_category.update!(suggestion_category_params)
  end

  def destroy
    @suggestion_category.destroy!
    head :ok
  end

  private

  def fetch_suggestion_category
    @suggestion_category = Current.account.suggestion_categories.find(params[:id])
  end

  def suggestion_category_params
    params.require(:suggestion_category).permit(:name, :color)
  end
end
