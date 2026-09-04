class Api::V1::Accounts::ChecklistsController < Api::V1::Accounts::BaseController
  before_action :fetch_checklist, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @checklists = Current.account.checklists.ordered
  end

  def show; end

  def create
    @checklist = Current.account.checklists.create!(checklist_params)
  end

  def update
    @checklist.update!(checklist_params)
    render 'show'
  end

  def destroy
    @checklist.destroy!
    head :ok
  end

  private

  def fetch_checklist
    @checklist = Current.account.checklists.find(params[:id])
  end

  def checklist_params
    params.require(:checklist).permit(:name, items: [:title])
  end
end
