class Api::V1::Accounts::FlowStepsController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation_flow
  before_action :fetch_flow_step, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @flow_steps = @conversation_flow.flow_steps
  end

  def create
    @flow_step = @conversation_flow.flow_steps.create!(flow_step_params.merge(account_id: Current.account.id, position: next_position))
  end

  def update
    @flow_step.update!(flow_step_params)
  end

  def destroy
    @flow_step.destroy!
    head :ok
  end

  def reorder
    FlowStep.reorder!(@conversation_flow, params[:step_ids])
    @conversation_flow.reload
    @flow_steps = @conversation_flow.flow_steps
    render :index
  end

  private

  def fetch_conversation_flow
    @conversation_flow = Current.account.conversation_flows.find(params[:conversation_flow_id])
  end

  def fetch_flow_step
    @flow_step = @conversation_flow.flow_steps.find(params[:id])
  end

  def next_position
    (@conversation_flow.flow_steps.maximum(:position) || -1) + 1
  end

  # `options` shape depends on `step_type` - a single hash of action params for most
  # types, but an array of `{title, value, next_step_id}` branches for
  # `present_options`. Strong parameters can't express both shapes with one static
  # declaration, and (like AutomationRule#conditions/#actions) this is
  # administrator-only configuration data, so it's taken as-is rather than filtered.
  def flow_step_params
    raw = params.require(:flow_step).to_unsafe_h.with_indifferent_access
    raw.slice(:step_type, :content, :next_step_id, :options)
  end
end
