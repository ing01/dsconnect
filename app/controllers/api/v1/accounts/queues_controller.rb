class Api::V1::Accounts::QueuesController < Api::V1::Accounts::BaseController
  before_action :fetch_queue, only: [:show, :update, :destroy]
  before_action :build_queue, only: [:create]
  before_action :check_authorization

  def index
    @queues = Current.account.queues.includes(:team)
    @queues = @queues.where(team_id: params[:team_id]) if params[:team_id].present?
  end

  def show; end

  def create
    @queue.save!
  end

  def update
    @queue.update!(queue_params)
  end

  def destroy
    @queue.destroy!
    head :ok
  end

  # "Pegar próximo da fila": sempre a mais antiga/prioritária ainda sem
  # dono, dentre TODAS as filas que o agente atual tem acesso - nunca uma
  # escolhida a mao. E o unico jeito de pegar uma conversa da fila pra quem
  # esta com `enforce_queue_order` ligado (ver
  # Conversations::AssignmentsController#blocked_self_assign?), mas fica
  # disponivel pra qualquer atendente, travado ou nao.
  def claim_next
    @conversation = claim_next_conversation
  end

  private

  # Nao amarra a uma fila especifica: considera todas as filas dos Times de
  # que o agente participa, de uma vez - a Ingrid pensa nisso como "a fila",
  # nao "qual fila", entao o agente nunca precisa escolher.
  #
  # Trava atomica (mesmo padrao de `AutoAssignment::AssignmentService`):
  # `FOR UPDATE SKIP LOCKED` garante que dois atendentes clicando ao mesmo
  # tempo nunca pegam a mesma conversa - quem perde a corrida so encontra a
  # fila com uma conversa a menos, nunca um erro nem duplicidade.
  #
  # Ordem: conversas devolvidas por um atendente (`requeued_at` presente)
  # sempre na frente, ignorando prioridade - so depois disso prioridade e
  # antiguidade decidem (mesmo criterio de `SortHandler#sort_on_queue_position`).
  def claim_next_conversation
    queue_ids = Current.account.queues.where(team_id: current_user.teams.ids).ids
    return if queue_ids.empty?

    Conversation.transaction do
      candidate = Current.account.conversations
                         .where(queue_id: queue_ids, assignee_id: nil, status: :open)
                         .order(Arel.sql('(requeued_at IS NULL) ASC, requeued_at ASC, priority DESC NULLS LAST, created_at ASC'))
                         .lock('FOR UPDATE SKIP LOCKED')
                         .first
      next if candidate.blank?

      candidate.update!(assignee: current_user)
      candidate
    end
  end

  def fetch_queue
    @queue = Current.account.queues.find(params[:id])
  end

  def build_queue
    @queue = Current.account.queues.new(queue_params)
  end

  def queue_params
    params.require(:queue).permit(:name, :description, :active, :team_id, :distribution_strategy, :default_sla_policy_id, :priority_boost)
  end

  # QueuePolicy checks the queue's owning team, so authorization must run
  # against the loaded/built instance (when there is one) rather than the bare
  # `ServiceQueue` class the generic `check_authorization` would otherwise use.
  def check_authorization(model = nil)
    super(model || @queue || ServiceQueue)
  end
end
