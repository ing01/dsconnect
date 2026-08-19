class Api::V1::Accounts::TicketBoardsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket_board, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @ticket_boards = Current.account.ticket_boards.includes(ticket_columns: { tickets: :ticket_conversations })
  end

  def show; end

  def create
    @ticket_board = Current.account.ticket_boards.create!(ticket_board_params)
  end

  def update
    @ticket_board.update!(ticket_board_params)
  end

  def destroy
    @ticket_board.destroy!
    head :ok
  end

  private

  def fetch_ticket_board
    @ticket_board = Current.account.ticket_boards.find(params[:id])
  end

  def ticket_board_params
    params.require(:ticket_board).permit(:name)
  end
end
