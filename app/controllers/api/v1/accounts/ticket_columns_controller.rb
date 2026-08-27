class Api::V1::Accounts::TicketColumnsController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :fetch_ticket_column, only: [:update, :destroy]
  before_action :check_authorization

  # Deliberately lean: just the Estagios, without the tickets that
  # `_ticket_column` inlines. Callers that only need the list of stages (the
  # Ticket detail page's Estagio select) would otherwise have to pull the whole
  # board through `teams#show`.
  def index
    @ticket_columns = @team.ticket_columns.order(:position, :id)
  end

  def create
    @ticket_column = @team.ticket_columns.create!(ticket_column_params)
    apply_requested_position!
  end

  def update
    @ticket_column.assign_attributes(ticket_column_params)
    @ticket_column.team = destination_team if destination_team.present?
    @ticket_column.save!
    apply_requested_position!
  end

  def destroy
    @ticket_column.destroy!
    head :ok
  end

  def reorder
    TicketColumn.reorder!(@team, params[:column_ids])
    @team.reload
    render 'api/v1/accounts/teams/show', formats: [:json]
  end

  private

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def fetch_ticket_column
    @ticket_column = @team.ticket_columns.find(params[:id])
  end

  # `team_id` is resolved against the current account's Mesas instead of being
  # permitted as a plain attribute, so an Estagio can never be handed to a Team
  # from another account.
  def destination_team
    return @destination_team if defined?(@destination_team)

    requested_id = params.dig(:ticket_column, :team_id)
    @destination_team = requested_id.present? ? Current.account.teams.find(requested_id) : nil
  end

  # `position` is read straight off params rather than permitted: an explicit 0 is
  # ignored by TicketColumn#set_default_position, so ordering always goes through
  # the same reorder path the rest of the app uses.
  def apply_requested_position!
    requested = params.dig(:ticket_column, :position)
    return if requested.blank?

    team = @ticket_column.team
    ids = team.ticket_columns.order(:position, :id).pluck(:id) - [@ticket_column.id]
    ids.insert(requested.to_i.clamp(0, ids.length), @ticket_column.id)
    TicketColumn.reorder!(team, ids)
    @ticket_column.reload
  end

  def ticket_column_params
    # `stage_threshold` aceita nulo de proposito: e assim que se diz que o
    # Estagio deixou de ter prazo.
    params.require(:ticket_column).permit(:name, :stage_threshold)
  end
end
