class Api::V1::Accounts::TicketCategoriesController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :fetch_ticket_category, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @ticket_categories = @team.ticket_categories.ordered
  end

  def create
    @ticket_category = @team.ticket_categories.create!(ticket_category_params)
  end

  def update
    @ticket_category.update!(ticket_category_params)
  end

  def destroy
    @ticket_category.destroy!
    head :ok
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def fetch_ticket_category
    @ticket_category = @team.ticket_categories.find(params[:id])
  end

  def ticket_category_params
    params.require(:ticket_category).permit(:name, :position, :require_attachment, :client_visible)
  end
end
