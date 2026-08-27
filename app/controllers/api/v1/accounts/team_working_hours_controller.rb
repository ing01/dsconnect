# O expediente da Mesa, usado pelos tres SLAs do Ticket.
#
# Mesmo formato que o expediente das Inboxes ja usa (OutOfOffisable), para que a
# tela do frontend seja a mesma ideia e o calculo continue sendo um so.
class Api::V1::Accounts::TeamWorkingHoursController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  # Autoriza contra a propria Mesa: quem pode editar a Mesa pode editar o
  # expediente dela, sem policy nova para um recurso que nao e um recurso.
  before_action -> { authorize(@team) }

  def show; end

  def update
    @team.update!(team_params) if team_params.present?
    @team.update_working_hours(working_hours_params) if params[:working_hours].present?
    @team.reload
    render 'show'
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def team_params
    params.permit(:working_hours_enabled, :timezone).slice(:working_hours_enabled, :timezone)
  end

  def working_hours_params
    params.permit(working_hours: OutOfOffisable::OFFISABLE_ATTRS)[:working_hours]
  end
end
