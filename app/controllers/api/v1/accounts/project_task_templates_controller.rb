class Api::V1::Accounts::ProjectTaskTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_project_task_template, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @project_task_templates = Current.account.project_task_templates.includes(:default_assignee, :checklist).ordered
  end

  def show; end

  def create
    @project_task_template = Current.account.project_task_templates.create!(project_task_template_params)
  end

  def update
    @project_task_template.update!(project_task_template_params)
    render 'show'
  end

  def destroy
    @project_task_template.destroy!
    head :ok
  end

  private

  def fetch_project_task_template
    @project_task_template = Current.account.project_task_templates.find(params[:id])
  end

  def project_task_template_params
    params.require(:project_task_template).permit(
      :name, :default_ticket_title, :description, :default_assignee_id,
      :due_days, :next_project_stage, :checklist_id
    )
  end
end
