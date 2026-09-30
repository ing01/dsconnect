# Roteamento automatico do ticket do Portal do Cliente, por nivel de
# prioridade da Empresa (`TicketRoutingRule`) - so Administrador configura,
# mesmo padrao de `AttendanceWindowsController`.
class Api::V1::Accounts::TicketRoutingRulesController < Api::V1::Accounts::BaseController
  before_action -> { authorize(Current.account, :update?) }

  def index
    @ticket_routing_rules = current_rules
  end

  # Substitui o conjunto inteiro de uma vez - no maximo 3 linhas (Baixa/Media/
  # Alta), e' mais simples do que casar id-a-id. Um nivel sem Mesa escolhida
  # na tela simplesmente nao manda linha nenhuma para ele.
  def bulk_update
    ActiveRecord::Base.transaction do
      Current.account.ticket_routing_rules.destroy_all
      rules_params.each { |rule| Current.account.ticket_routing_rules.create!(rule) }
    end
    @ticket_routing_rules = current_rules
    render :index
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.full_messages.join(', '))
  end

  private

  def current_rules
    Current.account.ticket_routing_rules.includes(:team).order(:client_level)
  end

  def rules_params
    (params[:ticket_routing_rules] || []).map { |rule| rule.permit(:client_level, :team_id) }
  end
end
