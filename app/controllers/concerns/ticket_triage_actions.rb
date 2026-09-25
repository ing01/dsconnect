# A aprovacao da triagem.
#
# Num concern, como TicketImpedimentActions: o TicketsController ja esta no
# limite de tamanho, e isto e recortavel.
#
# O `before_action :fetch_ticket` NAO e declarado aqui - o Rails deduplica
# callbacks pelo nome do filtro, e uma segunda declaracao substituiria a do
# controller. A acao entra na lista de la.
module TicketTriageActions
  extend ActiveSupport::Concern

  # Aceita o chamado e o encaminha, numa coisa so: aprovar sem dizer para onde
  # deixaria o chamado parado num lugar que ninguem escolheu.
  def approve_triage
    team = Current.account.teams.find(triage_params[:team_id])
    column = team.ticket_columns.find(triage_params[:ticket_column_id])
    category = team.ticket_categories.find_by(id: triage_params[:ticket_category_id])

    @ticket.approve_triage!(user: Current.user, team: team, column: column, category: category)
    fetch_ticket(@ticket.id)
    render 'show'
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def triage_params
    params.permit(:team_id, :ticket_column_id, :ticket_category_id)
  end
end
