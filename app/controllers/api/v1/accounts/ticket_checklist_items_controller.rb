class Api::V1::Accounts::TicketChecklistItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_checklist_item, only: [:update, :toggle, :destroy]
  before_action :check_authorization

  def index
    @checklist_items = @ticket.ticket_checklist_items.ordered
  end

  def create
    @checklist_item = @ticket.ticket_checklist_items.create!(
      checklist_item_params.merge(account: Current.account)
    )
  end

  def update
    @checklist_item.update!(checklist_item_params)
    render 'show'
  end

  def toggle
    @checklist_item.toggle!(Current.user)
    render 'show'
  end

  def destroy
    @checklist_item.destroy!
    head :ok
  end

  private

  def fetch_ticket
    @ticket = Current.account.tickets.find(params[:ticket_id])
  end

  def fetch_checklist_item
    @checklist_item = @ticket.ticket_checklist_items.find(params[:id])
  end

  def checklist_item_params
    params.require(:checklist_item).permit(:title, :completed, :position)
  end
end
