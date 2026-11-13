class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  before_action :fetch_project, only: [:show, :update, :destroy, :generate_tickets, :cancel, :reactivate, :create_schedule]
  before_action :check_authorization

  # Rede de seguranca so' pra erro genuinamente inesperado (bug) - tudo que
  # ja tem tratamento proprio (RecordInvalid, RecordNotFound,
  # NotAuthorizedError, etc) e' resolvido ANTES disso, dentro do
  # `around_action :handle_with_exception` da ApplicationController, e
  # nunca chega aqui. Sem isso, um bug em qualquer action desta controller
  # (ex: create_schedule) vazava como "Internal Server Error" cru - bug
  # relatado pela Ingrid, 2026-11-13.
  rescue_from StandardError, with: :render_unexpected_error

  def index
    @projects = board_scope(filtered_projects)
                .includes(:team, :company, :contact, :project_module, :implementer, :default_ticket_category)
                .order(created_at: :desc).to_a
    @progress = progress_for(@projects)
  end

  # Contadores das abas do quadro (Ativos / Concluidos / Cancelados). Vem do
  # servidor porque a lista so traz uma aba por vez - contar o que ja foi
  # carregado deixava o contador da outra aba sempre em zero.
  def counts
    scope = filtered_projects
    render json: {
      active: scope.active_board.count,
      completed: scope.completed_board.count,
      cancelled: scope.where(status: :cancelled).count
    }
  end

  def show; end

  # Com `tasks`, o projeto e as tarefas sao criados juntos: se a geracao falhar,
  # nada fica criado (antes o projeto ficava sem tarefas e tentar de novo criava
  # um segundo projeto).
  def create
    Project.transaction do
      @project = Current.account.projects.create!(project_params)
      generate_requested_tickets(@project) if params[:tasks].present?
    end
  end

  def update
    @project.update!(project_params)
    render 'show'
  end

  def generate_tickets
    @created_tickets = generate_tickets_for(@project, params[:tasks])

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

  # Botao "Criar cronograma": lote de agendamentos (ticket + data/hora +
  # responsavel), cada um virando um CalendarEvent vinculado ao ticket -
  # pedido da Ingrid, 2026-11-12. Cada linha e' isolada no servico (uma
  # linha com problema nao derruba as outras - ver
  # Projects::CreateScheduleService), entao a resposta sempre vem 200,
  # mesmo quando parte das linhas falhou; quem decide o que mostrar e' o
  # `failed` da resposta.
  def create_schedule
    results = Projects::CreateScheduleService.new(
      account: Current.account,
      project: @project,
      user: Current.user,
      items: schedule_items_params
    ).perform

    succeeded = results.select(&:success)
    failed = results.reject(&:success)

    render json: {
      created_count: succeeded.size,
      tickets: succeeded.map { |result| result.ticket.slice(:id, :display_id, :title, :scheduled_at, :assignee_id) },
      calendar_event_ids: succeeded.map { |result| result.calendar_event.id },
      failed: failed.map { |result| { label: result.label, error: result.error_message } }
    }
  end

  private

  def render_unexpected_error(exception)
    Rails.logger.error("[ProjectsController] #{exception.class}: #{exception.message}")
    render json: { error: I18n.t('errors.project.unexpected_error', default: 'Não foi possível concluir a operação. Tente novamente ou contate o suporte.') },
           status: :internal_server_error
  end

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  def filtered_projects
    projects = Current.account.projects

    projects = projects.where(team_id: params[:team_id]) if params[:team_id].present?
    projects = projects.where(company_id: params[:company_id]) if params[:company_id].present?
    projects = projects.where(stage: params[:stage]) if params[:stage].present?
    projects = projects.where(implementer_id: params[:implementer_id]) if params[:implementer_id].present?
    projects = projects.where(project_module_id: params[:project_module_id]) if params[:project_module_id].present?
    projects = search_projects(projects) if params[:search].present?
    projects
  end

  def search_projects(projects)
    term = "%#{params[:search].strip.downcase}%"
    projects.left_joins(:company).where(
      'LOWER(projects.name) LIKE :term OR LOWER(companies.name) LIKE :term', term: term
    )
  end

  # Qual aba do quadro: `status` explicito (ex.: cancelled), `completed=true`
  # (finalizados) ou, por padrao, os ativos.
  def board_scope(projects)
    if params[:status].present?
      projects.where(status: params[:status])
    elsif params[:completed] == 'true'
      projects.completed_board
    else
      projects.active_board
    end
  end

  # Progresso e horas de todos os projetos da lista em duas consultas, em vez
  # de varias por projeto (a lista de projetos era lenta por isso). Mesma regra
  # de `Project#progress_tickets_count` / `#completed_tickets_count`.
  def progress_for(projects)
    ids = projects.map(&:id)
    progress = ids.index_with { { tickets_count: 0, completed_tickets_count: 0, open_tickets_count: 0, total_hours: 0 } }

    Ticket.where(project_id: ids).pluck(:project_id, :status).each do |project_id, status|
      next if status == 'cancelled'

      entry = progress[project_id]
      entry[:tickets_count] += 1
      entry[:completed_tickets_count] += 1 if %w[resolved closed].include?(status)
      entry[:open_tickets_count] += 1 if status == 'open'
    end

    TicketTimeEntry.joins(:ticket).where(tickets: { project_id: ids }).pluck('tickets.project_id', :hours).each do |project_id, hours|
      progress[project_id][:total_hours] += hours.to_f
    end

    progress
  end

  def generate_tickets_for(project, tasks)
    Projects::CreateTicketsService.new(
      account: Current.account,
      project: project,
      tasks: tasks,
      user: Current.user
    ).perform
  end

  def generate_requested_tickets(project)
    created = generate_tickets_for(project, params[:tasks])
    return if created.size == Array(params[:tasks]).size

    project.errors.add(:base, I18n.t('errors.project.tasks_not_generated'))
    raise ActiveRecord::RecordInvalid, project
  end

  # Livre para qualquer usuario que ja possa acessar o projeto (acompanhamento
  # do dia a dia): estagio, implantador, observacoes, datas de suporte/contrato
  # e de inicio de uso do sistema.
  ALWAYS_ALLOWED_ATTRS = %i[
    stage status implementer_id completion_type notes support_ends_on contract_signed_on system_started_on
  ].freeze

  # So podem ser alterados DEPOIS de criado por quem administra o projeto -
  # na criacao (`create`) continuam livres, e' so a EDICAO posterior desses
  # campos que exige `project_manage`.
  RESTRICTED_ATTRS = %i[name company_id contact_id team_id project_module_id start_date due_date
                        default_ticket_category_id].freeze

  def schedule_items_params
    params.require(:items).map do |item|
      item.permit(:ticket_id, :new_ticket_title, :title, :description, :start_at, :end_at, :responsible_user_id).to_h
    end
  end

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
