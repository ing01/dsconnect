class Api::V1::Accounts::TicketTimeEntriesController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_time_entry, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @ticket_time_entries = @ticket.ticket_time_entries.ordered
  end

  def create
    @ticket_time_entry = @ticket.ticket_time_entries.create!(
      time_entry_params.merge(account: Current.account, user: Current.user)
    )
  end

  def update
    @ticket_time_entry.update!(time_entry_params)
    render 'show'
  end

  def destroy
    @ticket_time_entry.destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def fetch_time_entry
    @ticket_time_entry = @ticket.ticket_time_entries.find(params[:id])
  end

  def time_entry_params
    # `level` e opcional: quando nao vem, o model o deduz de quem esta apontando
    # (TicketTimeEntry#inferred_level).
    params.require(:ticket_time_entry).permit(:category, :hours, :worked_on, :note, :level)
  end
end
