class Api::V1::Accounts::ConversationFlowsController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation_flow, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @conversation_flows = Current.account.conversation_flows.includes(:flow_steps)
  end

  def show; end

  def create
    @conversation_flow = Current.account.conversation_flows.create!(conversation_flow_params)
  end

  def update
    @conversation_flow.update!(conversation_flow_params)
  end

  def destroy
    @conversation_flow.destroy!
    head :ok
  end

  private

  def fetch_conversation_flow
    @conversation_flow = Current.account.conversation_flows.includes(:flow_steps).find(params[:id])
  end

  def conversation_flow_params
    params.require(:conversation_flow).permit(:name, :description, :active)
  end
end
