class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  before_action :fetch_project, only: [:show, :update, :destroy, :generate_tickets]
  before_action :check_authorization

  def index
    @projects = Current.account.projects.includes(:team, :company, :contact, :project_module)

    @projects = @projects.where(team_id: params[:team_id]) if params[:team_id].present?
    @projects = @projects.where(company_id: params[:company_id]) if params[:company_id].present?
    @projects = @projects.where(stage: params[:stage]) if params[:stage].present?

    if params[:status].present?
      @projects = @projects.where(status: params[:status])
    elsif params[:completed] == 'true'
      @projects = @projects.completed_board
    else
      @projects = @projects.active_board
    end

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @projects = @projects.left_joins(:company).where(
        'LOWER(projects.name) LIKE :term OR LOWER(companies.name) LIKE :term', term: term
      )
    end

    @projects = @projects.order(created_at: :desc)
  end

  def show; end

  def create
    @project = Current.account.projects.create!(project_params)
  end

  def update
    @project.update!(project_params)
    render 'show'
  end

  def generate_tickets
    @created_tickets = Projects::CreateTicketsService.new(
      account: Current.account,
      project: @project,
      tasks: params[:tasks],
      user: Current.user
    ).perform

    render 'show'
  end

  def destroy
    @project.destroy!
    head :ok
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(
      :name, :company_id, :contact_id, :team_id, :project_module_id,
      :stage, :status, :start_date, :due_date, custom_attributes: {}
    )
  end
end
