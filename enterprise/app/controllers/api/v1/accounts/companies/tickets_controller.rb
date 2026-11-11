class Api::V1::Accounts::Companies::TicketsController < Api::V1::Accounts::Companies::BaseController
  before_action :authorize_company_read!

  def index
    # Do maior numero de chamado para o menor: o mais recente primeiro.
    @tickets = @company.tickets.includes(:assignee, :team, :ticket_column)
                       .order(Arel.sql('tickets.display_id DESC NULLS LAST'), id: :desc)
  end
end
