class Api::V1::Accounts::TicketColumnsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket_board
  before_action :fetch_ticket_column, only: [:update, :destroy]
  before_action :check_authorization

  def create
    @ticket_column = @ticket_board.ticket_columns.create!(ticket_column_params)
  end

  def update
    @ticket_column.update!(ticket_column_params)
  end

  def destroy
    @ticket_column.destroy!
    head :ok
  end

  def reorder
    TicketColumn.reorder!(@ticket_board, params[:column_ids])
    @ticket_board.reload
    render 'api/v1/accounts/ticket_boards/show', formats: [:json]
  end

  private

  def fetch_ticket_board
    @ticket_board = Current.account.ticket_boards.find(params[:ticket_board_id])
  end

  def fetch_ticket_column
    @ticket_column = @ticket_board.ticket_columns.find(params[:id])
  end

  def ticket_column_params
    params.require(:ticket_column).permit(:name)
  end
end
