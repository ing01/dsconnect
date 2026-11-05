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
    return reject_out_of_order_assign if blocked_manual_assign?

    resource = Conversations::AssignmentService.new(
      conversation: @conversation,
      assignee_id: params[:assignee_id],
      assignee_type: params[:assignee_type]
    ).perform

    render_agent(resource)
  end

  # Quem NAO E Administrador nao escolhe atendimento livremente - so pega a
  # proxima conversa da fila em ordem (endpoint `Queues#claim_next`). Vale
  # pra se atribuir a si mesmo e pra atribuir a outro colega igual - senao a
  # trava vira so um convite pra "passar a conversa pra frente" via outra
  # pessoa -, em qualquer conversa que esteja numa fila. Regra fixa: ignora
  # completamente qualquer Funcao personalizada (`conversation_manage` e
  # companhia) e o antigo campo por atendente - so o cargo Administrador de
  # verdade libera a escolha livre.
  def blocked_manual_assign?
    return false if agent_bot_assignment?
    return false if params[:assignee_id].blank?
    return false if @conversation.queue_id.blank?

    !Current.account_user.administrator?
  end

  def clearing_queue?(queue_id)
    !queue_id.positive? && @conversation.queue_id.present? && !Current.account_user.administrator?
  end

  def render_clear_queue_not_allowed
    render_could_not_create_error(I18n.t('errors.queues.clear_queue_not_allowed'))
  end

  def reject_out_of_order_assign
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
    sync_linked_tickets_to_team if @team
    render json: @team
  end

  # "Atribuir Time" na conversa e a Mesa do Ticket eram dois campos sem
  # nenhuma ligacao - trocar o Time aqui nunca movia o ticket vinculado, e o
  # cartao da lista (que mostra a Mesa do TICKET) ficava parado. Qualquer
  # ticket vinculado a esta conversa passa a seguir para a mesma Mesa, pelo
  # Estagio de entrada dela - o mesmo caminho de Tickets::TransferService
  # que a tela de Transferir usa.
  def sync_linked_tickets_to_team
    column = entry_column(@team)
    return unless column

    @conversation.tickets.where.not(team_id: @team.id).find_each do |ticket|
      Tickets::TransferService.new(
        ticket: ticket, user: Current.user,
        attributes: { team_id: @team.id, ticket_column_id: column.id }
      ).perform
    rescue ActiveRecord::RecordInvalid
      # O Estagio de entrada da Mesa nova pode exigir algo que o ticket ainda
      # nao tem (prazo, responsavel...) - a troca de Time da conversa nao
      # pode travar por isso; o ticket so fica de fora, pra alguem mover a
      # mao mais tarde.
      next
    end
  end

  def entry_column(team)
    team.ticket_columns.find_by(kind: 'pending') || team.ticket_columns.order(:position, :id).first
  end

  def agent_bot_assignment?
    params[:assignee_type].to_s == 'AgentBot'
  end

  def set_queue
    queue_id = params[:queue_id].to_i
    # Tirar a conversa da fila destrava a atribuicao livre (a trava so olha
    # `queue_id`), entao so' Administrador pode fazer isso.
    return render_clear_queue_not_allowed if clearing_queue?(queue_id)

    @queue =queue_id.positive? ? Current.account.queues.find(queue_id) : nil
    @conversation.with_lock do
      @conversation.update!(queue: @queue)
    end
    render json: @queue
  end
end
