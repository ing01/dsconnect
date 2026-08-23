class Api::V1::Accounts::TicketActivitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :check_authorization

  def index
    @ticket_activities = @ticket.ticket_activities.includes(:user).order(created_at: :desc)
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end
end
