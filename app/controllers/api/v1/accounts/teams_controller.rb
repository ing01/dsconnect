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
  # association per ticket. `ticket_conversations` and `ticket_checklist_items`
  # matter most: a column with a few hundred cards turned into a few hundred
  # extra queries just for those two (the partial used `.pluck`/`.ordered`,
  # which hit the database even when the association is preloaded - fixed
  # alongside this in `_ticket.json.jbuilder`).
  BOARD_TICKET_INCLUDES = [:team, :ticket_column, :ticket_category, :ticket_complexity, :company, :contact,
                           :project, :blocked_by, :ticket_conversations, :ticket_checklist_items, :sprint,
                           *AssigneeLeveled.assignee_associations,
                           { conversations: :contact }].freeze

  private

  def fetch_team
    @team = Current.account.teams.includes(:ticket_columns).find(params[:id])
    # Carrega `board_tickets` de cada Estagio numa query so' que respeita o
    # limite POR COLUNA (ver TicketColumn.preload_board_tickets!) - encadear
    # `board_tickets` dentro do `includes(ticket_columns: {...})` acima faria o
    # Rails misturar as colunas numa unica query e aplicar o LIMIT na Mesa toda.
    TicketColumn.preload_board_tickets!(@team.ticket_columns, includes: BOARD_TICKET_INCLUDES)
  end

  def team_params
    params.require(:team).permit(:name, :description, :allow_auto_assign, :icon, :icon_color, :manager_id, :active,
                                 :assignee_levels_enabled, :assignee_levels_count,
                                 :handles_conversations, :handles_projects, :visible_in_portal,
                                 :development_module_enabled, :default_checklist_id)
  end

  # TeamPolicy#update? checks the team's manager, so authorization must run
  # against the loaded instance (when there is one) rather than the bare
  # `Team` class the generic `check_authorization` would otherwise use.
  def check_authorization(model = nil)
    super(model || @team || Team)
  end
end
