class Api::V1::Accounts::TicketColumnsController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :fetch_ticket_column, only: [:update, :destroy]
  before_action :check_authorization

  def create
    @ticket_column = @team.ticket_columns.create!(ticket_column_params)
  end

  def update
    @ticket_column.update!(ticket_column_params)
  end

  def destroy
    @ticket_column.destroy!
    head :ok
  end

  def reorder
    TicketColumn.reorder!(@team, params[:column_ids])
    @team.reload
    render 'api/v1/accounts/teams/show', formats: [:json]
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def fetch_ticket_column
    @ticket_column = @team.ticket_columns.find(params[:id])
  end

  def ticket_column_params
    params.require(:ticket_column).permit(:name)
  end
end
