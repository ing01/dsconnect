class Api::V1::Accounts::TicketConversationsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :check_authorization

  def create
    conversation = Current.account.conversations.find(ticket_conversation_params[:conversation_id])
    @ticket_conversation = @ticket.ticket_conversations.create!(conversation: conversation)
  end

  def destroy
    @ticket.ticket_conversations.find_by!(conversation_id: params[:id]).destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def ticket_conversation_params
    params.require(:ticket_conversation).permit(:conversation_id)
  end
end
