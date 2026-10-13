class Api::V1::Accounts::TeamsController < Api::V1::Accounts::BaseController
  before_action :fetch_team, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @teams = Current.account.teams
  end

  def show; end

  def create
    @team = Current.account.teams.new(team_params)
    @team.save!
  end

  def update
    @team.update!(team_params)
  end

  def destroy
    @team.destroy!
    head :ok
  end

  # `_ticket` reads all of these; without the preload the board fires a query per
  # association per ticket.
  BOARD_TICKET_INCLUDES = [:team, :ticket_column, :ticket_category, :company, :contact,
                           *AssigneeLeveled.assignee_associations,
                           { conversations: :contact }].freeze

  private

  def fetch_team
    @team = Current.account.teams.includes(ticket_columns: { board_tickets: BOARD_TICKET_INCLUDES }).find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :description, :allow_auto_assign, :icon, :icon_color, :manager_id, :active,
                                 :assignee_levels_enabled, :assignee_levels_count,
                                 :handles_conversations, :handles_projects, :visible_in_portal)
  end

  # TeamPolicy#update? checks the team's manager, so authorization must run
  # against the loaded instance (when there is one) rather than the bare
  # `Team` class the generic `check_authorization` would otherwise use.
  def check_authorization(model = nil)
    super(model || @team || Team)
  end
end
