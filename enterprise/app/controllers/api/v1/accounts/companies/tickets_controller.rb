class Api::V1::Accounts::Companies::TicketsController < Api::V1::Accounts::Companies::BaseController
  before_action :authorize_company_read!

  def index
    @tickets = @company.tickets.includes(:assignee, :team, :ticket_column).order(:position)
  end
end
