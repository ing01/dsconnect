# A matriz Mesa x Prioridade: um prazo de atendimento e um de solucao por
# prioridade da Mesa. Nada aqui e hardcoded - uma Mesa sem linhas simplesmente
# nao promete prazo nenhum.
class Api::V1::Accounts::TicketSlaPoliciesController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :fetch_ticket_sla_policy, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @ticket_sla_policies = @team.ticket_sla_policies.order(:priority)
  end

  def create
    @ticket_sla_policy = @team.ticket_sla_policies.create!(ticket_sla_policy_params)
  end

  def update
    @ticket_sla_policy.update!(ticket_sla_policy_params.except(:priority))
  end

  # Apagar a linha e como se diz que a prioridade nao tem prazo. Os relogios ja
  # abertos continuam valendo: cada um guardou o prazo que valia quando comecou.
  def destroy
    @ticket_sla_policy.destroy!
    head :ok
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def fetch_ticket_sla_policy
    @ticket_sla_policy = @team.ticket_sla_policies.find(params[:id])
  end

  def ticket_sla_policy_params
    params.require(:ticket_sla_policy).permit(
      :priority, :response_threshold, :resolution_threshold, :only_during_business_hours
    )
  end
end
