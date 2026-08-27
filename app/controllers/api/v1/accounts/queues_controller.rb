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

  private

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
  # `Queue` class the generic `check_authorization` would otherwise use.
  def check_authorization(model = nil)
    super(model || @queue || Queue)
  end
end
