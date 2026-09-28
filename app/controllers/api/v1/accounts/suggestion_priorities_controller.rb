class Api::V1::Accounts::SuggestionPrioritiesController < Api::V1::Accounts::BaseController
  before_action :fetch_suggestion_priority, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @suggestion_priorities = Current.account.suggestion_priorities.order(:position, :id)
  end

  def create
    @suggestion_priority = Current.account.suggestion_priorities.create!(suggestion_priority_params)
  end

  def update
    @suggestion_priority.update!(suggestion_priority_params)
  end

  def destroy
    @suggestion_priority.destroy!
    head :ok
  end

  private

  def fetch_suggestion_priority
    @suggestion_priority = Current.account.suggestion_priorities.find(params[:id])
  end

  def suggestion_priority_params
    params.require(:suggestion_priority).permit(:name)
  end
end
