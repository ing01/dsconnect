class Api::V1::Accounts::TicketChecklistItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket
  before_action :fetch_checklist_item, only: [:update, :toggle, :fill_form, :destroy]
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

  # Preenche o item de checklist tipo 'form': cria o FormResponse e um
  # FormAnswer por pergunta (texto/data/opcoes em `answers`, arquivo em
  # `files` - ambos um hash field_id => valor), e marca o item como
  # completo (ver FormResponse#attach_to_checklist_item!).
  def fill_form
    return render_wrong_item_type unless @checklist_item.item_type == 'form'

    ActiveRecord::Base.transaction do
      form_response = @checklist_item.form.form_responses.create!(
        account: Current.account, ticket: @ticket, ticket_checklist_item: @checklist_item,
        filled_by: Current.user
      )
      build_answers!(form_response)
      form_response.attach_to_checklist_item!
    end
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

  def build_answers!(form_response)
    (params[:answers] || {}).each do |field_id, value|
      next if value.blank?

      form_response.form_answers.create!(account: Current.account, field_id: field_id, value: value)
    end
    (params[:files] || {}).each do |field_id, file|
      next if file.blank?

      answer = form_response.form_answers.create!(account: Current.account, field_id: field_id)
      answer.file.attach(file)
    end
  end

  def render_wrong_item_type
    render json: { error: 'This checklist item is not a form' }, status: :unprocessable_entity
  end
end
