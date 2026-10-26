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

  # Copies every item of a pre-built Checklist onto this ticket, continuing the
  # position sequence after whatever items the ticket already has - a ticket
  # can attach the same or different Checklists any number of times over its
  # lifecycle (e.g. one from its Project task template at creation, more later
  # as extra work comes up).
  def attach_checklist
    checklist = Current.account.checklists.find(params[:checklist_id])
    @checklist_items = checklist.attach_to!(@ticket)
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
    params.require(:checklist_item).permit(:title, :completed, :position, :item_type, :required, :value, options: [])
  end
end
