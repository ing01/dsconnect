class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket, only: [:show, :update, :destroy, :move]
  before_action :check_authorization

  def index
    @tickets = Current.account.tickets
    @tickets = @tickets.where(ticket_column_id: params[:ticket_column_id]) if params[:ticket_column_id].present?
    @tickets = @tickets.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    @tickets = @tickets.where(team_id: params[:team_id]) if params[:team_id].present?
    @tickets = @tickets.joins(:ticket_conversations).where(ticket_conversations: { conversation_id: params[:conversation_id] }) if params[:conversation_id].present?
    @tickets = @tickets.order(:position)
  end

  def show; end

  def create
    @ticket = Current.account.tickets.new(ticket_params)
    @ticket.save!

    link_conversation!(params[:conversation_id]) if params[:conversation_id].present?
  end

  def update
    @ticket.update!(ticket_params.except(:ticket_column_id))
  end

  # Moves the ticket to another column and/or position (Kanban drag-and-drop).
  def move
    target_column = fetch_ticket_column(params[:ticket_column_id]) || @ticket.ticket_column
    @ticket.move_to!(ticket_column: target_column, position: params[:position].to_i)
  end

  def destroy
    @ticket.destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:id])
  end

  def fetch_ticket_column(id)
    return if id.blank?

    TicketColumn.joins(:ticket_board).find_by(id: id, ticket_boards: { account_id: Current.account.id })
  end

  def link_conversation!(conversation_id)
    conversation = Current.account.conversations.find(conversation_id)
    @ticket.ticket_conversations.create!(conversation: conversation)
  end

  def ticket_params
    params.require(:ticket).permit(:title, :description, :priority, :assignee_id, :team_id, :ticket_column_id)
  end
end
