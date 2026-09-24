class Api::V1::Accounts::Conversations::AssignmentsController < Api::V1::Accounts::Conversations::BaseController
  # assigns agent/team to a conversation
  def create
    if params.key?(:assignee_id) || agent_bot_assignment?
      set_agent
    elsif params.key?(:team_id)
      set_team
    elsif params.key?(:queue_id)
      set_queue
    else
      render json: nil
    end
  end

  private

  def set_agent
    return reject_out_of_order_self_assign if blocked_self_assign?

    resource = Conversations::AssignmentService.new(
      conversation: @conversation,
      assignee_id: params[:assignee_id],
      assignee_type: params[:assignee_type]
    ).perform

    render_agent(resource)
  end

  # Atendente com a trava de fila ligada nao escolhe livremente - so pega a
  # proxima em ordem (endpoint `Queues#claim_next`). So se aplica a
  # AUTO-atribuicao (o proprio atendente se atribuindo) e so a conversas numa
  # fila; Administrador nunca e afetado, e nada impede um Admin atribuir
  # OUTRA pessoa livremente.
  def blocked_self_assign?
    return false unless self_assignment?
    return false if @conversation.queue_id.blank?
    return false unless Current.account_user.enforce_queue_order?
    return false if Current.account_user.administrator?

    true
  end

  def self_assignment?
    params[:assignee_id].present? && !agent_bot_assignment? && params[:assignee_id].to_i == Current.user.id
  end

  def reject_out_of_order_self_assign
    render_could_not_create_error(I18n.t('errors.queues.out_of_order_assignment'))
  end

  def render_agent(resource)
    case resource
    when User
      render partial: 'api/v1/models/agent', formats: [:json], locals: { resource: resource }
    when AgentBot
      render partial: 'api/v1/models/agent_bot_slim', formats: [:json], locals: { resource: resource }
    else
      render json: nil
    end
  end

  def set_team
    team_id = params[:team_id].to_i
    @team = team_id.positive? ? Current.account.teams.find(team_id) : nil
    @conversation.with_lock do
      @conversation.update!(team: @team)
    end
    render json: @team
  end

  def agent_bot_assignment?
    params[:assignee_type].to_s == 'AgentBot'
  end

  def set_queue
    queue_id = params[:queue_id].to_i
    @queue = queue_id.positive? ? Current.account.queues.find(queue_id) : nil
    @conversation.with_lock do
      @conversation.update!(queue: @queue)
    end
    render json: @queue
  end
end
