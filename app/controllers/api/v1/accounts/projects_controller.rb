class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  before_action :fetch_project, only: [:show, :update, :destroy, :generate_tickets, :cancel, :reactivate]
  before_action :check_authorization

  def index
    @projects = Current.account.projects.includes(:team, :company, :contact, :project_module)

    @projects = @projects.where(team_id: params[:team_id]) if params[:team_id].present?
    @projects = @projects.where(company_id: params[:company_id]) if params[:company_id].present?
    @projects = @projects.where(stage: params[:stage]) if params[:stage].present?
    @projects = @projects.where(implementer_id: params[:implementer_id]) if params[:implementer_id].present?
    @projects = @projects.where(project_module_id: params[:project_module_id]) if params[:project_module_id].present?

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

  def cancel
    @project.cancel!(reason: params[:reason])
    render 'show'
  end

  def reactivate
    @project.reactivate!
    render 'show'
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  # Livre para qualquer usuario que ja possa acessar o projeto (acompanhamento
  # do dia a dia): estagio, implantador, observacoes, datas de suporte/contrato.
  ALWAYS_ALLOWED_ATTRS = %i[
    stage status implementer_id completion_type notes support_ends_on contract_signed_on
  ].freeze

  # So podem ser alterados DEPOIS de criado por quem administra o projeto -
  # na criacao (`create`) continuam livres, e' so a EDICAO posterior desses
  # campos que exige `project_manage`.
  RESTRICTED_ATTRS = %i[name company_id contact_id team_id project_module_id start_date due_date
                        default_ticket_category_id].freeze

  def project_params
    params.require(:project).permit(*permitted_project_attrs, custom_attributes: {})
  end

  def permitted_project_attrs
    return ALWAYS_ALLOWED_ATTRS + RESTRICTED_ATTRS if action_name == 'create' || can_manage_project?

    ALWAYS_ALLOWED_ATTRS
  end

  def can_manage_project?
    Current.account_user&.administrator? || Current.account_user&.permissions&.include?('project_manage')
  end
end
